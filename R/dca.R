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
#' @return A data frame of class `funcml_dcacurve` with `threshold`, `model`,
#'   `treat_all`, and `treat_none` net benefit columns. `plot()` draws the
#'   decision curve (see [plot.funcml_dcacurve()]).
#' @examples
#' set.seed(1)
#' truth <- factor(rbinom(200, 1, 0.3))
#' prob <- pmin(pmax(rnorm(200, mean = ifelse(truth == 1, 0.6, 0.3), sd = 0.15), 0), 1)
#' dc <- dca(truth, prob)
#' plot(dc)
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

  out <- data.frame(
    threshold = thresholds,
    model = net_benefit_model,
    treat_all = net_benefit_all,
    treat_none = 0,
    stringsAsFactors = FALSE
  )
  class(out) <- c("funcml_dcacurve", "data.frame")
  out
}

#' Plot a decision curve.
#'
#' Draws net benefit against the threshold probability for one or more
#' models, with the "treat all" (dashed) and "treat none" (net benefit 0)
#' reference strategies.
#'
#' @param x A `funcml_dcacurve` data frame returned by [dca()].
#' @param ... Further `funcml_dcacurve` objects (other models) computed on
#'   the same outcome and thresholds; named arguments set their labels.
#' @param labels Optional model labels, one per curve (`x` first). Defaults
#'   to the argument names, or `"Model"` for a single curve.
#' @param ylim Net benefit axis limits. Defaults to `-0.05` to the largest
#'   net benefit, so the steep fall of "treat all" does not flatten the plot.
#' @param title,subtitle,caption Optional plot text; `NULL` (default) leaves it out.
#' @return A `ggplot2` object.
#' @examples
#' set.seed(1)
#' y <- rbinom(300, 1, 0.3)
#' p1 <- plogis(qlogis(0.3) + 1.5 * (y - 0.3) + rnorm(300))
#' p2 <- plogis(qlogis(0.3) + 0.5 * (y - 0.3) + rnorm(300))
#' plot(dca(y, p1))
#' plot(dca(y, p1), dca(y, p2), labels = c("Strong", "Weak"))
#' @export
plot.funcml_dcacurve <- function(x, ..., labels = NULL, ylim = NULL, title = NULL, subtitle = NULL,
                                 caption = NULL) {
  cs <- c(list(x), list(...))
  nm <- names(cs)
  labels <- labels %||% if (length(cs) == 1L) "Model" else ifelse(nzchar(nm %||% ""), nm, paste("Model", seq_along(cs)))
  .dca_plot(cs, labels, ylim = ylim) + .ttl(title, subtitle, caption)
}

# Shared decision-curve drawing for dca() curves and interpret(method = "dca").
.dca_plot <- function(cs, labels, ylim = NULL) {
  ref <- cs[[1L]]
  mods <- do.call(rbind, Map(function(d, l) data.frame(threshold = d$threshold, nb = d$model, s = l), cs, labels))
  refs <- data.frame(threshold = rep(ref$threshold, 2L), nb = c(ref$treat_all, ref$treat_none),
                     s = rep(c("Treat all", "Treat none"), each = nrow(ref)))
  lv <- c(labels, "Treat all", "Treat none")
  long <- rbind(mods, refs); long$s <- factor(long$s, levels = lv)
  k <- length(labels)
  # Okabe-Ito without grey, black first: sober for one model, distinct for several.
  pal <- c("#000000", unname(.funcml_okabe_ito[c("blue", "vermillion", "green", "orange", "pink", "sky_blue")]))
  cols <- stats::setNames(c(rep_len(pal, k), "grey45", "grey45"), lv)
  ltys <- stats::setNames(c(rep("solid", k), "dashed", "solid"), lv)
  ylim <- ylim %||% c(-0.05, max(mods$nb, ref$treat_all, 0, na.rm = TRUE))
  ggplot2::ggplot(long, ggplot2::aes(x = threshold, y = nb, colour = s, linetype = s)) +
    ggplot2::geom_line(linewidth = 0.7) +
    ggplot2::scale_colour_manual(values = cols) +
    ggplot2::scale_linetype_manual(values = ltys) +
    ggplot2::coord_cartesian(ylim = ylim) +
    ggplot2::labs(x = "Threshold probability", y = "Net benefit", colour = NULL, linetype = NULL) +
    themefuncml() +
    ggplot2::theme(legend.position = "bottom")
}

#' Methods for decision curve analysis results.
#'
#' These provide the standard `print()` and `plot()` interfaces for
#' `funcml_dca` objects returned by `interpret(method = "dca")`.
#'
#' @param x A `funcml_dca` object.
#' @param digits Number of digits numeric columns are rounded to when printed.
#' @param ... Additional arguments (unused).
#' @param title,subtitle,caption Optional plot text; `NULL` (default) leaves it out.
#' @return `print()` returns the input object invisibly. `plot()` returns a
#'   `ggplot2` object.
#' @name dca-methods
#' @aliases print.funcml_dca plot.funcml_dca
#' @export
print.funcml_dca <- function(x, digits = 4L, ...) {
  cat(sprintf("<funcml_dca> positive: %s\n", x$result$positive %||% "NA"))
  print(.round_numeric_df(utils::head(x$result$curve, 10), digits = digits))
  invisible(x)
}

#' @rdname dca-methods
#' @export
plot.funcml_dca <- function(x, ..., title = NULL, subtitle = NULL, caption = NULL) {
  .dca_plot(list(x$result$curve), "Model") + .ttl(title, subtitle, caption)
}
