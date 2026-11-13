#' Cross-validated evaluation.
#'
#' @param data Data frame.
#' @param formula Model formula.
#' @param model Learner id (ignored if `fit` supplied).
#' @param spec Hyperparameter list.
#' @param resampling Resampling object from `cv()`.
#' @param metrics Character vector of metric names.
#' @param type Prediction type override.
#' @param conf_level Confidence level for fold-based summary intervals.
#' @param se_method How the standard error of the cross-validated mean is
#'   computed. `"naive"` (default) uses `sd / sqrt(J)` over the `J` fold
#'   values with a t interval on `J - 1` degrees of freedom. This treats the
#'   folds as independent, but they share training data, so the standard
#'   error and the interval are too narrow (often markedly so). `"corrected"`
#'   uses the Nadeau and Bengio (2003) corrected variance
#'   `(1 / J + n_test / n_train) * sd^2`, with `n_test / n_train` the ratio of
#'   the mean test and training sizes. It is a heuristic, more conservative
#'   correction; neither interval has exact coverage. Use the intervals as a
#'   rough guide to fold-to-fold variability, not as formal inference.
#' @param seed Optional seed.
#' @param fit Optional preconfigured `funcml_fit` object (re-fit per fold).
#' @param ncores Optional number of CPU cores used to evaluate resampling folds.
#'   `NULL` or `1` runs sequentially.
#' @param pooled Logical; if `TRUE`, also compute every metric once on the
#'   pooled out-of-fold predictions (all test folds stacked, one value per
#'   repeat, then averaged over repeats) and return it as `$pooled`.
#' @param ... Passed to `fit()`.
#' @details Missing values are not handled for most learners: if any variable
#'   used by `formula` contains `NA`, `evaluate()` stops with an error naming
#'   the affected columns. Impute or drop incomplete rows (for example with
#'   `stats::na.omit()` on the model variables) before calling it. Learners
#'   that handle missing predictors natively (currently `fastgbm`, see
#'   [fit()]) accept `NA` in predictors; the outcome must still be complete.
#'
#'   `$summary` averages each metric over folds. For metrics that are not
#'   means of per-row losses this differs from the value computed on the
#'   pooled out-of-fold predictions. Binned calibration metrics (`ece`,
#'   `mce`) are the main case: each fold has few rows per bin, so the
#'   fold-averaged ECE is inflated by bin noise and is typically much larger
#'   than the pooled ECE (for example 0.11 vs 0.04). `auc` differs too, less
#'   markedly. Use `pooled = TRUE`, or compute the metric from
#'   `$predictions`, when you want the pooled value.
#' @return A `funcml_eval` object: a list with `folds` (metric per fold),
#'   `summary` (fold-averaged metrics with intervals), `predictions` (one row
#'   per out-of-fold prediction: `row`, `repeat_id`, `fold`, `truth`, and
#'   `.pred` for regression or `.pred_class` plus one `.prob_<level>` column
#'   per class for classification), `pooled` (`NULL` unless `pooled = TRUE`),
#'   and bookkeeping fields.
#' @examples
#' eval_obj <- evaluate(
#'   data = mtcars,
#'   formula = mpg ~ wt + hp,
#'   model = "glm",
#'   resampling = cv(3, seed = 1),
#'   metrics = c("rmse", "mae")
#' )
#' eval_obj$summary
#' @export
evaluate <- function(data, formula, model = NULL, spec = NULL,
                     resampling = cv(5), metrics = NULL, type = NULL,
                     conf_level = 0.95, seed = NULL, fit = NULL,
                     ncores = NULL, se_method = c("naive", "corrected"),
                     pooled = FALSE, ...) {
  se_method <- match.arg(se_method)
  ncores <- .validate_ncores(ncores)
  if (!is.null(seed)) set.seed(seed)
  if (!is.null(fit)) {
    base_model <- fit$model
    base_spec <- spec %||% fit$spec
    formula <- formula %||% fit$formula
    task <- fit$task
  } else {
    if (is.null(model)) stop("Provide either `model` or `fit`.", call. = FALSE)
    base_model <- model
    base_spec <- spec
    task <- infer_task(model.response(model.frame(formula, data)))
  }

  .check_no_missing_model_vars(
    formula, data,
    outcome_only = isTRUE(funcml_registry(base_model)$supports$na) && is.null(list(...)$na_action)
  )
  y_all <- model.response(model.frame(formula, data, na.action = stats::na.pass))
  if (task == "classification") {
    y_all <- factor(y_all)
  }
  is_multiclass <- task == "classification" && length(levels(y_all)) > 2
  resampling <- generate_folds(nrow(data), y_all, resampling, data = data)

  if (is.null(metrics)) {
    metrics <- if (task == "regression") {
      c("rmse", "mae", "mse", "medae", "mape", "rsq")
    } else if (is_multiclass) {
      c("accuracy", "precision", "recall", "specificity", "f1", "balanced_accuracy", "logloss", "brier", "auc")
    } else {
      c("accuracy", "precision", "recall", "specificity", "f1", "balanced_accuracy", "logloss", "brier", "auc", "ece", "mce")
    }
    metrics <- unlist(metrics)
  }
  fold_ids <- seq_along(resampling$folds)
  fold_seeds <- .task_seeds(seed, length(fold_ids))
  folds_out <- .funcml_map(fold_ids, function(i) {
    fold <- resampling$folds[[i]]
    task_seed <- fold_seeds[[i]]
    if (!is.null(task_seed)) {
      set.seed(task_seed)
    }
    .evaluate_split(
      data = data, formula = formula, model = base_model, spec = base_spec,
      fold = fold, y_all = y_all, task = task, metrics = metrics, type = type, ...
    )
  }, ncores = ncores)

  predictions <- .rbind_dt(lapply(folds_out, `[[`, "predictions"))
  folds_out <- lapply(folds_out, `[[`, "metrics")
  folds_df <- .rbind_dt(folds_out)
  # Aggregate fold metrics into mean/sd columns explicitly to avoid the
  # list/matrix column shape that `aggregate()` produces when the function
  # returns a vector. The previous approach created a 2-column matrix inside a
  # single `value` column, which then failed when assigning back to a data
  # frame (replacement length mismatch on some R versions).
  summary_df <- .summarize_metric_uncertainty(
    folds_df,
    conf_level = conf_level,
    se_method = se_method,
    test_train_ratio = .test_train_ratio(resampling$folds)
  )

  out <- list(
    folds = folds_df,
    summary = summary_df,
    predictions = predictions,
    pooled = if (isTRUE(pooled)) .pooled_metrics(predictions, metrics, task) else NULL,
    call = match.call(),
    task = task,
    model = base_model,
    resampling = resampling,
    se_method = se_method
  )
  class(out) <- "funcml_eval"
  out
}

#' Methods for cross-validation results.
#'
#' These methods provide the standard `print()` and `summary()` interfaces for
#' `funcml_eval` objects, plus a `plot()` method for fold-level diagnostics.
#'
#' @param x A `funcml_eval` object.
#' @param object A `funcml_eval` object.
#' @param digits Number of digits numeric columns are rounded to when printed.
#' @param ... Additional arguments passed to the underlying method.
#' @return `print()` and `summary()` return the input object or summary
#'   table invisibly. `plot()` returns a `ggplot2` object.
#'
#' @name evaluate-methods
#' @aliases print.funcml_eval summary.funcml_eval plot.funcml_eval
#' @examples
#' eval_obj <- evaluate(
#'   data = mtcars,
#'   formula = mpg ~ wt + hp,
#'   model = "glm",
#'   resampling = cv(3, seed = 1),
#'   metrics = c("rmse", "mae")
#' )
#' print(eval_obj)
#' summary(eval_obj)
#' plot(eval_obj)
#' @export
print.funcml_eval <- function(x, digits = 4L, ...) {
  cat(sprintf("<funcml_eval> model: %s | task: %s\n", x$model, x$task))
  print(.round_numeric_df(x$summary, digits = digits))
  if (identical(x$se_method %||% "naive", "naive")) {
    cat("Note: std_error and conf_low/conf_high treat folds as independent and are too narrow;\n")
    cat("      see `se_method = \"corrected\"` in ?evaluate.\n")
  } else {
    cat("Note: std_error uses the Nadeau-Bengio corrected variance (approximate).\n")
  }
  invisible(x)
}

#' @rdname evaluate-methods
#' @export
summary.funcml_eval <- function(object, digits = 4L, ...) {
  print(.round_numeric_df(object$summary, digits = digits))
  invisible(object$summary)
}

#' @rdname evaluate-methods
#' @export
plot.funcml_eval <- function(x, ...) {
  df <- x$folds
  ggplot2::ggplot(df, ggplot2::aes(x = value, y = stats::reorder(metric, value, FUN = median))) +
    ggplot2::geom_boxplot(fill = "white", colour = "grey25", outlier.alpha = 0.3, width = 0.65) +
    ggplot2::geom_point(
      position = ggplot2::position_jitter(height = 0.12, width = 0),
      alpha = 0.3,
      size = 1.2,
      colour = "grey30"
    ) +
    ggplot2::geom_point(
      data = x$summary,
      mapping = ggplot2::aes(x = mean, y = metric),
      inherit.aes = FALSE,
      size = 2.2,
      colour = "black"
    ) +
    ggplot2::geom_segment(
      data = x$summary,
      mapping = ggplot2::aes(x = conf_low, xend = conf_high, y = metric, yend = metric),
      inherit.aes = FALSE,
      linewidth = 0.45,
      colour = .funcml_palette$accent
    ) +
    ggplot2::labs(x = "Cross-validated metric value", y = NULL, title = "Cross-validation performance") +
    themefuncml()
}

.check_no_missing_model_vars <- function(formula, data, outcome_only = FALSE) {
  mf <- stats::model.frame(formula, data, na.action = stats::na.pass)
  if (isTRUE(outcome_only)) {
    if (anyNA(stats::model.response(mf))) {
      stop(sprintf(
        "`evaluate()` needs a complete outcome: %d row(s) have NA in '%s'. Remove them first.",
        sum(is.na(stats::model.response(mf))), names(mf)[1L]
      ), call. = FALSE)
    }
    return(invisible(TRUE))
  }
  has_na <- vapply(mf, anyNA, logical(1))
  if (any(has_na)) {
    n_rows <- sum(!stats::complete.cases(mf))
    stop(sprintf(
      paste0(
        "`evaluate()` does not handle missing values: %d row(s) have NA in ",
        "model variable(s) %s. Impute or remove incomplete rows first."
      ),
      n_rows,
      paste(sprintf("'%s'", names(mf)[has_na]), collapse = ", ")
    ), call. = FALSE)
  }
  invisible(TRUE)
}

.test_train_ratio <- function(folds) {
  if (!length(folds)) {
    return(NA_real_)
  }
  n_test <- mean(vapply(folds, function(f) length(f$test), numeric(1)))
  n_train <- mean(vapply(folds, function(f) length(f$train), numeric(1)))
  n_test / n_train
}

.summarize_metric_uncertainty <- function(folds_df, conf_level = 0.95,
                                          se_method = "naive",
                                          test_train_ratio = NA_real_) {
  metrics <- unique(folds_df$metric)
  alpha <- 1 - conf_level
  out <- lapply(metrics, function(metric_name) {
    vals <- folds_df$value[folds_df$metric == metric_name]
    n <- length(vals)
    mean_val <- mean(vals)
    sd_val <- if (n > 1L) stats::sd(vals) else NA_real_
    se_val <- if (n <= 1L) {
      NA_real_
    } else if (identical(se_method, "corrected")) {
      sqrt((1 / n + test_train_ratio) * sd_val^2)
    } else {
      sd_val / sqrt(n)
    }
    crit <- if (n > 1L) stats::qt(1 - alpha / 2, df = n - 1L) else NA_real_
    data.frame(
      metric = metric_name,
      mean = mean_val,
      sd = sd_val,
      n = n,
      std_error = se_val,
      conf_level = conf_level,
      conf_low = if (n > 1L) mean_val - crit * se_val else NA_real_,
      conf_high = if (n > 1L) mean_val + crit * se_val else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  .rbind_dt(out)
}

.evaluate_split <- function(data, formula, model, spec, fold, y_all, task,
                            metrics, type, ...) {
  train_data <- data[fold$train, , drop = FALSE]
  test_data <- data[fold$test, , drop = FALSE]
  fit_fold <- fit(formula, train_data, model, spec = spec, ...)
  prob_metrics <- c("logloss", "brier", "auc", "auc_weighted", "ece", "mce")
  type_use <- type %||% if (task == "regression") "response" else if (any(metrics %in% prob_metrics)) "prob" else "class"
  preds <- predict(fit_fold, newdata = test_data, type = type_use)
  truth <- y_all[fold$test]

  prob_matrix <- NULL
  pred_class <- NULL
  if (task == "classification") {
    if (type_use == "prob") {
      prob_matrix <- as.matrix(preds)
      if (is.null(colnames(prob_matrix))) colnames(prob_matrix) <- fit_fold$levels
      pred_class <- factor(fit_fold$levels[max.col(prob_matrix)], levels = fit_fold$levels)
    } else {
      pred_class <- preds
    }
  }

  vals <- vapply(metrics, function(m) {
    if (task == "regression") {
      .loss(truth, preds, task, m)
    } else {
      .loss(truth, pred_class, task, m, prob_matrix = prob_matrix)
    }
  }, numeric(1))

  metrics_df <- data.frame(
    repeat_id = rep(fold$repeat_id, length(metrics)),
    fold = rep(fold$fold, length(metrics)),
    metric = metrics,
    value = vals,
    stringsAsFactors = FALSE
  )
  pred_df <- data.frame(
    row = fold$test,
    repeat_id = rep(fold$repeat_id, length(fold$test)),
    fold = rep(fold$fold, length(fold$test)),
    truth = truth,
    stringsAsFactors = FALSE
  )
  if (task == "regression") {
    pred_df$.pred <- as.numeric(preds)
  } else {
    pred_df$.pred_class <- pred_class
    if (!is.null(prob_matrix)) {
      for (lvl in colnames(prob_matrix)) {
        pred_df[[paste0(".prob_", lvl)]] <- as.numeric(prob_matrix[, lvl])
      }
    }
  }
  list(metrics = metrics_df, predictions = pred_df, fit = fit_fold)
}

.pooled_metrics <- function(predictions, metrics, task) {
  reps <- sort(unique(predictions$repeat_id))
  vals <- vapply(reps, function(r) {
    p <- predictions[predictions$repeat_id == r, , drop = FALSE]
    if (task == "regression") {
      return(vapply(metrics, function(m) .loss(p$truth, p$.pred, task, m), numeric(1)))
    }
    prob_cols <- grep("^\\.prob_", names(p), value = TRUE)
    prob_matrix <- if (length(prob_cols)) {
      pm <- as.matrix(p[, prob_cols, drop = FALSE])
      colnames(pm) <- sub("^\\.prob_", "", prob_cols)
      pm
    } else {
      NULL
    }
    vapply(metrics, function(m) .loss(p$truth, p$.pred_class, task, m, prob_matrix = prob_matrix), numeric(1))
  }, numeric(length(metrics)))
  vals <- matrix(vals, nrow = length(metrics))
  data.frame(
    metric = metrics,
    value = rowMeans(vals),
    n_repeats = length(reps),
    stringsAsFactors = FALSE
  )
}
