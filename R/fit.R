#' Fit a model using a formula-first functional interface.
#'
#' Registered learner ids currently include:
#' regression and classification: `glm`, `rpart`, `glmnet`, `ranger`, `nnet`,
#' `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`,
#' `lightgbm`, `catboost`, `xgboost`, `stacking`, `superlearner`;
#' regression plus binary classification: `gam`, `bart`;
#' classification only: `C50`, `naivebayes`, `fda`, `lda`, `qda`;
#' binary classification only: `adaboost`;
#' regression plus binary classification: `earth`;
#' regression only: `pls`.
#'
#' These learner backends are declared as package dependencies so the advertised
#' registry is meant to be available after a standard `install.packages("funcml")`
#' installation.
#'
#' @param formula Model formula.
#' @param data Data frame.
#' @param model Learner id (see `learners()`).
#' @param spec Optional list of hyperparameters for the learner.
#' @param seed Optional seed for reproducibility.
#' @param na_action NA handling passed to `model.frame`/`model.matrix` (default `stats::na.fail`).
#' @param ... Additional parameters merged into `spec`.
#' @return An object of class `funcml_fit`.
#' @examples
#' fit_obj <- fit(mpg ~ wt + hp, data = mtcars, model = "glm")
#' predict(fit_obj, newdata = mtcars[1:3, , drop = FALSE])
#' @export
fit <- function(formula, data, model, spec = NULL, seed = NULL, na_action = stats::na.fail, ...) {
  call <- match.call()
  if (!is.null(seed)) set.seed(seed)
  adapter <- funcml_registry(model)
  encoded <- .encode_train(data = data, formula = formula, na_action = na_action)
  task <- encoded$task
  if (!task %in% adapter$tasks) stop(sprintf("Model '%s' does not support %s.", model, task), call. = FALSE)

  spec_full <- merge_spec(adapter$defaults, spec, list(...))
  state <- adapter$fit_xy(encoded$X, encoded$y, spec_full, task = task, levels = encoded$levels)

  obj <- list(
    call = call,
    formula = formula,
    task = task,
    model = model,
    adapter = adapter,
    state = state,
    spec = spec_full,
    terms = encoded$terms,
    xlevels = encoded$xlevels,
    contrasts = encoded$contrasts,
    features = encoded$features,
    has_intercept = encoded$has_intercept,
    levels = encoded$levels,
    na_action = na_action,
    n = nrow(encoded$X),
    predict = NULL
  )

  obj$predict <- create_predict(obj, adapter, state)
  class(obj) <- "funcml_fit"
  obj
}

create_predict <- function(obj, adapter, state) {
  function(newdata, type = NULL, class_level = NULL, pos_level = NULL,
           na_action = obj$na_action, ...) {
    Xnew <- .encode_new(obj, newdata, na_action = na_action)
    .predict_prob_or_response(
      fit = obj,
      adapter = adapter,
      state = state,
      Xnew = Xnew,
      type = type,
      class_level = class_level,
      pos_level = pos_level,
      ...
    )
  }
}

#' Available learners.
#'
#' `learners()` returns the registry keys accepted by [fit()]. Task support is:
#' regression and classification: `glm`, `rpart`, `glmnet`, `ranger`, `nnet`,
#' `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`,
#' `lightgbm`, `catboost`, `xgboost`, `stacking`, `superlearner`;
#' regression plus binary classification: `gam`, `bart`, `earth`;
#' classification only: `C50`, `naivebayes`, `fda`, `lda`, `qda`;
#' binary classification only: `adaboost`;
#' regression only: `pls`.
#'
#' The learner engine packages are declared in `Imports`, so these ids are
#' intended to be available immediately after installing `funcml`.
#' @return Character vector of learner ids.
#' @examples
#' learners()
#' @export
learners <- function() {
  names(funcml_registry())
}

#' @export
print.funcml_fit <- function(x, ...) {
  cat(sprintf("<funcml_fit> %s model: %s\n", x$task, x$model))
  cat(sprintf("Formula: %s\n", deparse(x$formula)))
  cat(sprintf("Features: %d | Obs: %d\n", length(x$features), x$n))
  invisible(x)
}

#' @export
summary.funcml_fit <- function(object, ...) {
  cat(sprintf("<funcml_fit summary> %s model: %s\n", object$task, object$model))
  cat("Spec:\n")
  print(object$spec)
  invisible(object)
}

#' @export
predict.funcml_fit <- function(object, newdata, type = NULL, class_level = NULL,
                              pos_level = NULL, na_action = object$na_action, ...) {
  object$predict(newdata = newdata, type = type, class_level = class_level,
                 pos_level = pos_level, na_action = na_action, ...)
}

# Optional helper for models exposing coefficients.
#' @export
coef.funcml_fit <- function(object, ...) {
  if (is.null(object$state$state)) stop("Coefficients not available for this model.", call. = FALSE)
  if (!inherits(object$state$state, c("glm", "lm"))) stop("Coefficients not available for this model.", call. = FALSE)
  stats::coef(object$state$state)
}
