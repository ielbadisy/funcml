# Decision curve analysis (Vickers & Elkin, 2006).
#
# Net benefit at threshold t: NB = (TP/n) - (FP/n) * (t / (1 - t)).
# "Treat all" uses the outcome prevalence in place of TP/FP; "treat none"
# is 0 by definition.

#' Decision curve analysis: net benefit.
#'
#' Computes net benefit across a range of risk thresholds for a binary
#' classifier's predicted probabilities, alongside the "treat all" and
#' "treat none" reference strategies (Vickers and Elkin, 2006).
#'
#' @param truth Factor (or coercible to factor) of true class labels.
#' @param prob Predicted probability of the positive class, or a probability
#'   matrix/data frame with one column per class level.
#' @param positive Optional positive class level. Defaults to the second
#'   factor level.
#' @param thresholds Numeric vector of risk thresholds in (0, 1).
#' @return A data frame with `threshold`, `model`, `treat_all`, and
#'   `treat_none` net benefit columns.
#' @examples
#' set.seed(1)
#' truth <- factor(rbinom(200, 1, 0.3))
#' prob <- pmin(pmax(rnorm(200, mean = ifelse(truth == 1, 0.6, 0.3), sd = 0.15), 0), 1)
#' dca(truth, prob)
#' @export
dca <- function(truth, prob, positive = NULL, thresholds = seq(0.01, 0.99, by = 0.01)) {
  if (any(thresholds <= 0) || any(thresholds >= 1)) {
    stop("`thresholds` must lie strictly between 0 and 1.", call. = FALSE)
  }
  parsed <- .binary_truth_prob(truth, prob, positive = positive)
  y <- parsed$truth
  p <- parsed$prob
  n <- length(y)
  prevalence <- mean(y)
  odds <- thresholds / (1 - thresholds)

  net_benefit_model <- vapply(thresholds, function(t) {
    pred_pos <- p >= t
    tp <- sum(pred_pos & y == 1L)
    fp <- sum(pred_pos & y == 0L)
    (tp / n) - (fp / n) * (t / (1 - t))
  }, numeric(1))
  net_benefit_all <- prevalence - (1 - prevalence) * odds

  data.frame(
    threshold = thresholds,
    model = net_benefit_model,
    treat_all = net_benefit_all,
    treat_none = 0,
    stringsAsFactors = FALSE
  )
}

#' Methods for decision curve analysis results.
#'
#' These provide the standard `print()` and `plot()` interfaces for
#' `funcml_dca` objects returned by `interpret(method = "dca")`.
#'
#' @param x A `funcml_dca` object.
#' @param ... Additional arguments (unused).
#' @return `print()` returns the input object invisibly. `plot()` returns a
#'   `ggplot2` object.
#' @name dca-methods
#' @aliases print.funcml_dca plot.funcml_dca
#' @export
print.funcml_dca <- function(x, ...) {
  cat(sprintf("<funcml_dca> positive: %s\n", x$result$positive %||% "NA"))
  print(utils::head(x$result$curve, 10))
  invisible(x)
}

#' @rdname dca-methods
#' @export
plot.funcml_dca <- function(x, ...) {
  curve <- x$result$curve
  long <- data.frame(
    threshold = rep(curve$threshold, 3L),
    net_benefit = c(curve$model, curve$treat_all, curve$treat_none),
    strategy = factor(
      rep(c("Model", "Treat all", "Treat none"), each = nrow(curve)),
      levels = c("Model", "Treat all", "Treat none")
    ),
    stringsAsFactors = FALSE
  )
  y_floor <- max(min(curve$model, curve$treat_all, curve$treat_none, na.rm = TRUE), -0.1)
  ggplot2::ggplot(long, ggplot2::aes(x = threshold, y = net_benefit, colour = strategy)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
    ggplot2::geom_line(linewidth = 0.8) +
    ggplot2::coord_cartesian(ylim = c(y_floor, NA)) +
    ggplot2::scale_colour_manual(
      values = c(
        Model = "#0072B2",
        `Treat all` = "#D55E00",
        `Treat none` = "#999999"
      )
    ) +
    ggplot2::labs(
      x = "Threshold probability",
      y = "Net benefit",
      colour = NULL,
      title = "Decision curve analysis"
    ) +
    theme_funcml()
}
