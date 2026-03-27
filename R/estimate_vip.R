#' Effect-targeted permutation importance for causal estimands.
#'
#' @param object A `funcml_estimand` object returned by [estimate()].
#' @param data Optional training/reference data used to fit the outcome model.
#'   Defaults to the data stored on `object`.
#' @param newdata Optional target data for `object$estimand = "CATE"` or
#'   `"IATE"`. Defaults to the target data stored on `object`.
#' @param variables Optional subset of covariates to perturb.
#' @param perturb Perturbation scheme. Currently only `"permute"` is supported.
#' @param mode One of `"evaluate"` or `"refit"`.
#' @param measure Discrepancy measure: `"absolute"` or `"squared"`.
#' @param relative Should importance be scaled by the baseline effect magnitude?
#' @param nsim Number of perturbation repetitions.
#' @param keep Keep the per-repetition raw scores.
#' @param seed Optional seed.
#' @param ... Additional arguments passed to [fit()] when `mode = "refit"`.
#' @return A `funcml_estimand_vip` object.
#' @export
estimate_vip <- function(object, data = NULL, newdata = NULL, variables = NULL,
                         perturb = c("permute"),
                         mode = c("evaluate", "refit"),
                         measure = c("absolute", "squared"),
                         relative = FALSE,
                         nsim = 30,
                         keep = TRUE,
                         seed = NULL,
                         ...) {
  if (!inherits(object, "funcml_estimand")) {
    stop("`object` must be a funcml_estimand returned by `estimate()`.", call. = FALSE)
  }
  perturb <- match.arg(perturb)
  mode <- match.arg(mode)
  measure <- match.arg(measure)
  if (!is.numeric(nsim) || length(nsim) != 1L || is.na(nsim) || nsim < 1) {
    stop("`nsim` must be a single integer greater than or equal to 1.", call. = FALSE)
  }
  nsim <- as.integer(nsim)
  if (!is.null(seed)) {
    set.seed(seed)
  }

  fit_obj <- object$fit
  if (!inherits(fit_obj, "funcml_fit")) {
    stop("`object` must contain a valid funcml fit.", call. = FALSE)
  }

  data <- .estimate_vip_reference_data(object, data)
  target_data <- .estimate_vip_target_data(object, data, newdata)
  variables <- .estimate_vip_variables(
    variables = variables,
    formula = fit_obj$formula,
    data = data,
    treatment = object$treatment
  )
  pred_type <- object$prediction_type %||% .estimand_prediction_type(fit_obj, type = NULL)

  baseline_core <- .estimate_vip_effects(
    fit_obj = fit_obj,
    object = object,
    data = data,
    target_data = target_data,
    pred_type = pred_type
  )

  raw_scores <- matrix(
    NA_real_,
    nrow = nsim,
    ncol = length(variables),
    dimnames = list(NULL, variables)
  )
  target_is_training <- .estimate_vip_target_is_training(object, newdata)

  for (sim in seq_len(nsim)) {
    for (j in seq_along(variables)) {
      variable <- variables[j]
      pert_data <- .estimate_vip_perturb(data, variable, perturb = perturb)
      pert_target <- if (target_is_training) {
        pert_data
      } else {
        .estimate_vip_perturb(target_data, variable, perturb = perturb)
      }

      if (mode == "evaluate") {
        pert_core <- .estimate_vip_effects(
          fit_obj = fit_obj,
          object = object,
          data = pert_data,
          target_data = pert_target,
          pred_type = pred_type
        )
      } else {
        refit_obj <- .estimate_vip_refit(fit_obj, pert_data, ...)
        pert_core <- .estimate_vip_effects(
          fit_obj = refit_obj,
          object = object,
          data = pert_data,
          target_data = pert_target,
          pred_type = pred_type
        )
      }

      raw_scores[sim, j] <- .estimate_vip_distance(
        baseline = baseline_core,
        perturbed = pert_core,
        estimand = object$estimand,
        measure = measure,
        relative = relative
      )
    }
  }

  scores <- data.frame(
    variable = variables,
    importance = colMeans(raw_scores),
    std_dev = if (nsim > 1) apply(raw_scores, 2, stats::sd) else NA_real_,
    stringsAsFactors = FALSE
  )
  scores$rank <- rank(-scores$importance, ties.method = "min")
  scores <- scores[order(scores$importance, decreasing = TRUE), , drop = FALSE]
  rownames(scores) <- NULL

  out <- list(
    call = match.call(),
    estimand = object$estimand,
    estimand_label = object$estimand_label %||% .estimand_label(object$estimand),
    estimand_role = object$estimand_role %||% .estimand_role(object$estimand),
    treatment = object$treatment,
    treatment_level = object$treatment_level,
    control_level = object$control_level,
    mode = mode,
    perturb = perturb,
    measure = measure,
    relative = isTRUE(relative),
    nsim = nsim,
    baseline = if (object$estimand == "IATE") baseline_core$effects$effect else baseline_core$estimate,
    result = list(
      scores = scores,
      raw_scores = if (isTRUE(keep) && nsim > 1) raw_scores else NULL
    )
  )
  class(out) <- "funcml_estimand_vip"
  out
}

.estimate_vip_reference_data <- function(object, data) {
  if (!is.null(data)) {
    return(data)
  }
  if (!is.null(object$data)) {
    return(object$data)
  }
  stop("`data` is required when the estimand object does not store reference data.", call. = FALSE)
}

.estimate_vip_target_data <- function(object, data, newdata) {
  if (!is.null(newdata)) {
    target_data <- newdata
  } else if (!is.null(object$target_data)) {
    target_data <- object$target_data
  } else {
  target_data <- switch(
    object$estimand,
    ATE = data,
    ATT = data,
    CATE = {
      if (is.null(newdata)) {
        stop("`newdata` is required for `object$estimand = \"CATE\"`.", call. = FALSE)
      }
      newdata
    },
    IATE = newdata %||% data
  )
  }
  if (!object$treatment %in% names(target_data)) {
    stop("Treatment variable not found in target data.", call. = FALSE)
  }
  target_data
}

.estimate_vip_target_is_training <- function(object, newdata) {
  object$estimand %in% c("ATE", "ATT") || (object$estimand == "IATE" && is.null(newdata))
}

.estimate_vip_variables <- function(variables, formula, data, treatment) {
  mf <- stats::model.frame(stats::delete.response(stats::terms(formula)), data)
  available <- setdiff(names(mf), treatment)
  if (is.null(variables)) {
    return(available)
  }
  variables <- unique(as.character(variables))
  missing_vars <- setdiff(variables, available)
  if (length(missing_vars)) {
    stop(
      sprintf(
        "Unknown covariates requested in `variables`: %s.",
        paste(missing_vars, collapse = ", ")
      ),
      call. = FALSE
    )
  }
  variables
}

.estimate_vip_perturb <- function(data, variable, perturb = "permute") {
  if (perturb != "permute") {
    stop("Only `perturb = \"permute\"` is currently supported.", call. = FALSE)
  }
  out <- data
  out[[variable]] <- sample(out[[variable]])
  out
}

.estimate_vip_refit <- function(fit_obj, data, ...) {
  extra_args <- list(...)
  do.call(
    fit,
    c(
      list(
        formula = fit_obj$formula,
        data = data,
        model = fit_obj$model,
        spec = fit_obj$spec,
        na_action = fit_obj$na_action
      ),
      extra_args
    )
  )
}

.estimate_vip_effects <- function(fit_obj, object, data, target_data, pred_type) {
  trt_bin <- .coerce_binary_treatment(
    data[[object$treatment]],
    treatment_level = object$treatment_level,
    control_level = object$control_level
  )
  .estimate_effects(
    base_fit = fit_obj,
    data = data,
    formula = fit_obj$formula,
    treatment = object$treatment,
    estimand = object$estimand,
    target_data = target_data,
    trt_bin = trt_bin,
    pred_type = pred_type
  )
}

.estimate_vip_distance <- function(baseline, perturbed, estimand, measure, relative) {
  if (estimand == "IATE") {
    delta <- baseline$effects$effect - perturbed$effects$effect
    score <- if (measure == "absolute") mean(abs(delta)) else mean(delta^2)
    if (!isTRUE(relative)) {
      return(score)
    }
    denom <- if (measure == "absolute") {
      mean(abs(baseline$effects$effect))
    } else {
      mean(baseline$effects$effect^2)
    }
    return(score / (denom + sqrt(.Machine$double.eps)))
  }

  delta <- baseline$estimate - perturbed$estimate
  score <- if (measure == "absolute") abs(delta) else delta^2
  if (!isTRUE(relative)) {
    return(score)
  }
  denom <- if (measure == "absolute") abs(baseline$estimate) else baseline$estimate^2
  score / (denom + sqrt(.Machine$double.eps))
}

.estimate_vip_axis_label <- function(x) {
  prefix <- if (isTRUE(x$relative)) "Relative effect-targeted importance" else "Effect-targeted importance"
  suffix <- switch(
    x$estimand,
    ATE = "for estimated ATE",
    ATT = "for estimated ATT",
    CATE = "for target-average CATE",
    IATE = "for estimated individualized effects"
  )
  sprintf("%s (%s)", prefix, suffix)
}

#' @export
print.funcml_estimand_vip <- function(x, ...) {
  cat(sprintf("<funcml_estimand_vip> %s | mode: %s | perturb: %s\n", x$estimand, x$mode, x$perturb))
  cat(sprintf("Target: %s\n", x$estimand_label %||% .estimand_label(x$estimand)))
  print(utils::head(x$result$scores, 10))
  invisible(x)
}

#' @export
summary.funcml_estimand_vip <- function(object, ...) {
  print(object$result$scores)
  invisible(object$result$scores)
}

#' @export
plot.funcml_estimand_vip <- function(x, ...) {
  df <- x$result$scores
  df <- df[order(df$importance, decreasing = TRUE), , drop = FALSE]
  df$variable <- factor(df$variable, levels = rev(df$variable))
  raw_scores <- x$result$raw_scores

  if (!is.null(raw_scores)) {
    raw_df <- data.frame(
      variable = rep(colnames(raw_scores), each = nrow(raw_scores)),
      raw_score = as.numeric(raw_scores),
      stringsAsFactors = FALSE
    )
    raw_df$variable <- factor(raw_df$variable, levels = levels(df$variable))
    return(
      ggplot2::ggplot(raw_df, ggplot2::aes(x = raw_score, y = variable)) +
        ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
        ggplot2::geom_boxplot(
          width = 0.65,
          outlier.alpha = 0.25,
          fill = "white",
          colour = "grey25"
        ) +
        ggplot2::geom_point(
          data = df,
          ggplot2::aes(x = importance, y = variable),
          inherit.aes = FALSE,
          size = 2.1,
          colour = "black"
        ) +
        ggplot2::labs(
          x = .estimate_vip_axis_label(x),
          y = NULL,
          title = sprintf("%s variable importance", x$estimand_label %||% x$estimand)
        ) +
        .publication_theme()
    )
  }

  ggplot2::ggplot(df, ggplot2::aes(x = importance, y = variable)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
    ggplot2::geom_point(size = 2.3, colour = "black") +
  ggplot2::labs(
      x = .estimate_vip_axis_label(x),
      y = NULL,
      title = sprintf("%s variable importance", x$estimand_label %||% x$estimand)
    ) +
    .publication_theme()
}
