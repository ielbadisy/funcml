# Registry wrapper around the `fastgbm` package.
#
# `fastgbm` is a histogram-based gradient boosting engine (compiled via
# RcppParallel) covering regression, binary, and multiclass objectives, and
# is wired in here as an additional tree-ensemble learner alongside `gbm`,
# `xgboost`, and `lightgbm`. Only its regression/binary/multiclass
# objectives are used; its survival objectives (cox/aft/pexp) are outside
# funcml's task scope.

.fastgbm_fit <- function(X, y, spec, task, levels, ...) {
  assert_package("fastgbm", "fastgbm")

  fastgbm_objective <- if (identical(task, "regression")) {
    "regression"
  } else if (length(levels) > 2L) {
    "multiclass"
  } else {
    "binary"
  }

  fit <- fastgbm::fastgbm(
    x = X,
    y = y,
    objective = fastgbm_objective,
    ntrees = spec$ntrees %||% 200L,
    learning_rate = spec$learning_rate %||% 0.1,
    max_depth = spec$max_depth %||% 5L,
    min_node_size = spec$min_node_size %||% 10L,
    max_bins = spec$max_bins %||% 255L,
    subsample = spec$subsample %||% 0.8,
    colsample = spec$colsample %||% 0.8,
    lambda = spec$lambda %||% 1,
    gamma = spec$gamma %||% 0,
    min_child_weight = spec$min_child_weight %||% 1,
    threads = spec$threads %||% 0L,
    seed = spec$seed %||% 1L,
    verbose = isTRUE(spec$verbose %||% FALSE)
  )

  list(state = fit, task = task, levels = levels)
}

.fastgbm_predict <- function(state, Xnew, type, levels, ...) {
  fit <- state$state

  if (identical(state$task, "regression")) {
    return(as.numeric(predict(fit, newdata = Xnew, type = "response")))
  }

  if (length(levels) > 2L) {
    if (identical(type, "class")) {
      pred <- predict(fit, newdata = Xnew, type = "class")
      return(factor(as.character(pred), levels = levels))
    }
    prob <- predict(fit, newdata = Xnew, type = "prob")
    out <- matrix(0, nrow = nrow(prob), ncol = length(levels), dimnames = list(NULL, levels))
    common <- intersect(colnames(prob), levels)
    out[, common] <- prob[, common, drop = FALSE]
    return(out)
  }

  prob1 <- as.numeric(predict(fit, newdata = Xnew, type = "response"))
  if (identical(type, "class")) {
    return(factor(levels[ifelse(prob1 >= 0.5, 2L, 1L)], levels = levels))
  }
  prob_mat <- cbind(1 - prob1, prob1)
  colnames(prob_mat) <- levels
  prob_mat
}
