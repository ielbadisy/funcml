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
#' @param seed Optional seed.
#' @param ... Passed to `fit()`.
#' @return A `funcml_tune` object.
#' @export
tune <- function(data, formula, model, grid, resampling = cv(5),
                 metric = NULL, type = NULL,
                 search = c("grid", "random"), n_evals = NULL,
                 seed = NULL, ...) {
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
  rows <- split(search_grid, seq_len(nrow(search_grid)))
  results <- lapply(rows, function(row) {
    spec_row <- as.list(row)
    eval_row <- evaluate(data, formula, model, spec = spec_row, resampling = resampling,
                         metrics = metric, type = type, seed = seed, ...)
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
  })
  results_df <- do.call(rbind, lapply(results, function(x) as.data.frame(as.list(x), stringsAsFactors = FALSE)))
  best_idx <- if (dirs == "min") which.min(results_df$mean) else which.max(results_df$mean)
  best_spec <- as.list(search_grid[best_idx, , drop = FALSE])
  fit_best <- fit(formula, data, model, spec = best_spec, ...)

  out <- list(
    results = results_df,
    best = results_df[best_idx, , drop = FALSE],
    fit_best = fit_best,
    metric = metric,
    direction = dirs,
    search = search,
    n_evals = nrow(search_grid),
    candidates = nrow(grid),
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
  if (metric %in% c("rmse", "mae", "logloss", "brier")) "min" else "max"
}

#' @export
print.funcml_tune <- function(x, ...) {
  cat(sprintf("<funcml_tune> metric=%s direction=%s search=%s\n", x$metric, x$direction, x$search))
  cat("Best:\n")
  print(x$best)
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
