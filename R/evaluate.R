#' Cross-validated evaluation.
#'
#' @param data Data frame.
#' @param formula Model formula.
#' @param model Learner id (ignored if `fit` supplied).
#' @param spec Hyperparameter list.
#' @param resampling Resampling object from `cv()`.
#' @param metrics Character vector of metric names.
#' @param type Prediction type override.
#' @param seed Optional seed.
#' @param fit Optional preconfigured `funcml_fit` object (re-fit per fold).
#' @param ... Passed to `fit()`.
#' @return A `funcml_eval` object.
#' @export
evaluate <- function(data, formula, model = NULL, spec = NULL,
                     resampling = cv(5), metrics = NULL, type = NULL,
                     seed = NULL, fit = NULL, ...) {
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
  resampling <- generate_folds(nrow(data), y_all, resampling)

  if (is.null(metrics)) {
    metrics <- if (task == "regression") c("rmse", "mae", "rsq") else c("accuracy", "logloss", "brier", if (!is_multiclass) "auc")
    metrics <- unlist(metrics)
  }
  folds_out <- list()
  idx <- 1

  for (fold in resampling$folds) {
    train_data <- data[fold$train, , drop = FALSE]
    test_data  <- data[fold$test, , drop = FALSE]
    fit_fold <- fit(formula, train_data, base_model, spec = base_spec, ...)
    type_use <- type %||% if (task == "regression") "response" else if (any(metrics %in% c("logloss", "brier", "auc"))) "prob" else "class"
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

    for (m in metrics) {
      val <- if (task == "regression") {
        .loss(y_all[fold$test], preds, task, m)
      } else if (m %in% c("logloss", "brier", "auc")) {
        .loss(y_all[fold$test], pred_class, task, m, prob_matrix = prob_matrix)
      } else {
        .loss(y_all[fold$test], pred_class, task, m, prob_matrix = prob_matrix)
      }
      folds_out[[idx]] <- data.frame(
        repeat_id = fold$repeat_id,
        fold = fold$fold,
        metric = m,
        value = val,
        stringsAsFactors = FALSE
      )
      idx <- idx + 1
    }
  }

  folds_df <- do.call(rbind, folds_out)
  # Aggregate fold metrics into mean/sd columns explicitly to avoid the
  # list/matrix column shape that `aggregate()` produces when the function
  # returns a vector. The previous approach created a 2-column matrix inside a
  # single `value` column, which then failed when assigning back to a data
  # frame (replacement length mismatch on some R versions).
  summary_mean <- aggregate(value ~ metric, data = folds_df, FUN = mean)
  summary_sd   <- aggregate(value ~ metric, data = folds_df, FUN = stats::sd)
  summary_df <- summary_mean
  names(summary_df)[names(summary_df) == "value"] <- "mean"
  summary_df$sd <- summary_sd$value

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

#' @export
print.funcml_eval <- function(x, ...) {
  cat(sprintf("<funcml_eval> model: %s | task: %s\n", x$model, x$task))
  print(x$summary)
  invisible(x)
}

#' @export
summary.funcml_eval <- function(object, ...) {
  print(object$summary)
  invisible(object$summary)
}

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
    ggplot2::labs(x = "Cross-validated metric value", y = NULL, title = "Cross-validation performance") +
    ggplot2::theme_bw() +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank())
}
