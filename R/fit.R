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

#' Learner inventory table with capabilities.
#'
#' `list_learners()` returns one row per learner id with task support,
#' probability/multiclass/importance flags, and availability of the engine
#' package in the current R session. Optional filters and column selection make
#' it easier to request a compact catalog view directly.
#'
#' This mirrors a "catalog view" API style useful for quickly seeing what can
#' be fit, tuned, and interpreted in `funcml`.
#'
#' @param regression Optional logical filter for regression support.
#' @param classification Optional logical filter for classification support.
#' @param tune Optional logical filter for tuning support.
#' @param prob Optional logical filter for probability support.
#' @param multiclass Optional logical filter for multiclass support.
#' @param importance Optional logical filter for feature-importance support.
#' @param available Optional logical filter for engine availability in the
#'   current session.
#' @param columns Optional character vector of columns to return.
#' @return Data frame with learner metadata and capability columns.
#' @examples
#' list_learners()
#' list_learners(classification = TRUE, prob = TRUE, available = TRUE,
#'               columns = c("learner", "supports_prob", "engine_package"))
#' @export
list_learners <- function(regression = NULL, classification = NULL,
                          tune = NULL, prob = NULL, multiclass = NULL,
                          importance = NULL, available = NULL,
                          columns = NULL) {
  regression <- .validate_list_learners_flag(regression, "regression")
  classification <- .validate_list_learners_flag(classification, "classification")
  tune <- .validate_list_learners_flag(tune, "tune")
  prob <- .validate_list_learners_flag(prob, "prob")
  multiclass <- .validate_list_learners_flag(multiclass, "multiclass")
  importance <- .validate_list_learners_flag(importance, "importance")
  available <- .validate_list_learners_flag(available, "available")
  reg <- funcml_registry()
  ids <- names(reg)
  pkg_map <- .learner_engine_packages()

  rows <- lapply(ids, function(id) {
    adapter <- reg[[id]]
    engine_pkg <- unname(pkg_map[[id]] %||% NA_character_)
    available <- if (is.na(engine_pkg)) TRUE else requireNamespace(engine_pkg, quietly = TRUE)

    data.frame(
      learner = id,
      fit = "fit()",
      predict = "predict()",
      tune = "tune()",
      interpret = "interpret()",
      interpret_methods = .interpret_methods_for(adapter),
      has_fit = TRUE,
      has_predict = TRUE,
      has_tune = TRUE,
      has_interpret = TRUE,
      supports_regression = "regression" %in% adapter$tasks,
      supports_classification = "classification" %in% adapter$tasks,
      supports_prob = isTRUE(adapter$supports$prob),
      supports_multiclass = isTRUE(adapter$supports$multiclass),
      supports_importance = isTRUE(adapter$supports$importance),
      engine_package = engine_pkg,
      available = available,
      stringsAsFactors = FALSE
    )
  })

  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out <- out[order(out$learner), , drop = FALSE]

  if (!is.null(regression)) {
    out <- out[out$supports_regression == regression, , drop = FALSE]
  }
  if (!is.null(classification)) {
    out <- out[out$supports_classification == classification, , drop = FALSE]
  }
  if (!is.null(tune)) {
    out <- out[out$has_tune == tune, , drop = FALSE]
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
  }

  out
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
