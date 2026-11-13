#' Compare multiple learners with optional tuning.
#'
#' All learners are scored on the same resampling splits. The folds are drawn
#' once, after setting `seed` (or from `resampling`'s own seed), and shared by
#' every learner, so differences between learners are not confounded with
#' differences between fold assignments. The frozen splits are returned in
#' `$resampling`; passing that object to [evaluate()] or [compare()] on the
#' same data reuses them.
#'
#' With `tune = TRUE` and `nested = TRUE` (the default), performance is
#' estimated by nested resampling: within each outer training fold the grid is
#' tuned by an inner resampling (`inner_resampling`, default the same
#' specification as `resampling`, redrawn on the training rows), the selected
#' configuration is refit on that training fold, and it is scored on the
#' outer test fold. The tuning never sees the test fold, so the estimate is
#' not optimistically biased by the selection. The reported `best_spec` is the
#' configuration selected by tuning on the full data over the shared folds,
#' which is the configuration you would deploy. `nested = FALSE` restores the
#' older, faster behaviour of tuning and scoring on the same folds; that
#' estimate is optimistic (the best of many configurations on the very folds
#' used to pick it) and should not be reported as a performance estimate.
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
#' @param seed Optional seed. It fixes the shared folds (when `resampling`
#'   has no seed of its own) and the per-learner random streams.
#' @param ncores Optional number of CPU cores used to compare learners. `NULL`
#'   or `1` runs sequentially.
#' @param tune Logical; if `TRUE`, run `tune()` for each learner before comparing.
#' @param grids Optional tuning grids. Supply either a single data frame to reuse
#'   across learners or a named list of data frames keyed by learner id. A
#'   learner without a supplied grid uses [defaulttunegrid()]; a learner with
#'   no tunable hyperparameters is evaluated with its own `specs` entry.
#' @param metric Optimization metric used when `tune = TRUE`.
#' @param nested Logical; when `tune = TRUE`, estimate performance by nested
#'   resampling (default `TRUE`). See Details.
#' @param inner_resampling Optional resampling object for the inner tuning
#'   loop when `nested = TRUE`. Defaults to the specification of `resampling`.
#' @param ... Additional arguments passed to `evaluate()` or `tune()` / `fit()`.
#' @return A `funcml_compare` object: a list with `results` (one row per
#'   learner and metric), `details` (per-learner evaluation and tuning
#'   objects), `predictions` (out-of-fold predictions of every learner, with a
#'   `model` column and the columns described in [evaluate()]), the shared
#'   `resampling`, and bookkeeping fields. The out-of-fold predictions are on
#'   the same rows and folds for every learner, so they can be used directly
#'   for paired tests (for example DeLong or a paired bootstrap).
#' @examples
#' cmp <- compare(
#'   data = mtcars,
#'   formula = mpg ~ wt + hp,
#'   models = c("glm", "rpart"),
#'   resampling = cv(3, seed = 1),
#'   metrics = c("rmse", "mae")
#' )
#' cmp$results
#' head(cmp$predictions)
#' @export
compare <- function(data, formula, models, specs = NULL,
                             resampling = cv(5), metrics = NULL, type = NULL,
                             conf_level = 0.95, seed = NULL, ncores = NULL,
                             tune = FALSE, grids = NULL,
                             metric = NULL, nested = TRUE,
                             inner_resampling = NULL, ...) {
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

  y <- model.response(model.frame(formula, data, na.action = stats::na.pass))
  task <- infer_task(y)
  if (task == "classification") {
    y <- factor(y)
  }
  # Draw the folds once and freeze them so every learner uses the same splits.
  inner_spec <- inner_resampling %||% .resampling_spec_only(resampling)
  resampling <- generate_folds(nrow(data), y, resampling, data = data)
  resampling$fixed <- TRUE

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
      list(summary = out, detail = obj, predictions = obj$predictions)
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
      model_spec <- specs[[model_id]] %||% list()
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
          model_spec,
          dots
        )
        do.call(tune_fn, tune_args)
      }
      best_spec <- if (is.null(tune_obj)) model_spec else tune_obj$fit_best$spec

      selected <- NULL
      if (!is.null(tune_obj) && isTRUE(nested)) {
        nested_res <- .compare_nested_eval(
          data = data, formula = formula, model = model_id,
          grid_fn = function(d) .compare_grid_for_model(grids, model_id, data = d, formula = formula),
          model_spec = model_spec, resampling = resampling,
          inner_resampling = inner_spec, optimize_metric = optimize_metric,
          metrics = metrics_use, type = type, task = task, y = y,
          conf_level = conf_level, seed = model_seeds[[i]], tune_fn = tune_fn,
          dots = dots
        )
        eval_obj <- nested_res$evaluate
        selected <- nested_res$selected
      } else {
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
      }

      out <- eval_obj$summary
      out$model <- model_id
      out$tuned <- !is.null(tune_obj)
      out$best_spec <- .format_compare_spec(.strip_control_spec(best_spec))
      out$opt_metric <- optimize_metric
      list(
        summary = out,
        detail = list(tune = tune_obj, evaluate = eval_obj, selected_specs = selected),
        predictions = eval_obj$predictions
      )
    }, ncores = ncores)
    rows <- lapply(res, `[[`, "summary")
    for (i in model_ids) details[[models[[i]]]] <- res[[i]]$detail
    results <- .rbind_dt(rows)
    results <- results[, c("model", "metric", "mean", "sd", "n", "std_error", "conf_level", "conf_low", "conf_high", "tuned", "best_spec", "opt_metric")]
    rownames(results) <- NULL
    results$rank <- .compare_rank(results)
  }

  predictions <- .rbind_dt(lapply(model_ids, function(i) {
    p <- res[[i]]$predictions
    if (is.null(p) || !nrow(p)) return(NULL)
    cbind(model = models[[i]], p, stringsAsFactors = FALSE)
  }))

  out <- list(
    call = match.call(),
    task = task,
    tuned = isTRUE(tune),
    nested = isTRUE(tune) && isTRUE(nested),
    metric = if (isTRUE(tune)) optimize_metric else NULL,
    results = results,
    details = details,
    predictions = predictions,
    resampling = resampling
  )
  class(out) <- "funcml_compare"
  out
}

# Resampling specification without any drawn folds, so it can be redrawn on
# a subset of the data (inner tuning loop).
.resampling_spec_only <- function(resampling) {
  resampling$folds <- NULL
  resampling$fixed <- NULL
  resampling$n <- NULL
  resampling
}

.compare_nested_eval <- function(data, formula, model, grid_fn, model_spec,
                                 resampling, inner_resampling, optimize_metric,
                                 metrics, type, task, y, conf_level, seed,
                                 tune_fn, dots) {
  folds <- resampling$folds
  fold_seeds <- .task_seeds(seed, length(folds))
  if (is.null(metrics)) {
    metrics <- optimize_metric
  }
  per_fold <- lapply(seq_along(folds), function(k) {
    fold <- folds[[k]]
    if (!is.null(fold_seeds[[k]])) set.seed(fold_seeds[[k]])
    train_data <- data[fold$train, , drop = FALSE]
    # Default grids depend on the data size (e.g. kknn's k), so they are
    # rebuilt on each outer training fold; user grids are used as given.
    inner <- do.call(tune_fn, c(
      list(
        data = train_data,
        formula = formula,
        model = model,
        grid = grid_fn(train_data),
        resampling = inner_resampling,
        metric = optimize_metric,
        type = type,
        seed = fold_seeds[[k]],
        ncores = NULL
      ),
      model_spec,
      dots
    ))
    split <- do.call(.evaluate_split, c(
      list(
        data = data, formula = formula, model = model,
        spec = inner$fit_best$spec, fold = fold, y_all = y, task = task,
        metrics = metrics, type = type
      ),
      dots
    ))
    split$selected <- .format_compare_spec(.strip_control_spec(inner$fit_best$spec))
    split
  })
  folds_df <- .rbind_dt(lapply(per_fold, `[[`, "metrics"))
  eval_obj <- list(
    folds = folds_df,
    summary = .summarize_metric_uncertainty(
      folds_df,
      conf_level = conf_level,
      test_train_ratio = .test_train_ratio(folds)
    ),
    predictions = .rbind_dt(lapply(per_fold, `[[`, "predictions")),
    pooled = NULL,
    call = NULL,
    task = task,
    model = model,
    resampling = resampling,
    se_method = "naive",
    nested = TRUE
  )
  class(eval_obj) <- "funcml_eval"
  selected <- data.frame(
    repeat_id = vapply(folds, function(f) as.integer(f$repeat_id), integer(1)),
    fold = vapply(folds, function(f) as.integer(f$fold), integer(1)),
    selected_spec = vapply(per_fold, `[[`, character(1), "selected"),
    stringsAsFactors = FALSE
  )
  list(evaluate = eval_obj, selected = selected)
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
  defaulttunegrid(model_id, data = data, formula = formula)
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
  if (isTRUE(x$tuned)) {
    cat(if (isTRUE(x$nested)) {
      "Performance: nested resampling (tuning inside each outer training fold).\n"
    } else {
      "Performance: tuned and scored on the same folds (optimistic; see `nested` in ?compare).\n"
    })
  }
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
    themefuncml()
}
