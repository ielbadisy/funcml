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
#' @param conf_level Confidence level for learner summary intervals.
#' @param seed Optional seed.
#' @param ncores Optional number of CPU cores used to compare learners. `NULL`
#'   or `1` runs sequentially.
#' @param tune Logical; if `TRUE`, run `tune()` for each learner before comparing.
#' @param grids Optional tuning grids. Supply either a single data frame to reuse
#'   across learners or a named list of data frames keyed by learner id. A
#'   learner without a supplied grid uses [default_tune_grid()]; a learner with
#'   no tunable hyperparameters is evaluated with its own `specs` entry.
#' @param metric Optimization metric used when `tune = TRUE`.
#' @param ... Additional arguments passed to `evaluate()` or `tune()` / `fit()`.
#' @return A `funcml_compare` object.
#' @examples
#' cmp <- compare(
#'   data = mtcars,
#'   formula = mpg ~ wt + hp,
#'   models = c("glm", "rpart"),
#'   resampling = cv(3, seed = 1),
#'   metrics = c("rmse", "mae")
#' )
#' cmp$results
#' @export
compare <- function(data, formula, models, specs = NULL,
                             resampling = cv(5), metrics = NULL, type = NULL,
                             conf_level = 0.95, seed = NULL, ncores = NULL,
                             tune = FALSE, grids = NULL,
                             metric = NULL, ...) {
  ncores <- .validate_ncores(ncores)
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
  model_ids <- seq_along(models)
  model_seeds <- .task_seeds(seed, length(model_ids))

  if (!isTRUE(tune)) {
    res <- .funcml_map(model_ids, function(i) {
      model_id <- models[[i]]
      eval_args <- c(
        list(
          data = data,
          formula = formula,
          model = model_id,
          spec = specs[[model_id]] %||% list(),
          resampling = resampling,
          metrics = metrics,
          type = type,
          conf_level = conf_level,
          seed = model_seeds[[i]],
          ncores = NULL
        ),
        dots
      )
      obj <- do.call(evaluate, eval_args)
      out <- obj$summary
      out$model <- model_id
      out$tuned <- FALSE
      # Return the detail with the summary: assigning it into `details` from
      # inside the worker (`<<-`) is lost when the worker is a forked process.
      list(summary = out, detail = obj)
    }, ncores = ncores)
    rows <- lapply(res, `[[`, "summary")
    for (i in model_ids) details[[models[[i]]]] <- res[[i]]$detail
    results <- .rbind_dt(rows)
    results <- results[, c("model", "metric", "mean", "sd", "n", "std_error", "conf_level", "conf_low", "conf_high", "tuned")]
    rownames(results) <- NULL
    results$rank <- .compare_rank(results)
  } else {
    res <- .funcml_map(model_ids, function(i) {
      model_id <- models[[i]]
      grid <- .compare_grid_for_model(grids, model_id, data = data, formula = formula)
      # A learner with no hyperparameters (grid NULL) is evaluated with its own spec.
      tune_obj <- if (is.null(grid)) {
        NULL
      } else {
        tune_args <- c(
          list(
            data = data,
            formula = formula,
            model = model_id,
            grid = grid,
            resampling = resampling,
            metric = optimize_metric,
            type = type,
            seed = model_seeds[[i]],
            ncores = NULL
          ),
          specs[[model_id]] %||% list(),
          dots
        )
        do.call(tune_fn, tune_args)
      }
      best_spec <- if (is.null(tune_obj)) specs[[model_id]] %||% list() else tune_obj$fit_best$spec

      eval_args <- c(
        list(
          data = data,
          formula = formula,
          model = model_id,
          spec = best_spec,
          resampling = resampling,
          metrics = metrics_use,
          type = type,
          conf_level = conf_level,
          seed = model_seeds[[i]],
          ncores = NULL
        ),
        dots
      )
      eval_obj <- do.call(evaluate, eval_args)

      out <- eval_obj$summary
      out$model <- model_id
      out$tuned <- !is.null(tune_obj)
      out$best_spec <- .format_compare_spec(.strip_control_spec(best_spec))
      out$opt_metric <- optimize_metric
      list(summary = out, detail = list(tune = tune_obj, evaluate = eval_obj))
    }, ncores = ncores)
    rows <- lapply(res, `[[`, "summary")
    for (i in model_ids) details[[models[[i]]]] <- res[[i]]$detail
    results <- .rbind_dt(rows)
    results <- results[, c("model", "metric", "mean", "sd", "n", "std_error", "conf_level", "conf_low", "conf_high", "tuned", "best_spec", "opt_metric")]
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

.compare_grid_for_model <- function(grids, model_id, data = NULL, formula = NULL) {
  if (is.data.frame(grids)) {
    return(grids)
  }
  if (!is.null(grids) && !is.list(grids)) {
    stop("`grids` must be NULL, a data frame, or a named list of data frames.", call. = FALSE)
  }
  if (!is.null(grids) && !is.null(grids[[model_id]])) {
    return(grids[[model_id]])
  }
  # No grid supplied for this learner: use the built-in default grid.
  default_tune_grid(model_id, data = data, formula = formula)
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

#' Methods for learner comparison results.
#'
#' These methods provide the standard `print()`, `summary()`, and `plot()`
#' interfaces for `funcml_compare` objects.
#'
#' @param x A `funcml_compare` object.
#' @param object A `funcml_compare` object.
#' @param digits Number of digits numeric columns are rounded to when printed.
#' @param ... Additional arguments passed to the underlying method.
#' @return `print()` and `summary()` return the input object or results table
#'   invisibly. `plot()` returns a `ggplot2` object.
#'
#' @name compare-methods
#' @aliases print.funcml_compare summary.funcml_compare plot.funcml_compare
#' @examples
#' cmp <- compare(
#'   data = mtcars,
#'   formula = mpg ~ wt + hp,
#'   models = c("glm", "rpart"),
#'   resampling = cv(3, seed = 1),
#'   metrics = c("rmse", "mae")
#' )
#' print(cmp)
#' summary(cmp)
#' plot(cmp)
#' @export
print.funcml_compare <- function(x, digits = 4L, ...) {
  cat(sprintf("<funcml_compare> task: %s | tuned: %s\n", x$task, x$tuned))
  print(.round_numeric_df(x$results, digits = digits))
  invisible(x)
}

#' @rdname compare-methods
#' @export
summary.funcml_compare <- function(object, digits = 4L, ...) {
  print(.round_numeric_df(object$results, digits = digits))
  invisible(object$results)
}

#' @rdname compare-methods
#' @export
plot.funcml_compare <- function(x, ...) {
  df <- x$results
  ggplot2::ggplot(df, ggplot2::aes(x = mean, y = stats::reorder(model, mean))) +
    ggplot2::geom_segment(ggplot2::aes(x = conf_low, xend = conf_high, yend = stats::reorder(model, mean)), linewidth = 0.45, colour = .funcml_palette$accent) +
    ggplot2::geom_point(size = 2.4, colour = "black") +
    ggplot2::coord_flip() +
    ggplot2::facet_wrap(~metric, scales = "free_x") +
    ggplot2::labs(
      x = "Mean cross-validated metric",
      y = NULL,
      title = if (x$tuned) "Tuned learner comparison" else "Learner comparison"
    ) +
    theme_funcml()
}
