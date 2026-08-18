# ROC curve and AUC confidence intervals, backed by the pROC package.
#
# funcml's own `auc()` (metrics.R) stays a fast Mann-Whitney implementation
# used inside resampling loops. These functions are for one-off, user-facing
# analysis of a single fitted model's predictions: the full ROC curve and a
# DeLong/bootstrap confidence interval on AUC, which funcml does not
# implement itself.

#' ROC curve.
#'
#' Computes the receiver operating characteristic curve for binary
#' classification predictions, using [pROC::roc()] as the backend.
#'
#' @param truth Factor (or coercible to factor) of true class labels.
#' @param prob Predicted probability of the positive class, or a probability
#'   matrix/data frame with one column per class level.
#' @param positive Optional positive class level. Defaults to the second
#'   factor level.
#' @return A `funcml_roc` object: a list with a `curve` data frame
#'   (`threshold`, `sensitivity`, `specificity`), the AUC, and the
#'   underlying `pROC::roc` object (`proc`).
#' @examples
#' if (requireNamespace("pROC", quietly = TRUE)) {
#'   set.seed(1)
#'   truth <- factor(rbinom(100, 1, 0.4))
#'   prob <- runif(100)
#'   roc_obj <- roc_curve(truth, prob)
#'   roc_obj$curve
#' }
#' @export
roc_curve <- function(truth, prob, positive = NULL) {
  assert_package("pROC", "roc_curve")
  parsed <- .binary_truth_prob(truth, prob, positive = positive)
  roc_obj <- pROC::roc(
    response = parsed$truth, predictor = parsed$prob,
    quiet = TRUE, direction = "<"
  )
  curve <- data.frame(
    threshold = roc_obj$thresholds,
    sensitivity = roc_obj$sensitivities,
    specificity = roc_obj$specificities,
    stringsAsFactors = FALSE
  )
  curve <- curve[order(curve$threshold), , drop = FALSE]
  rownames(curve) <- NULL
  out <- list(curve = curve, auc = as.numeric(pROC::auc(roc_obj)), proc = roc_obj)
  class(out) <- "funcml_roc"
  out
}

#' AUC with a confidence interval.
#'
#' Computes AUC together with a confidence interval, using [pROC::ci.auc()]
#' as the backend (DeLong by default, or bootstrap).
#'
#' @param truth Factor (or coercible to factor) of true class labels.
#' @param prob Predicted probability of the positive class, or a probability
#'   matrix/data frame with one column per class level.
#' @param positive Optional positive class level. Defaults to the second
#'   factor level.
#' @param conf_level Confidence level.
#' @param method `"delong"` (default, analytic) or `"bootstrap"`.
#' @param boot_n Number of bootstrap replicates when `method = "bootstrap"`.
#' @param digits Number of digits numeric columns are rounded to.
#' @return A one-row data frame with `auc`, `conf_low`, `conf_high`,
#'   `conf_level`, and `method`.
#' @examples
#' if (requireNamespace("pROC", quietly = TRUE)) {
#'   set.seed(1)
#'   truth <- factor(rbinom(100, 1, 0.4))
#'   prob <- runif(100)
#'   auc_ci(truth, prob)
#' }
#' @export
auc_ci <- function(truth, prob, positive = NULL, conf_level = 0.95,
                   method = c("delong", "bootstrap"), boot_n = 2000L, digits = 4L) {
  assert_package("pROC", "auc_ci")
  method <- match.arg(method)
  parsed <- .binary_truth_prob(truth, prob, positive = positive)
  roc_obj <- pROC::roc(
    response = parsed$truth, predictor = parsed$prob,
    quiet = TRUE, direction = "<"
  )
  ci_obj <- pROC::ci.auc(
    roc_obj, conf.level = conf_level, method = method, boot.n = boot_n
  )
  .round_numeric_df(data.frame(
    auc = as.numeric(pROC::auc(roc_obj)),
    conf_low = as.numeric(ci_obj[1]),
    conf_high = as.numeric(ci_obj[3]),
    conf_level = conf_level,
    method = method,
    stringsAsFactors = FALSE
  ), digits = digits)
}

#' Methods for ROC curve results.
#'
#' @param x A `funcml_roc` object.
#' @param digits Number of digits numeric columns are rounded to when printed.
#' @param ... Additional arguments (unused).
#' @return `print()` returns the input object invisibly. `plot()` returns a
#'   `ggplot2` object.
#' @name roc-methods
#' @aliases print.funcml_roc plot.funcml_roc
#' @export
print.funcml_roc <- function(x, digits = 4L, ...) {
  cat(sprintf("<funcml_roc> AUC: %.4f\n", x$auc))
  print(.round_numeric_df(utils::head(x$curve, 10), digits = digits))
  invisible(x)
}

#' @rdname roc-methods
#' @export
plot.funcml_roc <- function(x, ...) {
  df <- x$curve
  ggplot2::ggplot(df, ggplot2::aes(x = 1 - specificity, y = sensitivity)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey70", linetype = "dashed") +
    ggplot2::geom_line(colour = .funcml_palette$accent, linewidth = 0.8) +
    ggplot2::labs(
      x = "1 - Specificity",
      y = "Sensitivity",
      title = sprintf("ROC curve (AUC = %.3f)", x$auc)
    ) +
    theme_funcml()
}
