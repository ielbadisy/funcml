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
#' @param tuned Alias for `tune`, kept because the results table and `print()`
#'   output label the column `tuned`. If supplied (non-`NULL`), it overrides
#'   `tune`.
#' @param grids Optional tuning grids, used only when `tune = TRUE`. Leave `NULL`
#'   (the default) to tune each learner over its built-in grid (see
#'   [default_grid()]). Supply a single data frame to reuse one grid across every
#'   learner, or a named list of data frames keyed by learner id to override
#'   individual learners; any learner absent from the list falls back to its
#'   built-in grid. Learners with no tunable hyperparameters (e.g. `glm`, `lda`,
#'   `qda`, `fda`, `naivebayes`, `gam`) are fitted once at their defaults and
#'   reported with `tuned = FALSE`.
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
                             metric = NULL, tuned = NULL, ...) {
  if (!is.null(tuned)) {
    if (!is.logical(tuned) || length(tuned) != 1L || is.na(tuned)) {
      stop("`tuned` must be a single logical value.", call. = FALSE)
    }
    tune <- tuned
  }
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
    rows <- .funcml_map(model_ids, function(i) {
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
      details[[model_id]] <<- obj
      out <- obj$summary
      out$model <- model_id
      out$tuned <- FALSE
      out
    }, ncores = ncores)
    results <- .rbind_dt(rows)
    results <- results[, c("model", "metric", "mean", "sd", "n", "std_error", "conf_level", "conf_low", "conf_high", "tuned")]
    rownames(results) <- NULL
    results$rank <- .compare_rank(results)
  } else {
    rows <- .funcml_map(model_ids, function(i) {
      model_id <- models[[i]]
      grid <- .compare_grid_for_model(grids, model_id)

      if (is.null(grid)) {
        eval_args <- c(
          list(
            data = data,
            formula = formula,
            model = model_id,
            spec = specs[[model_id]] %||% list(),
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
        details[[model_id]] <<- list(tune = NULL, evaluate = eval_obj)

        out <- eval_obj$summary
        out$model <- model_id
        out$tuned <- FALSE
        out$best_spec <- NA_character_
        out$opt_metric <- NA_character_
        return(out)
      }

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
          conf_level = conf_level,
          seed = model_seeds[[i]],
          ncores = NULL
        ),
        dots
      )
      eval_obj <- do.call(evaluate, eval_args)
      details[[model_id]] <<- list(tune = tune_obj, evaluate = eval_obj)

      out <- eval_obj$summary
      out$model <- model_id
      out$tuned <- TRUE
      out$best_spec <- .format_compare_spec(.strip_control_spec(tune_obj$fit_best$spec))
      out$opt_metric <- optimize_metric
      out
    }, ncores = ncores)
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

.compare_grid_for_model <- function(grids, model_id) {
  if (is.data.frame(grids)) {
    return(grids)
  }
  if (is.list(grids) && !is.null(grids[[model_id]])) {
    return(grids[[model_id]])
  }
  default_grid(model_id)
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
