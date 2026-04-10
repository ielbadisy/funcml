#' Hyperparameter tuning via grid or random search.
#'
#' @param data Data frame.
#' @param formula Model formula.
#' @param model Learner id.
#' @param grid Data frame of hyperparameter combinations.
#' @param resampling Resampling object.
#' @param metric Metric to optimize.
#' @param type Prediction type override.
#' @param search Search strategy: `"grid"` or `"random"`.
#' @param n_evals Maximum number of configurations to evaluate when
#'   `search = "random"`.
#' @param outer_resampling Optional outer resampling object. When supplied,
#'   `tune()` performs nested resampling and reports outer-fold performance
#'   estimates for the tuned model-selection procedure.
#' @param seed Optional seed.
#' @param ncores Optional number of CPU cores used for tuning tasks. `NULL` or
#'   `1` runs sequentially.
#' @param ... Passed to `fit()`.
#' @return A `funcml_tune` object.
#' @examples
#' tune_obj <- tune(
#'   data = mtcars,
#'   formula = mpg ~ wt + hp,
#'   model = "rpart",
#'   grid = expand.grid(cp = c(0.001, 0.01), minsplit = c(5, 10)),
#'   resampling = cv(3, seed = 1),
#'   metric = "rmse"
#' )
#' tune_obj$best
#' @export
tune <- function(data, formula, model, grid, resampling = cv(5),
                 metric = NULL, type = NULL,
                 search = c("grid", "random"), n_evals = NULL,
                 outer_resampling = NULL, seed = NULL,
                 ncores = NULL, ...) {
  ncores <- .validate_ncores(ncores)
  search <- match.arg(search)
  if (!is.data.frame(grid) || !nrow(grid)) {
    stop("`grid` must be a non-empty data frame.", call. = FALSE)
  }
  if (is.null(metric)) {
    task <- infer_task(model.response(model.frame(formula, data)))
    metric <- if (task == "regression") "rmse" else "accuracy"
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }
  dirs <- metric_direction(metric)
  search_grid <- .select_tuning_configs(grid, search = search, n_evals = n_evals)
  nested <- NULL
  if (!is.null(outer_resampling)) {
    nested <- .nested_resampling_summary(
      data = data,
      formula = formula,
      model = model,
      grid = grid,
      resampling = resampling,
      outer_resampling = outer_resampling,
      metric = metric,
      type = type,
      search = search,
      n_evals = n_evals,
      seed = seed,
      ncores = ncores,
      ...
    )
  }
  rows <- split(search_grid, seq_len(nrow(search_grid)))
  row_ids <- seq_along(rows)
  row_seeds <- .task_seeds(seed, length(row_ids))
  results <- .funcml_map(row_ids, function(i) {
    row <- rows[[i]]
    spec_row <- as.list(row)
    eval_row <- evaluate(data, formula, model, spec = spec_row, resampling = resampling,
                         metrics = metric, type = type, seed = row_seeds[[i]],
                         ncores = NULL, ...)
    summary_row <- eval_row$summary[eval_row$summary$metric == metric, , drop = FALSE]
    c(
      spec_row,
      mean = summary_row$mean,
      sd = summary_row$sd,
      n = summary_row$n,
      std_error = summary_row$std_error,
      conf_level = summary_row$conf_level,
      conf_low = summary_row$conf_low,
      conf_high = summary_row$conf_high
    )
  }, ncores = ncores)
  results_df <- do.call(rbind, lapply(results, function(x) as.data.frame(as.list(x), stringsAsFactors = FALSE)))
  best_idx <- if (dirs == "min") which.min(results_df$mean) else which.max(results_df$mean)
  best_spec <- as.list(search_grid[best_idx, , drop = FALSE])
  fit_best <- fit(formula, data, model, spec = best_spec, ...)
  fit_best$spec <- .strip_control_spec(fit_best$spec)

  out <- list(
    results = results_df,
    best = results_df[best_idx, , drop = FALSE],
    fit_best = fit_best,
    metric = metric,
    direction = dirs,
    search = search,
    n_evals = nrow(search_grid),
    candidates = nrow(grid),
    nested = nested,
    call = match.call()
  )
  class(out) <- "funcml_tune"
  out
}

.select_tuning_configs <- function(grid, search = "grid", n_evals = NULL) {
  if (search == "grid") {
    return(grid)
  }
  if (is.null(n_evals)) {
    stop("`n_evals` must be supplied when `search = \"random\"`.", call. = FALSE)
  }
  if (!is.numeric(n_evals) || length(n_evals) != 1L || n_evals < 1) {
    stop("`n_evals` must be a positive integer.", call. = FALSE)
  }
  n_take <- min(nrow(grid), as.integer(n_evals))
  grid[sample.int(nrow(grid), size = n_take, replace = FALSE), , drop = FALSE]
}

metric_direction <- function(metric) {
  if (metric %in% c("rmse", "mae", "mse", "medae", "mape", "logloss", "brier", "ece", "mce")) "min" else "max"
}

#' @export
print.funcml_tune <- function(x, ...) {
  cat(sprintf("<funcml_tune> metric=%s direction=%s search=%s\n", x$metric, x$direction, x$search))
  cat("Best:\n")
  print(x$best)
  if (!is.null(x$nested)) {
    cat("Nested resampling:\n")
    print(x$nested$summary)
  }
  invisible(x)
}

#' @export
summary.funcml_tune <- function(object, ...) {
  print(object$results)
  invisible(object$results)
}

#' @export
plot.funcml_tune <- function(x, ...) {
  df <- x$results
  df$config_label <- .format_tune_config(df)
  ord <- if (x$direction == "max") order(df$mean, decreasing = TRUE) else order(df$mean, decreasing = FALSE)
  df <- df[ord, , drop = FALSE]
  df$config_label <- factor(df$config_label, levels = rev(df$config_label))
  best_label <- .format_tune_config(x$best)[1]
  ggplot2::ggplot(df, ggplot2::aes(x = mean, y = config_label)) +
    ggplot2::geom_segment(ggplot2::aes(x = conf_low, xend = conf_high, yend = config_label), linewidth = 0.45, colour = "#2b8cbe") +
    ggplot2::geom_point(size = 2.2, colour = "black") +
    ggplot2::geom_point(data = df[df$config_label == best_label, , drop = FALSE], size = 2.8, colour = "#2b8cbe") +
    ggplot2::labs(
      x = sprintf("%s (%s)", toupper(x$metric), x$direction),
      y = NULL,
      title = sprintf("%s search results", tools::toTitleCase(x$search))
    ) +
  ggplot2::theme_bw() +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}

.nested_resampling_summary <- function(data, formula, model, grid, resampling,
                                       outer_resampling, metric, type,
                                       search, n_evals, seed, ncores, ...) {
  y_all <- model.response(model.frame(formula, data))
  task <- infer_task(y_all)
  if (task == "classification") {
    y_all <- factor(y_all)
  }
  outer_resampling <- generate_folds(nrow(data), y_all, outer_resampling, data = data)

  outer_ids <- seq_along(outer_resampling$folds)
  outer_seeds <- .task_seeds(seed, length(outer_ids))
  outer_folds <- .funcml_map(outer_ids, function(i) {
    fold <- outer_resampling$folds[[i]]
    inner_seed <- outer_seeds[[i]]
    train_data <- data[fold$train, , drop = FALSE]
    test_data <- data[fold$test, , drop = FALSE]
    inner_tune <- tune(
      data = train_data,
      formula = formula,
      model = model,
      grid = grid,
      resampling = resampling,
      metric = metric,
      type = type,
      search = search,
      n_evals = n_evals,
      outer_resampling = NULL,
      seed = inner_seed,
      ncores = NULL,
      ...
    )
    metric_value <- .score_tuned_split(
      train_data = train_data,
      test_data = test_data,
      formula = formula,
      model = model,
      spec = inner_tune$fit_best$spec,
      metric = metric,
      type = type,
      seed = inner_seed,
      ...
    )
    spec_label <- .format_tune_config(inner_tune$best)[1]
    data.frame(
      repeat_id = fold$repeat_id,
      fold = fold$fold,
      metric = metric,
      value = metric_value,
      selected_config = spec_label,
      stringsAsFactors = FALSE
    )
  }, ncores = ncores)
  outer_folds <- do.call(rbind, outer_folds)
  list(
    folds = outer_folds,
    summary = .summarize_metric_uncertainty(outer_folds),
    resampling = outer_resampling
  )
}

.score_tuned_split <- function(train_data, test_data, formula, model, spec,
                               metric, type, seed, ...) {
  fit_obj <- fit(formula, train_data, model, spec = spec, seed = seed, ...)
  truth <- model.response(model.frame(formula, test_data))
  if (fit_obj$task == "classification") {
    truth <- factor(truth, levels = fit_obj$levels)
  }

  type_use <- type %||% if (fit_obj$task == "regression") {
    "response"
  } else if (metric %in% c("logloss", "brier", "auc", "auc_weighted", "ece", "mce")) {
    "prob"
  } else {
    "class"
  }

  preds <- predict(fit_obj, newdata = test_data, type = type_use)
  prob_matrix <- NULL
  pred_class <- NULL
  if (fit_obj$task == "classification") {
    if (type_use == "prob") {
      prob_matrix <- as.matrix(preds)
      if (is.null(colnames(prob_matrix))) {
        colnames(prob_matrix) <- fit_obj$levels
      }
      pred_class <- factor(fit_obj$levels[max.col(prob_matrix)], levels = fit_obj$levels)
    } else {
      pred_class <- preds
    }
  }

  if (fit_obj$task == "regression") {
    return(.loss(truth, preds, fit_obj$task, metric))
  }

  .loss(truth, pred_class, fit_obj$task, metric, prob_matrix = prob_matrix)
}
