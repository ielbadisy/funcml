# Internal predictor adapter for vendored interpretability code.

funcml_predictor <- function(fit, data, formula = fit$formula,
                             type = c("response", "prob"),
                             class_level = NULL, pos_level = NULL) {
  if (!inherits(fit, "funcml_fit")) {
    stop("`fit` must inherit from 'funcml_fit'.", call. = FALSE)
  }

  type <- match.arg(type)
  encoded <- .encode_train(data = data, formula = formula, na_action = fit$na_action)
  predictors <- stats::model.frame(stats::delete.response(encoded$terms), data = data, na.action = fit$na_action)
  task <- encoded$task
  levels <- encoded$levels
  selected_class <- class_level %||% pos_level %||% if (!is.null(levels)) levels[length(levels)] else NULL

  predictor <- list(
    fit = fit,
    formula = formula,
    data = data,
    X = predictors,
    y = encoded$y,
    task = task,
    levels = levels,
    terms = encoded$terms,
    xlevels = encoded$xlevels,
    contrasts = encoded$contrasts,
    type = type,
    class_level = class_level,
    pos_level = pos_level,
    selected_class = selected_class
  )

  predictor$predict <- function(newdata, type = predictor$type,
                                class_level = predictor$class_level,
                                pos_level = predictor$pos_level,
                                drop = FALSE) {
    pred <- predict(
      predictor$fit,
      newdata = newdata,
      type = type,
      class_level = class_level,
      pos_level = pos_level
    )
    if (predictor$task == "regression") {
      return(as.numeric(pred))
    }
    prob <- .normalize_prob_matrix(pred, predictor$levels)
    if (isTRUE(drop)) {
      selected <- class_level %||% pos_level %||% predictor$selected_class
      return(prob[, selected, drop = TRUE])
    }
    prob
  }

  class(predictor) <- "funcml_predictor"
  predictor
}
