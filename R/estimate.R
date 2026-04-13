#' Causal effect estimation via plug-in g-computation.
#'
#' @param data Data frame.
#' @param formula Outcome model formula. The first term on the right-hand side
#'   is treated as the treatment variable unless `treatment` is supplied.
#' @param model Learner id (ignored if `fit` supplied).
#' @param treatment Optional treatment variable name.
#' @param estimand One of `"ATE"`, `"ATT"`, `"CATE"`, or `"IATE"`.
#' @param newdata Optional target population for `estimand = "CATE"` or
#'   `"IATE"`.
#' @param treatment_level Optional treated level for binary treatment.
#' @param control_level Optional control level for binary treatment.
#' @param spec Hyperparameter list passed to `fit()`.
#' @param type Prediction type override for the outcome model.
#' @param interval Interval method: `"normal"` or `"bootstrap"`.
#' @param conf_level Confidence level for uncertainty intervals.
#' @param n_boot Number of bootstrap resamples used when `interval = "bootstrap"`.
#' @param seed Optional seed.
#' @param fit Optional preconfigured `funcml_fit` object.
#' @param ... Passed to `fit()`.
#' @return A `funcml_estimand` object.
#' @examples
#' causal_data <- mtcars
#' causal_data$am <- factor(causal_data$am, labels = c("auto", "manual"))
#' ate <- estimate(
#'   data = causal_data,
#'   formula = mpg ~ am + wt + hp,
#'   model = "glm",
#'   treatment = "am",
#'   estimand = "ATE"
#' )
#' ate$estimate
#' @export
estimate <- function(data, formula, model = NULL, treatment = NULL,
                     estimand = c("ATE", "ATT", "CATE", "IATE"),
                     newdata = NULL,
                     treatment_level = NULL, control_level = NULL,
                     spec = NULL, type = NULL,
                     interval = c("normal", "bootstrap"),
                     conf_level = 0.95, n_boot = 200,
                     seed = NULL, fit = NULL, ...) {
  if (!is.null(seed)) set.seed(seed)
  estimand <- match.arg(estimand)
  interval <- match.arg(interval)

  if (!is.null(fit)) {
    formula <- formula %||% fit$formula
    base_fit <- fit
  } else {
    if (is.null(model)) stop("Provide either `model` or `fit`.", call. = FALSE)
    base_fit <- fit(formula, data, model, spec = spec, seed = seed, ...)
  }

  outcome <- all.vars(formula)[1L]
  rhs_terms <- attr(stats::terms(formula), "term.labels")
  if (length(rhs_terms) == 0L) {
    stop("The formula must include a treatment variable on the right-hand side.", call. = FALSE)
  }
  treatment <- treatment %||% rhs_terms[1L]
  if (!treatment %in% names(data)) {
    stop("Treatment variable not found in `data`.", call. = FALSE)
  }
  trt_raw <- data[[treatment]]
  trt_bin <- .coerce_binary_treatment(trt_raw, treatment_level = treatment_level, control_level = control_level)

  pred_type <- .estimand_prediction_type(base_fit, type = type)
  target_data <- if (estimand == "CATE") {
    if (is.null(newdata)) stop("`newdata` is required for `estimand = \"CATE\"`.", call. = FALSE)
    newdata
  } else if (estimand == "IATE") {
    newdata %||% data
  } else {
    data
  }
  if (!treatment %in% names(target_data)) {
    stop("Treatment variable not found in target data.", call. = FALSE)
  }

  est_core <- .estimate_effects(
    base_fit = base_fit,
    data = data,
    formula = formula,
    treatment = treatment,
    estimand = estimand,
    target_data = target_data,
    trt_bin = trt_bin,
    pred_type = pred_type
  )
  alpha <- 1 - conf_level
  ci <- .estimate_interval(
    estimate_value = est_core$estimate,
    se_value = est_core$std_error,
    interval = interval,
    conf_level = conf_level,
    alpha = alpha,
    estimand = estimand,
    base_fit = base_fit,
    data = data,
    formula = formula,
    treatment = treatment,
    target_data = target_data,
    trt_bin = trt_bin,
    pred_type = pred_type,
    spec = spec,
    fit_obj = fit,
    n_boot = n_boot
  )

  out <- list(
    estimate = est_core$estimate,
    std_error = est_core$std_error,
    conf_int = stats::setNames(ci, c("lower", "upper")),
    conf_level = conf_level,
    interval_method = interval,
    estimand = estimand,
    treatment = treatment,
    treatment_level = trt_bin$treated,
    control_level = trt_bin$control,
    outcome = outcome,
    task = base_fit$task,
    call = match.call(),
    fit = base_fit,
    effects = est_core$effects,
    assumptions = c(
      "Binary treatment with no hidden confounding",
      "Consistency and positivity",
      "Outcome model correctly specified for g-computation"
    )
  )
  class(out) <- "funcml_estimand"
  out
}

.coerce_binary_treatment <- function(x, treatment_level = NULL, control_level = NULL) {
  if (is.logical(x)) {
    lev <- c(FALSE, TRUE)
    vals <- as.logical(x)
  } else if (is.factor(x) || is.character(x)) {
    vals <- as.character(x)
    lev <- unique(vals)
  } else if (is.numeric(x)) {
    vals <- x
    lev <- sort(unique(vals))
  } else {
    stop("Treatment must be logical, factor, character, or numeric.", call. = FALSE)
  }
  lev <- lev[!is.na(lev)]
  if (length(lev) != 2L) {
    stop("Treatment must be binary.", call. = FALSE)
  }
  control <- control_level %||% lev[1L]
  treated <- treatment_level %||% lev[2L]
  if (!(treated %in% lev) || !(control %in% lev) || identical(treated, control)) {
    stop("`treatment_level` and `control_level` must be the two binary treatment values.", call. = FALSE)
  }
  list(values = vals, treated = treated, control = control)
}

.binary_level_value <- function(template, value) {
  if (is.logical(template)) {
    rep(as.logical(value), length(template))
  } else if (is.factor(template)) {
    factor(rep(as.character(value), length(template)), levels = levels(template), ordered = is.ordered(template))
  } else if (is.character(template)) {
    rep(as.character(value), length(template))
  } else {
    rep(as.numeric(value), length(template))
  }
}

.estimand_prediction_type <- function(fit, type = NULL) {
  if (!is.null(type)) return(type)
  if (fit$task == "regression") "response" else "prob"
}

.estimand_predict <- function(fit, newdata, type) {
  if (fit$task == "regression") {
    return(as.numeric(predict(fit, newdata = newdata, type = "response")))
  }
  prob <- .normalize_prob_matrix(
    predict(fit, newdata = newdata, type = "prob"),
    fit$levels
  )
  prob[, fit$levels[length(fit$levels)]]
}

.estimate_effects <- function(base_fit, data, formula, treatment, estimand, target_data, trt_bin, pred_type) {
  cf_treated <- target_data
  cf_control <- target_data
  cf_treated[[treatment]] <- .binary_level_value(target_data[[treatment]], trt_bin$treated)
  cf_control[[treatment]] <- .binary_level_value(target_data[[treatment]], trt_bin$control)

  mu1 <- .estimand_predict(base_fit, cf_treated, type = pred_type)
  mu0 <- .estimand_predict(base_fit, cf_control, type = pred_type)
  ite <- mu1 - mu0

  weights <- switch(
    estimand,
    ATE = rep(1, length(ite)),
    ATT = {
      idx <- as.integer(trt_bin$values == trt_bin$treated)
      if (!any(idx == 1L)) stop("ATT is undefined: no treated observations found.", call. = FALSE)
      idx
    },
    CATE = rep(1, length(ite)),
    IATE = rep(1, length(ite))
  )

  list(
    estimate = if (estimand == "IATE") NA_real_ else stats::weighted.mean(ite, w = weights),
    std_error = if (estimand == "IATE") NA_real_ else .weighted_se(ite, weights),
    effects = data.frame(
      row_id = seq_along(ite),
      effect = ite,
      mu1 = mu1,
      mu0 = mu0,
      weight = weights,
      stringsAsFactors = FALSE
    )
  )
}

.estimate_interval <- function(estimate_value, se_value, interval, conf_level, alpha, estimand,
                               base_fit, data, formula, treatment, target_data, trt_bin,
                               pred_type, spec, fit_obj, n_boot) {
  if (estimand == "IATE") {
    return(stats::setNames(c(NA_real_, NA_real_), c("lower", "upper")))
  }

  if (interval == "normal") {
    crit <- stats::qnorm(1 - alpha / 2)
    return(stats::setNames(estimate_value + c(-1, 1) * crit * se_value, c("lower", "upper")))
  }

  boot_vals <- .bootstrap_estimand(
    data = data,
    formula = formula,
    treatment = treatment,
    estimand = estimand,
    target_data = target_data,
    trt_bin = trt_bin,
    pred_type = pred_type,
    base_fit = base_fit,
    spec = spec,
    fit_obj = fit_obj,
    n_boot = n_boot
  )
  stats::setNames(
    as.numeric(stats::quantile(boot_vals, probs = c(alpha / 2, 1 - alpha / 2), na.rm = TRUE, names = FALSE)),
    c("lower", "upper")
  )
}

.bootstrap_estimand <- function(data, formula, treatment, estimand, target_data, trt_bin,
                                pred_type, base_fit, spec, fit_obj, n_boot) {
  if (!is.numeric(n_boot) || length(n_boot) != 1L || n_boot < 20) {
    stop("`n_boot` must be a single integer greater than or equal to 20.", call. = FALSE)
  }
  n <- nrow(data)
  vals <- numeric(n_boot)
  for (b in seq_len(n_boot)) {
    idx <- sample.int(n, size = n, replace = TRUE)
    boot_data <- data[idx, , drop = FALSE]
    boot_fit <- if (!is.null(fit_obj)) {
      fit(formula %||% fit_obj$formula, boot_data, fit_obj$model, spec = fit_obj$spec)
    } else {
      fit(formula, boot_data, base_fit$model, spec = spec %||% base_fit$spec)
    }
    boot_trt <- .coerce_binary_treatment(
      boot_data[[treatment]],
      treatment_level = trt_bin$treated,
      control_level = trt_bin$control
    )
    boot_core <- .estimate_effects(
      base_fit = boot_fit,
      data = boot_data,
      formula = formula,
      treatment = treatment,
      estimand = estimand,
      target_data = target_data,
      trt_bin = boot_trt,
      pred_type = pred_type
    )
    vals[b] <- boot_core$estimate
  }
  vals
}

.weighted_se <- function(x, w) {
  w <- as.numeric(w)
  w <- w / sum(w)
  mu <- sum(w * x)
  n_eff <- 1 / sum(w^2)
  if (!is.finite(n_eff) || n_eff <= 1) return(NA_real_)
  sqrt(sum(w * (x - mu)^2) / (n_eff - 1))
}

#' Methods for causal estimand results.
#'
#' These methods provide the standard `print()`, `summary()`, and `plot()`
#' interfaces for `funcml_estimand` objects.
#'
#' @param x A `funcml_estimand` object.
#' @param object A `funcml_estimand` object.
#' @param ... Additional arguments passed to the underlying method.
#'
#' @name estimate-methods
#' @aliases print.funcml_estimand summary.funcml_estimand plot.funcml_estimand
#' @examples
#' causal_data <- mtcars
#' causal_data$am <- factor(causal_data$am, labels = c("auto", "manual"))
#' ate <- estimate(
#'   data = causal_data,
#'   formula = mpg ~ am + wt + hp,
#'   model = "glm",
#'   treatment = "am",
#'   estimand = "ATE"
#' )
#' print(ate)
#' summary(ate)
#' plot(ate)
#' @export
print.funcml_estimand <- function(x, ...) {
  cat(sprintf("<funcml_estimand> %s via g-computation\n", x$estimand))
  cat(sprintf("Treatment: %s (%s vs %s)\n", x$treatment, x$treatment_level, x$control_level))
  if (x$estimand == "IATE") {
    cat(sprintf("Rows scored: %d | mean individualized effect: %.4f\n",
                nrow(x$effects), mean(x$effects$effect)))
  } else {
    cat(sprintf(
      "Estimate: %.4f | SE: %.4f | %.0f%% %s CI [%.4f, %.4f]\n",
      x$estimate, x$std_error, 100 * x$conf_level, x$interval_method,
      x$conf_int[1], x$conf_int[2]
    ))
  }
  invisible(x)
}

#' @rdname estimate-methods
#' @export
summary.funcml_estimand <- function(object, ...) {
  if (object$estimand == "IATE") {
    print(utils::head(object$effects, 10))
    return(invisible(object$effects))
  }
  out <- data.frame(
    estimand = object$estimand,
    treatment = object$treatment,
    treatment_level = object$treatment_level,
    control_level = object$control_level,
    estimate = object$estimate,
    std_error = object$std_error,
    interval_method = object$interval_method,
    conf_level = object$conf_level,
    conf_low = object$conf_int[1],
    conf_high = object$conf_int[2],
    stringsAsFactors = FALSE
  )
  print(out)
  invisible(out)
}

#' @rdname estimate-methods
#' @export
plot.funcml_estimand <- function(x, ...) {
  df <- x$effects
  center_line <- if (x$estimand == "IATE") mean(df$effect) else x$estimate
  estimate_label <- if (x$estimand == "IATE") "Mean individualized effect" else "Estimated average effect"
  ggplot2::ggplot(df, ggplot2::aes(x = effect)) +
    ggplot2::geom_histogram(
      bins = 24,
      fill = "white",
      colour = "grey35",
      linewidth = 0.4
    ) +
    ggplot2::geom_vline(
      xintercept = 0,
      colour = "grey55",
      linewidth = 0.5,
      linetype = "dashed"
    ) +
    ggplot2::geom_vline(
      xintercept = center_line,
      colour = .funcml_palette$accent,
      linewidth = 0.9
    ) +
    ggplot2::labs(
      x = "Estimated unit-level effect",
      y = "Count",
      title = sprintf("%s estimate", x$estimand),
      subtitle = sprintf(
        "%s: %s vs %s | %s = %.3f",
        x$treatment, x$treatment_level, x$control_level,
        estimate_label,
        center_line
      )
    ) +
    .publication_theme()
}
