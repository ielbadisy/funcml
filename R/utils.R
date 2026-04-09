# Basic utilities shared across funcml.

`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

assert_package <- function(pkg, model_id) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    stop(
      sprintf(
        "Model '%s' requires package '%s'. %s",
        model_id,
        pkg,
        .package_install_hint(pkg)
      ),
      call. = FALSE
    )
  }
}

.package_install_hint <- function(pkg) {
  switch(
    pkg,
    sprintf("Install it with install.packages('%s').", pkg)
  )
}

infer_task <- function(y) {
  if (is.factor(y) || is.character(y) || is.logical(y)) return("classification")
  "regression"
}

.encode_train <- function(data, formula, na_action = stats::na.fail) {
  mf <- stats::model.frame(formula, data = data, na.action = na_action)
  y <- stats::model.response(mf)
  task <- infer_task(y)

  if (task == "classification") {
    if (!is.factor(y)) y <- factor(y)
    y <- droplevels(y)
    levels_y <- levels(y)
  } else {
    levels_y <- NULL
  }

  trm <- stats::terms(mf)
  contrasts <- attr(mf, "contrasts")
  X <- stats::model.matrix(trm, mf, contrasts.arg = contrasts)
  has_intercept <- attr(trm, "intercept") == 1
  if (has_intercept && "(Intercept)" %in% colnames(X)) {
    X <- X[, colnames(X) != "(Intercept)", drop = FALSE]
  }

  list(
    y = y,
    task = task,
    levels = levels_y,
    terms = trm,
    xlevels = stats::.getXlevels(trm, mf),
    contrasts = contrasts,
    X = X,
    features = colnames(X),
    has_intercept = has_intercept
  )
}

.encode_new <- function(fit, newdata, na_action = stats::na.fail) {
  if (!is.data.frame(newdata)) {
    stop("`newdata` must be a data frame.", call. = FALSE)
  }
  terms_no_y <- stats::delete.response(fit$terms)
  vars_needed <- all.vars(terms_no_y)
  missing_vars <- setdiff(vars_needed, names(newdata))
  if (length(missing_vars)) {
    stop(
      "Prediction data is missing required columns: ",
      paste(missing_vars, collapse = ", "),
      call. = FALSE
    )
  }

  factor_vars <- intersect(names(fit$xlevels), names(newdata))
  for (var in factor_vars) {
    vals <- as.character(newdata[[var]])
    unseen <- setdiff(unique(vals[!is.na(vals)]), fit$xlevels[[var]])
    if (length(unseen)) {
      stop(
        "Unseen factor levels in `", var, "`: ",
        paste(unseen, collapse = ", "),
        call. = FALSE
      )
    }
  }

  mf_new <- tryCatch(
    stats::model.frame(terms_no_y, data = newdata, xlev = fit$xlevels, na.action = na_action),
    error = function(e) stop("Design matrix mismatch: ", e$message, call. = FALSE)
  )
  Xnew <- tryCatch(
    stats::model.matrix(terms_no_y, mf_new, contrasts.arg = fit$contrasts),
    error = function(e) stop("Design matrix mismatch: ", e$message, call. = FALSE)
  )
  if (isTRUE(fit$has_intercept) && "(Intercept)" %in% colnames(Xnew)) {
    Xnew <- Xnew[, colnames(Xnew) != "(Intercept)", drop = FALSE]
  }

  cols_new <- colnames(Xnew)
  if (!identical(cols_new, fit$features)) {
    missing <- setdiff(fit$features, cols_new)
    extra <- setdiff(cols_new, fit$features)
    msg <- "Design matrix mismatch."
    if (length(missing)) msg <- paste0(msg, " Missing columns: ", paste(missing, collapse = ", "), ".")
    if (length(extra)) msg <- paste0(msg, " Extra columns: ", paste(extra, collapse = ", "), ".")
    stop(msg, call. = FALSE)
  }
  Xnew
}

encode_training <- function(formula, data) {
  .encode_train(data = data, formula = formula)
}

encode_prediction <- function(object, newdata) {
  .encode_new(fit = object, newdata = newdata)
}

merge_spec <- function(defaults, spec, dots = list()) {
  spec <- spec %||% list()
  if (!is.list(spec)) stop("spec must be a list.", call. = FALSE)
  merged <- defaults
  for (nm in names(spec)) merged[[nm]] <- spec[[nm]]
  for (nm in names(dots)) merged[[nm]] <- dots[[nm]]
  merged
}

.normalize_prob_matrix <- function(prob, levels) {
  if (is.null(levels)) stop("Probability output requested but classification levels are missing.", call. = FALSE)
  if (is.null(dim(prob))) {
    prob <- as.numeric(prob)
    if (length(levels) != 2) stop("Vector probabilities only supported for binary classification.", call. = FALSE)
    prob <- cbind(1 - prob, prob)
  }
  prob <- as.matrix(prob)
  if (ncol(prob) != length(levels) && is.null(colnames(prob))) {
    stop("Probability matrix column count does not match the number of class levels.", call. = FALSE)
  }
  if (!is.null(colnames(prob))) {
    missing <- setdiff(levels, colnames(prob))
    if (length(missing)) stop("Probability matrix missing levels: ", paste(missing, collapse = ", "), call. = FALSE)
    prob <- prob[, levels, drop = FALSE]
  } else {
    colnames(prob) <- levels
  }
  if (any(!is.finite(prob))) {
    stop("Probability output contains non-finite values.", call. = FALSE)
  }
  if (any(prob < 0)) {
    stop("Probability output contains negative values.", call. = FALSE)
  }
  row_sums <- rowSums(prob)
  if (any(row_sums <= 0)) {
    stop("Probability output must have positive row sums.", call. = FALSE)
  }
  if (any(abs(row_sums - 1) > 1e-8)) {
    prob <- prob / row_sums
  }
  prob
}

.predict_prob_or_response <- function(fit, adapter, state, Xnew, type = NULL, class_level = NULL, pos_level = NULL, ...) {
  task <- fit$task
  levels <- fit$levels
  default_type <- if (task == "regression") "response" else "class"
  type <- type %||% default_type
  if (identical(type, "raw")) {
    type <- if (task == "regression") "response" else "class"
  }

  if (task == "regression" && type != "response") {
    stop("Regression models support only type='response'.", call. = FALSE)
  }

  if (task == "classification") {
    if (!type %in% c("class", "prob", "response")) stop("Classification type must be 'class', 'prob', or 'response'.", call. = FALSE)
    if (is.null(levels)) stop("Classification predictions require stored factor levels.", call. = FALSE)
    if (type == "prob" && !isTRUE(adapter$supports$prob)) {
      stop(sprintf("Model '%s' does not support type='prob'.", fit$model), call. = FALSE)
    }
  }

  adapter_type <- if (task == "classification" && type %in% c("class", "response")) "class" else type
  raw <- adapter$predict_xy(state, Xnew, type = adapter_type, levels = levels, spec = fit$spec, task = task, ...)

  if (task == "regression") {
    return(as.numeric(raw))
  }

  # classification handling
  class_level <- class_level %||% pos_level %||% levels[length(levels)]
  if (type == "prob") {
    prob <- .normalize_prob_matrix(raw, levels)
    return(prob)
  }

  # class / response
  if (is.matrix(raw)) {
    prob <- .normalize_prob_matrix(raw, levels)
    cls <- levels[max.col(prob, ties.method = "first")]
    return(factor(cls, levels = levels))
  }

  factor(as.character(raw), levels = levels)
}
