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
#' @param seed Optional seed.
#' @param fit Optional preconfigured `funcml_fit` object (re-fit per fold).
#' @param ncores Optional number of CPU cores used to evaluate resampling folds.
#'   `NULL` or `1` runs sequentially.
#' @param ... Passed to `fit()`.
#' @return A `funcml_eval` object.
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
                     ncores = NULL, ...) {
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

  y_all <- model.response(model.frame(formula, data))
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
    train_data <- data[fold$train, , drop = FALSE]
    test_data  <- data[fold$test, , drop = FALSE]
    fit_fold <- fit(formula, train_data, base_model, spec = base_spec, ...)
    type_use <- type %||% if (task == "regression") "response" else if (any(metrics %in% c("logloss", "brier", "auc", "auc_weighted", "ece", "mce"))) "prob" else "class"
    preds <- predict(fit_fold, newdata = test_data, type = type_use)

    prob_matrix <- NULL
    pred_class <- NULL
    if (task == "classification") {
      if (type_use == "prob") {
        prob_matrix <- as.matrix(preds)
        if (is.null(colnames(prob_matrix))) colnames(prob_matrix) <- fit_fold$levels
        pred_class <- fit_fold$levels[max.col(prob_matrix)]
        pred_class <- factor(pred_class, levels = fit_fold$levels)
      } else {
        pred_class <- preds
      }
    }

    vals <- vapply(metrics, function(m) {
      if (task == "regression") {
        .loss(y_all[fold$test], preds, task, m)
      } else if (m %in% c("logloss", "brier", "auc", "auc_weighted", "ece", "mce")) {
        .loss(y_all[fold$test], pred_class, task, m, prob_matrix = prob_matrix)
      } else {
        .loss(y_all[fold$test], pred_class, task, m, prob_matrix = prob_matrix)
      }
    }, numeric(1))

    data.frame(
      repeat_id = rep(fold$repeat_id, length(metrics)),
      fold = rep(fold$fold, length(metrics)),
      metric = metrics,
      value = vals,
      stringsAsFactors = FALSE
    )
  }, ncores = ncores)

  folds_df <- do.call(rbind, folds_out)
  # Aggregate fold metrics into mean/sd columns explicitly to avoid the
  # list/matrix column shape that `aggregate()` produces when the function
  # returns a vector. The previous approach created a 2-column matrix inside a
  # single `value` column, which then failed when assigning back to a data
  # frame (replacement length mismatch on some R versions).
  summary_df <- .summarize_metric_uncertainty(folds_df, conf_level = conf_level)

  out <- list(
    folds = folds_df,
    summary = summary_df,
    call = match.call(),
    task = task,
    model = base_model,
    resampling = resampling
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
print.funcml_eval <- function(x, ...) {
  cat(sprintf("<funcml_eval> model: %s | task: %s\n", x$model, x$task))
  print(x$summary)
  invisible(x)
}

#' @rdname evaluate-methods
#' @export
summary.funcml_eval <- function(object, ...) {
  print(object$summary)
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
      colour = "#2b8cbe"
    ) +
    ggplot2::labs(x = "Cross-validated metric value", y = NULL, title = "Cross-validation performance") +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

.summarize_metric_uncertainty <- function(folds_df, conf_level = 0.95) {
  metrics <- unique(folds_df$metric)
  alpha <- 1 - conf_level
  out <- lapply(metrics, function(metric_name) {
    vals <- folds_df$value[folds_df$metric == metric_name]
    n <- length(vals)
    mean_val <- mean(vals)
    sd_val <- if (n > 1L) stats::sd(vals) else NA_real_
    se_val <- if (n > 1L) sd_val / sqrt(n) else NA_real_
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
  do.call(rbind, out)
}
