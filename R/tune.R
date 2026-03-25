#' Simple grid search tuning.
#'
#' @param data Data frame.
#' @param formula Model formula.
#' @param model Learner id.
#' @param grid Data frame of hyperparameter combinations.
#' @param resampling Resampling object.
#' @param metric Metric to optimize.
#' @param type Prediction type override.
#' @param seed Optional seed.
#' @param ... Passed to `fit()`.
#' @return A `funcml_tune` object.
#' @export
tune <- function(data, formula, model, grid, resampling = cv(5),
                 metric = NULL, type = NULL, seed = NULL, ...) {
  if (is.null(metric)) {
    task <- infer_task(model.response(model.frame(formula, data)))
    metric <- if (task == "regression") "rmse" else "accuracy"
  }
  dirs <- metric_direction(metric)
  rows <- split(grid, seq_len(nrow(grid)))
  results <- lapply(rows, function(row) {
    spec_row <- as.list(row)
    eval_row <- evaluate(data, formula, model, spec = spec_row, resampling = resampling,
                         metrics = metric, type = type, seed = seed, ...)
    c(spec_row, mean = eval_row$summary$mean[eval_row$summary$metric == metric],
      sd = eval_row$summary$sd[eval_row$summary$metric == metric])
  })
  results_df <- do.call(rbind, lapply(results, function(x) as.data.frame(as.list(x), stringsAsFactors = FALSE)))
  best_idx <- if (dirs == "min") which.min(results_df$mean) else which.max(results_df$mean)
  best_spec <- as.list(grid[best_idx, , drop = FALSE])
  fit_best <- fit(formula, data, model, spec = best_spec, ...)

  out <- list(
    results = results_df,
    best = results_df[best_idx, , drop = FALSE],
    fit_best = fit_best,
    metric = metric,
    direction = dirs,
    call = match.call()
  )
  class(out) <- "funcml_tune"
  out
}

metric_direction <- function(metric) {
  if (metric %in% c("rmse", "mae", "logloss", "brier")) "min" else "max"
}

#' @export
print.funcml_tune <- function(x, ...) {
  cat(sprintf("<funcml_tune> metric=%s direction=%s\n", x$metric, x$direction))
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
    ggplot2::geom_segment(ggplot2::aes(x = mean - sd, xend = mean + sd, yend = config_label), linewidth = 0.35, colour = "grey45") +
    ggplot2::geom_point(size = 2.2, colour = "black") +
    ggplot2::geom_point(data = df[df$config_label == best_label, , drop = FALSE], size = 2.8, colour = "#2b8cbe") +
    ggplot2::labs(
      x = sprintf("%s (%s)", toupper(x$metric), x$direction),
      y = NULL,
      title = "Grid search results"
    ) +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}
