#' Compare multiple learners with optional tuning.
#'
#' @param data Data frame.
#' @param formula Model formula.
#' @param models Character vector of learner ids.
#' @param specs Optional named list of fixed specs per learner.
#' @param resampling Resampling object from `cv()`.
#' @param metrics Character vector of metrics to report. When `tune = TRUE`,
#'   these are computed for each learner's tuned best configuration.
#' @param type Prediction type override.
#' @param seed Optional seed.
#' @param tune Logical; if `TRUE`, run `tune()` for each learner before comparing.
#' @param grids Optional tuning grids. Supply either a single data frame to reuse
#'   across learners or a named list of data frames keyed by learner id.
#' @param metric Optimization metric used when `tune = TRUE`.
#' @param ... Additional arguments passed to `evaluate()` or `tune()` / `fit()`.
#' @return A `funcml_compare` object.
#' @export
compare_learners <- function(data, formula, models, specs = NULL,
                             resampling = cv(5), metrics = NULL, type = NULL,
                             seed = NULL, tune = FALSE, grids = NULL,
                             metric = NULL, ...) {
  if (!is.character(models) || !length(models)) {
    stop("`models` must be a non-empty character vector.", call. = FALSE)
  }
  if (anyDuplicated(models)) {
    stop("`models` must not contain duplicates.", call. = FALSE)
  }
  specs <- specs %||% list()
  if (!is.list(specs)) {
    stop("`specs` must be a list.", call. = FALSE)
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }

  y <- model.response(model.frame(formula, data))
  task <- infer_task(y)
  optimize_metric <- metric %||% if (task == "regression") "rmse" else "accuracy"
  metrics_use <- metrics %||% if (isTRUE(tune)) optimize_metric else NULL
  dots <- list(...)
  tune_fn <- get("tune", mode = "function")

  details <- vector("list", length(models))
  names(details) <- models

  if (!isTRUE(tune)) {
    rows <- lapply(models, function(model_id) {
      eval_args <- c(
        list(
          data = data,
          formula = formula,
          model = model_id,
          spec = specs[[model_id]] %||% list(),
          resampling = resampling,
          metrics = metrics,
          type = type,
          seed = seed
        ),
        dots
      )
      obj <- do.call(evaluate, eval_args)
      details[[model_id]] <<- obj
      out <- obj$summary
      out$model <- model_id
      out$tuned <- FALSE
      out
    })
    results <- do.call(rbind, rows)
    results <- results[, c("model", "metric", "mean", "sd", "tuned")]
    rownames(results) <- NULL
    results$rank <- .compare_rank(results)
  } else {
    rows <- lapply(models, function(model_id) {
      grid <- .compare_grid_for_model(grids, model_id)
      tune_args <- c(
        list(
          data = data,
          formula = formula,
          model = model_id,
          grid = grid,
          resampling = resampling,
          metric = optimize_metric,
          type = type,
          seed = seed
        ),
        specs[[model_id]] %||% list(),
        dots
      )
      tune_obj <- do.call(tune_fn, tune_args)

      eval_args <- c(
        list(
          data = data,
          formula = formula,
          model = model_id,
          spec = tune_obj$fit_best$spec,
          resampling = resampling,
          metrics = metrics_use,
          type = type,
          seed = seed
        ),
        dots
      )
      eval_obj <- do.call(evaluate, eval_args)
      details[[model_id]] <<- list(tune = tune_obj, evaluate = eval_obj)

      out <- eval_obj$summary
      out$model <- model_id
      out$tuned <- TRUE
      out$best_spec <- .format_compare_spec(tune_obj$fit_best$spec)
      out$opt_metric <- optimize_metric
      out
    })
    results <- do.call(rbind, rows)
    results <- results[, c("model", "metric", "mean", "sd", "tuned", "best_spec", "opt_metric")]
    rownames(results) <- NULL
    results$rank <- .compare_rank(results)
  }

  out <- list(
    call = match.call(),
    task = task,
    tuned = isTRUE(tune),
    metric = if (isTRUE(tune)) optimize_metric else NULL,
    results = results,
    details = details,
    resampling = resampling
  )
  class(out) <- "funcml_compare"
  out
}

.compare_grid_for_model <- function(grids, model_id) {
  if (is.null(grids)) {
    stop("`grids` must be supplied when `tune = TRUE`.", call. = FALSE)
  }
  if (is.data.frame(grids)) {
    return(grids)
  }
  if (!is.list(grids) || is.null(grids[[model_id]])) {
    stop(sprintf("Missing tuning grid for model '%s'.", model_id), call. = FALSE)
  }
  grids[[model_id]]
}

.format_compare_spec <- function(x, exclude = character()) {
  keep <- setdiff(names(x), exclude)
  keep <- keep[!vapply(x[keep], function(value) is.list(value) || length(value) != 1L, logical(1))]
  if (!length(keep)) {
    return("")
  }
  paste(sprintf("%s=%s", keep, unlist(x[keep], use.names = FALSE)), collapse = ", ")
}

.comparison_score <- function(x, metric) {
  direction <- metric_direction(metric[1])
  if (direction == "min") x else -x
}

.compare_rank <- function(df) {
  out <- integer(nrow(df))
  for (m in unique(df$metric)) {
    idx <- which(df$metric == m)
    ord <- order(.comparison_score(df$mean[idx], m))
    out[idx][ord] <- seq_along(idx)
  }
  out
}

#' @export
print.funcml_compare <- function(x, ...) {
  cat(sprintf("<funcml_compare> task: %s | tuned: %s\n", x$task, x$tuned))
  print(x$results)
  invisible(x)
}

#' @export
summary.funcml_compare <- function(object, ...) {
  print(object$results)
  invisible(object$results)
}

#' @export
plot.funcml_compare <- function(x, ...) {
  df <- x$results
  ggplot2::ggplot(df, ggplot2::aes(x = stats::reorder(model, mean), y = mean)) +
    ggplot2::geom_errorbar(ggplot2::aes(ymin = mean - sd, ymax = mean + sd), width = 0.18, alpha = 0.45, colour = .funcml_palette$context) +
    ggplot2::geom_point(color = .funcml_palette$accent_alt, size = 2.6) +
    ggplot2::coord_flip() +
    ggplot2::facet_wrap(~metric, scales = "free_x") +
    ggplot2::labs(
      x = "Model",
      y = "Mean score",
      title = if (x$tuned) "Tuned learner comparison" else "Learner comparison"
    ) +
    theme_funcml()
}
