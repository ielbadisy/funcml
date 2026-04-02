`%||%` <- function(x, y) {
  if (is.null(x)) y else x
}

capture_condition_run <- function(expr) {
  warnings <- character()
  value <- withCallingHandlers(
    tryCatch(
      expr,
      error = function(e) {
        structure(list(message = conditionMessage(e)), class = "audit_error")
      }
    ),
    warning = function(w) {
      warnings <<- c(warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )

  if (inherits(value, "audit_error")) {
    return(list(status = "fail", value = NULL, warnings = unique(warnings), error = value$message))
  }

  list(status = "pass", value = value, warnings = unique(warnings), error = NA_character_)
}

safe_fit <- function(formula, data, model, spec = NULL, seed = 1L) {
  capture_condition_run(fit(formula = formula, data = data, model = model, spec = spec, seed = seed))
}

safe_predict_raw <- function(fit_obj, newdata) {
  type <- if (identical(fit_obj$task, "regression")) "response" else "class"
  res <- capture_condition_run(predict(fit_obj, newdata = newdata, type = type))
  res$type <- type
  res
}

safe_predict_prob <- function(fit_obj, newdata, class_level = NULL) {
  res <- capture_condition_run(
    predict(
      fit_obj,
      newdata = newdata,
      type = "prob",
      class_level = class_level %||% if (!is.null(fit_obj$levels)) tail(fit_obj$levels, 1) else NULL
    )
  )
  res$type <- "prob"
  res
}

safe_interpret_raw <- function(fit_obj, data) {
  type <- if (identical(fit_obj$task, "regression")) "response" else "class"
  metric <- if (identical(fit_obj$task, "regression")) "rmse" else "accuracy"
  res <- capture_condition_run(
    interpret(
      fit = fit_obj,
      data = data,
      method = "permute",
      type = type,
      metric = metric,
      nsim = 2,
      seed = 1
    )
  )
  res$type <- type
  res$metric <- metric
  res
}

safe_interpret_prob <- function(fit_obj, data, class_level = NULL) {
  res <- capture_condition_run(
    interpret(
      fit = fit_obj,
      data = data,
      method = "permute",
      type = "prob",
      metric = "logloss",
      class_level = class_level %||% if (!is.null(fit_obj$levels)) tail(fit_obj$levels, 1) else NULL,
      nsim = 2,
      seed = 1
    )
  )
  res$type <- "prob"
  res$metric <- "logloss"
  res
}

make_check <- function(status, notes = character(), value = NULL) {
  list(status = status, notes = unique(notes[nzchar(notes)]), value = value)
}

check_raw_prediction <- function(pred, task, n_expected, levels_expected = NULL) {
  notes <- character()

  if (!identical(length(pred), n_expected)) {
    notes <- c(notes, sprintf("length=%s expected=%s", length(pred), n_expected))
  }

  if (identical(task, "regression")) {
    if (!is.numeric(pred)) {
      notes <- c(notes, "regression raw output is not numeric")
    }
    if (any(!is.finite(as.numeric(pred)))) {
      notes <- c(notes, "regression raw output contains non-finite values")
    }
    return(make_check(if (length(notes)) "fail" else "pass", notes))
  }

  if (!is.factor(pred)) {
    notes <- c(notes, "classification raw output is not a factor")
  }

  pred_chr <- as.character(pred)
  if (any(is.na(pred_chr))) {
    notes <- c(notes, "classification raw output contains NA labels")
  }

  if (!is.null(levels_expected)) {
    bad <- setdiff(unique(stats::na.omit(pred_chr)), levels_expected)
    if (length(bad)) {
      notes <- c(notes, paste("raw output contains unknown labels:", paste(bad, collapse = ", ")))
    }
    if (!identical(levels(pred), levels_expected)) {
      notes <- c(notes, "raw factor levels do not match stored training levels")
    }
  }

  make_check(if (length(notes)) "fail" else "pass", notes)
}

check_prob_prediction <- function(prob, n_expected, levels_expected) {
  notes <- character()

  prob_mat <- tryCatch(as.matrix(prob), error = function(e) NULL)
  if (is.null(prob_mat)) {
    return(make_check("fail", "probability output cannot be coerced to a matrix"))
  }

  storage.mode(prob_mat) <- "double"

  if (!identical(nrow(prob_mat), n_expected)) {
    notes <- c(notes, sprintf("nrow=%s expected=%s", nrow(prob_mat), n_expected))
  }
  if (!identical(ncol(prob_mat), length(levels_expected))) {
    notes <- c(notes, sprintf("ncol=%s expected=%s", ncol(prob_mat), length(levels_expected)))
  }
  if (!all(is.finite(prob_mat))) {
    notes <- c(notes, "probability output contains non-finite values")
  }
  if (any(prob_mat < 0 | prob_mat > 1, na.rm = TRUE)) {
    notes <- c(notes, "probability output contains values outside [0, 1]")
  }

  make_check(if (length(notes)) "fail" else "pass", notes, value = prob_mat)
}

check_level_alignment <- function(raw_pred, levels_expected) {
  if (is.null(levels_expected)) {
    return(make_check("unsupported", "regression has no class levels"))
  }
  if (!is.factor(raw_pred)) {
    return(make_check("fail", "raw prediction is not a factor"))
  }
  if (!identical(levels(raw_pred), levels_expected)) {
    return(make_check("fail", "raw prediction factor levels do not match training levels"))
  }
  make_check("pass")
}

check_prob_row_sums <- function(prob_mat, tolerance = 1e-6) {
  sums <- rowSums(prob_mat)
  if (any(abs(sums - 1) > tolerance)) {
    return(make_check("fail", sprintf("row sums drift beyond tolerance %.1e", tolerance)))
  }
  make_check("pass")
}

check_prob_column_names <- function(prob_mat, levels_expected) {
  if (is.null(colnames(prob_mat))) {
    return(make_check("fail", "probability output is missing column names"))
  }
  if (!identical(colnames(prob_mat), levels_expected)) {
    return(make_check(
      "fail",
      sprintf(
        "probability column names mismatch: got [%s] expected [%s]",
        paste(colnames(prob_mat), collapse = ", "),
        paste(levels_expected, collapse = ", ")
      )
    ))
  }
  make_check("pass")
}

check_prob_class_reconstruction <- function(prob_mat, raw_pred, levels_expected) {
  if (is.null(levels_expected)) {
    return(make_check("unsupported", "regression has no probability reconstruction"))
  }
  if (!is.factor(raw_pred)) {
    return(make_check("fail", "raw prediction is not a factor"))
  }
  recon <- factor(levels_expected[max.col(prob_mat, ties.method = "first")], levels = levels_expected)
  if (!identical(as.character(recon), as.character(raw_pred))) {
    return(make_check("fail", "argmax(prob) is inconsistent with raw class predictions"))
  }
  make_check("pass")
}

summarize_condition_log <- function(...) {
  entries <- Filter(length, lapply(list(...), function(x) {
    if (is.null(x) || all(is.na(x)) || !length(x)) {
      return(character())
    }
    as.character(x)
  }))
  if (!length(entries)) {
    return(NA_character_)
  }
  paste(unique(unlist(entries, use.names = FALSE)), collapse = " | ")
}

is_clear_unsupported_error <- function(message) {
  if (is.na(message) || !nzchar(message)) {
    return(FALSE)
  }
  grepl("support|unsupported|only|requires|missing", tolower(message), perl = TRUE)
}
