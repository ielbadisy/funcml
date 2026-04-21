#' Fit a model using the funcml interface.
#'
#' Registered learner ids currently include:
#' regression and classification: `glm`, `rpart`, `glmnet`, `ranger`, `nnet`,
#' `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`,
#' `lightgbm`, `xgboost`, `stacking`, `superlearner`;
#' regression plus binary classification: `gam`, `bart`;
#' classification only: `C50`, `naivebayes`, `fda`, `lda`, `qda`;
#' binary classification only: `adaboost`;
#' regression plus binary classification: `earth`;
#' regression only: `pls`.
#'
#' The learner engine packages are installed with `funcml`, so the advertised
#' registry is intended to be available after a standard installation.
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
  if (identical(task, "classification") && length(encoded$levels) > 2L && !isTRUE(adapter$supports$multiclass)) {
    stop(sprintf("Model '%s' does not support multiclass classification.", model), call. = FALSE)
  }

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
#' `lightgbm`, `xgboost`, `stacking`, `superlearner`;
#' regression plus binary classification: `gam`, `bart`, `earth`;
#' classification only: `C50`, `naivebayes`, `fda`, `lda`, `qda`;
#' binary classification only: `adaboost`;
#' regression only: `pls`.
#'
#' The learner engine packages are installed with `funcml`, so the advertised
#' registry is intended to be available after a standard installation.
#' @return Character vector of learner ids.
#' @examples
#' learners()
#' @export
learners <- function() {
  names(funcml_registry())
}

.learner_engine_packages <- function() {
  c(
    glm = "stats",
    rpart = "rpart",
    glmnet = "glmnet",
    ranger = "ranger",
    nnet = "nnet",
    e1071_svm = "e1071",
    randomForest = "randomForest",
    gbm = "gbm",
    C50 = "C50",
    kknn = "kknn",
    earth = "earth",
    gam = "mgcv",
    naivebayes = "naivebayes",
    fda = "mda",
    adaboost = "ada",
    pls = "pls",
    ctree = "partykit",
    cforest = "partykit",
    lda = "MASS",
    qda = "MASS",
    lightgbm = "lightgbm",
    bart = "dbarts",
    xgboost = "xgboost",
    stacking = "funcml",
    superlearner = "funcml"
  )
}

.interpret_methods_for <- function(adapter) {
  methods <- c("vip", "permute", "pdp", "ice", "ale", "local", "lime", "shap", "interaction", "surrogate")
  if ("classification" %in% adapter$tasks) {
    methods <- c(methods, "calibration")
  }
  paste(methods, collapse = ", ")
}

.learner_catalog <- function() {
  reg <- funcml_registry()
  ids <- names(reg)
  pkg_map <- .learner_engine_packages()

  rows <- lapply(ids, function(id) {
    adapter <- reg[[id]]
    engine_pkg <- unname(pkg_map[[id]] %||% NA_character_)
    has_tune <- TRUE
    available <- if (is.na(engine_pkg)) TRUE else requireNamespace(engine_pkg, quietly = TRUE)

    data.frame(
      learner = id,
      fit = "fit()",
      predict = "predict()",
      tune = if (has_tune) "tune()" else NA_character_,
      has_fit = TRUE,
      has_predict = TRUE,
      has_tune = has_tune,
      available = available,
      supports_regression = "regression" %in% adapter$tasks,
      supports_classification = "classification" %in% adapter$tasks,
      supports_prob = isTRUE(adapter$supports$prob),
      supports_multiclass = isTRUE(adapter$supports$multiclass),
      supports_importance = isTRUE(adapter$supports$importance),
      interpret = "interpret()",
      interpret_methods = .interpret_methods_for(adapter),
      has_interpret = TRUE,
      engine_package = engine_pkg,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$learner), , drop = FALSE]
}

#' Learner inventory table with capabilities.
#'
#' `list_learners()` returns a compact learner registry in the style of a
#' catalog table. By default it focuses on the most user-visible columns:
#' learner id, generic fit/predict/tune entry points, and availability in the
#' current session.
#'
#' Additional capability metadata remains available through `columns =`.
#'
#' @param has_fit Optional logical filter for fit support.
#' @param has_predict Optional logical filter for predict support.
#' @param has_tune Optional logical filter for tuning support.
#' @param available Optional logical filter for engine availability in the
#'   current session.
#' @param columns Optional character vector of columns to return.
#' @param regression Optional logical filter for regression support.
#' @param classification Optional logical filter for classification support.
#' @param prob Optional logical filter for probability support.
#' @param multiclass Optional logical filter for multiclass support.
#' @param importance Optional logical filter for feature-importance support.
#' @param tune Deprecated alias for `has_tune`.
#' @return Data frame with learner metadata and capability columns.
#' @examples
#' list_learners()
#' list_learners(has_tune = TRUE)
#' list_tunable_learners()
#' list_learners(classification = TRUE, prob = TRUE,
#'               columns = c("learner", "has_tune", "supports_prob", "engine_package"))
#' @export
list_learners <- function(has_fit = NULL, has_predict = NULL, has_tune = NULL,
                          available = NULL, columns = NULL,
                          regression = NULL, classification = NULL,
                          prob = NULL, multiclass = NULL, importance = NULL,
                          tune = NULL) {
  has_fit <- .validate_list_learners_flag(has_fit, "has_fit")
  has_predict <- .validate_list_learners_flag(has_predict, "has_predict")
  has_tune <- .validate_list_learners_flag(has_tune, "has_tune")
  tune <- .validate_list_learners_flag(tune, "tune")
  regression <- .validate_list_learners_flag(regression, "regression")
  classification <- .validate_list_learners_flag(classification, "classification")
  prob <- .validate_list_learners_flag(prob, "prob")
  multiclass <- .validate_list_learners_flag(multiclass, "multiclass")
  importance <- .validate_list_learners_flag(importance, "importance")
  available <- .validate_list_learners_flag(available, "available")
  if (is.null(has_tune) && !is.null(tune)) {
    has_tune <- tune
  }
  out <- .learner_catalog()

  if (!is.null(regression)) {
    out <- out[out$supports_regression == regression, , drop = FALSE]
  }
  if (!is.null(classification)) {
    out <- out[out$supports_classification == classification, , drop = FALSE]
  }
  if (!is.null(has_fit)) {
    out <- out[out$has_fit == has_fit, , drop = FALSE]
  }
  if (!is.null(has_predict)) {
    out <- out[out$has_predict == has_predict, , drop = FALSE]
  }
  if (!is.null(has_tune)) {
    out <- out[out$has_tune == has_tune, , drop = FALSE]
  }
  if (!is.null(prob)) {
    out <- out[out$supports_prob == prob, , drop = FALSE]
  }
  if (!is.null(multiclass)) {
    out <- out[out$supports_multiclass == multiclass, , drop = FALSE]
  }
  if (!is.null(importance)) {
    out <- out[out$supports_importance == importance, , drop = FALSE]
  }
  if (!is.null(available)) {
    out <- out[out$available == available, , drop = FALSE]
  }
  if (!is.null(columns)) {
    columns <- .validate_list_learners_columns(columns, names(out))
    out <- out[, columns, drop = FALSE]
  } else {
    out <- out[, c("learner", "fit", "predict", "tune", "has_fit", "has_predict", "has_tune", "available"), drop = FALSE]
  }

  out
}

#' Shortcut for learners with tuning support.
#'
#' @param ... Passed to [list_learners()].
#' @return Data frame with the same columns as [list_learners()].
#' @examples
#' list_tunable_learners()
#' @export
list_tunable_learners <- function(...) {
  list_learners(has_tune = TRUE, ...)
}

.validate_list_learners_flag <- function(x, arg) {
  if (is.null(x)) {
    return(NULL)
  }
  if (!is.logical(x) || length(x) != 1L || is.na(x)) {
    stop(sprintf("`%s` must be NULL or TRUE/FALSE.", arg), call. = FALSE)
  }
  x
}

.validate_list_learners_columns <- function(columns, allowed) {
  if (!is.character(columns) || !length(columns)) {
    stop("`columns` must be a non-empty character vector.", call. = FALSE)
  }
  unknown <- setdiff(columns, allowed)
  if (length(unknown)) {
    stop(
      sprintf(
        "Unknown `columns`: %s. Available columns: %s",
        paste(unknown, collapse = ", "),
        paste(allowed, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  columns
}

#' Methods for fitted funcml models.
#'
#' These methods provide the standard `print()`, `summary()`, `predict()`, and
#' `coef()` interfaces for `funcml_fit` objects.
#'
#' @param x A `funcml_fit` object.
#' @param object A `funcml_fit` object.
#' @param newdata Data frame of new observations.
#' @param type Prediction type override.
#' @param class_level Target class for multiclass probability predictions.
#' @param pos_level Alias for the binary positive class.
#' @param na_action NA handling for new data.
#' @param ... Additional arguments passed to the underlying method.
#' @return `print()` and `summary()` return the input object invisibly.
#'   `predict()` returns predictions in the requested format. `coef()`
#'   returns a named numeric coefficient vector when available.
#'
#' @name fit-methods
#' @aliases print.funcml_fit summary.funcml_fit predict.funcml_fit coef.funcml_fit
#' @examples
#' fit_obj <- fit(mpg ~ wt + hp, data = mtcars, model = "glm")
#' print(fit_obj)
#' summary(fit_obj)
#' predict(fit_obj, newdata = mtcars[1:3, , drop = FALSE])
#' coef(fit_obj)
#' @export
print.funcml_fit <- function(x, ...) {
  cat(sprintf("<funcml_fit> %s model: %s\n", x$task, x$model))
  cat(sprintf("Formula: %s\n", deparse(x$formula)))
  cat(sprintf("Features: %d | Obs: %d\n", length(x$features), x$n))
  invisible(x)
}

#' @rdname fit-methods
#' @export
summary.funcml_fit <- function(object, ...) {
  cat(sprintf("<funcml_fit summary> %s model: %s\n", object$task, object$model))
  cat("Spec:\n")
  print(object$spec)
  invisible(object)
}

#' @rdname fit-methods
#' @export
predict.funcml_fit <- function(object, newdata, type = NULL, class_level = NULL,
                              pos_level = NULL, na_action = object$na_action, ...) {
  object$predict(newdata = newdata, type = type, class_level = class_level,
                 pos_level = pos_level, na_action = na_action, ...)
}

#' @rdname fit-methods
#' @export
coef.funcml_fit <- function(object, ...) {
  if (is.null(object$state$state)) stop("Coefficients not available for this model.", call. = FALSE)
  if (!inherits(object$state$state, c("glm", "lm"))) stop("Coefficients not available for this model.", call. = FALSE)
  stats::coef(object$state$state)
}
