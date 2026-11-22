# Native ggplot2 SHAP visualizations, replacing the shapviz dependency.
#
# The SHAP values themselves are already funcml's own Monte Carlo
# permutation estimate (interpret_shap(), in interpret.R); shapviz was only
# ever used here for plotting the resulting long-format table
# (x$result: observation, feature, shap, baseline, prediction, raw_value,
# feature_value, feature_label). These functions read that table directly.

.shap_feature_order <- function(df, features) {
  imp <- vapply(features, function(feat) mean(abs(df$shap[df$feature == feat])), numeric(1))
  features[order(imp)]
}

.shap_waterfall_data <- function(df, row_id, max_display = 10L) {
  row_df <- df[df$observation == row_id, , drop = FALSE]
  row_df <- row_df[order(-abs(row_df$shap)), , drop = FALSE]
  baseline <- row_df$baseline[1]
  prediction <- row_df$prediction[1]
  if (nrow(row_df) > max_display) {
    keep <- row_df[seq_len(max_display - 1L), , drop = FALSE]
    rest <- row_df[-seq_len(max_display - 1L), , drop = FALSE]
    other <- data.frame(
      feature_label = sprintf("%d other features", nrow(rest)),
      shap = sum(rest$shap),
      stringsAsFactors = FALSE
    )
    row_df <- rbind(keep[, c("feature_label", "shap")], other)
  } else {
    row_df <- row_df[, c("feature_label", "shap")]
  }
  row_df <- row_df[order(abs(row_df$shap)), , drop = FALSE]
  row_df$end <- baseline + cumsum(row_df$shap)
  row_df$start <- row_df$end - row_df$shap
  row_df$sign <- ifelse(row_df$shap >= 0, "Positive", "Negative")
  row_df$y <- factor(row_df$feature_label, levels = row_df$feature_label)
  list(data = row_df, baseline = baseline, prediction = prediction)
}

# Okabe-Ito: vermillion raises the prediction, blue lowers it.
.shap_cols <- c(Positive = "#D55E00", Negative = "#0072B2")
.shap_signed_scale <- function() {
  ggplot2::scale_colour_manual(values = .shap_cols, labels = c(Positive = "Raises", Negative = "Lowers"))
}

.shap_signed_fill_scale <- function() {
  ggplot2::scale_fill_manual(values = .shap_cols, labels = c(Positive = "Raises", Negative = "Lowers"))
}

# Waterfall: bars run from the baseline E[f(x)] (bottom) to the prediction f(x) (top), largest |SHAP| on top;
# y labels carry the feature values, bar labels the signed SHAP values.
shap_plot_waterfall <- function(df, row_id = NULL, max_display = 10L) {
  row_id <- row_id %||% min(df$observation)
  b <- .shap_waterfall_data(df, row_id, max_display = max_display)
  d <- b$data; d$yi <- seq_len(nrow(d))
  d$lx <- pmax(d$start, d$end); d$hj <- -0.1
  rng <- range(c(d$start, d$end))
  ggplot2::ggplot(d) +
    ggplot2::geom_vline(xintercept = b$baseline, linetype = "dashed", colour = "grey55", linewidth = 0.4) +
    ggplot2::geom_vline(xintercept = b$prediction, colour = "grey25", linewidth = 0.4) +
    ggplot2::geom_rect(ggplot2::aes(xmin = pmin(start, end), xmax = pmax(start, end), ymin = yi - 0.35,
                                    ymax = yi + 0.35, fill = sign)) +
    ggplot2::geom_text(ggplot2::aes(x = lx, y = yi, label = sprintf("%+.3f", shap)), hjust = -0.1, size = 3,
                       colour = "grey20") +
    ggplot2::scale_y_continuous(breaks = d$yi, labels = d$feature_label, expand = ggplot2::expansion(add = 0.5)) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0.04, 0.2))) +
    .shap_signed_fill_scale() +
    ggplot2::labs(x = sprintf("Prediction (dashed: baseline E[f(x)] = %.3f; solid: f(x) = %.3f)",
                              b$baseline, b$prediction), y = NULL, fill = NULL) +
    themefuncml() +
    ggplot2::theme(legend.position = "bottom", panel.grid.major.y = ggplot2::element_blank())
}

shap_plot_force <- function(df, row_id = NULL, max_display = 10L) {
  row_id <- row_id %||% min(df$observation)
  b <- .shap_waterfall_data(df, row_id, max_display = max_display)
  d <- b$data; f <- b$prediction
  # positive contributions end at f(x) and negative ones start there, so segments never overlap;
  # larger contributions sit next to f(x), as in the force plot of Lundberg and Lee (2017)
  pos <- d[d$shap >= 0, , drop = FALSE]; pos <- pos[order(pos$shap), , drop = FALSE]
  pos$end <- f - sum(pos$shap) + cumsum(pos$shap); pos$start <- pos$end - pos$shap
  neg <- d[d$shap < 0, , drop = FALSE]
  neg <- neg[order(neg$shap), , drop = FALSE]  # most negative next to f(x)
  neg$start <- f + c(0, cumsum(-neg$shap))[seq_len(nrow(neg))]; neg$end <- neg$start - neg$shap
  d <- rbind(pos, neg)
  d$mid <- (d$start + d$end) / 2
  d$lab <- sprintf("%s\n%+.3f", d$feature_label, d$shap)
  # labels go above or below the bar, whichever side has the last label further away; a segment
  # narrower than 3% of the bar is left unlabeled when both sides are still crowded
  d <- d[order(d$mid), , drop = FALSE]
  w <- diff(range(c(d$start, d$end))); gap <- 0.14 * w; last <- c(up = -Inf, down = -Inf)
  d$ylab <- NA_real_
  for (k in seq_len(nrow(d))) {
    side <- if (d$mid[k] - last[["up"]] >= d$mid[k] - last[["down"]]) "up" else "down"
    if (d$mid[k] - last[[side]] < gap && abs(d$shap[k]) < 0.03 * w) next
    d$ylab[k] <- if (side == "up") 1.45 else 0.55; last[[side]] <- d$mid[k]
  }
  lab <- d[!is.na(d$ylab), , drop = FALSE]
  ggplot2::ggplot(d) +
    ggplot2::geom_rect(ggplot2::aes(xmin = pmin(start, end), xmax = pmax(start, end), ymin = 0.8, ymax = 1.2,
                                    fill = sign), colour = "white", linewidth = 0.3) +
    ggplot2::geom_segment(data = lab, ggplot2::aes(x = mid, xend = mid, y = ifelse(ylab > 1, 1.2, 0.8),
                                       yend = ifelse(ylab > 1, 1.32, 0.68)), colour = "grey50", linewidth = 0.3) +
    ggplot2::geom_text(data = lab, ggplot2::aes(x = mid, y = ylab, label = lab), size = 2.8, lineheight = 0.9,
                       colour = "grey20") +
    ggplot2::geom_vline(xintercept = b$baseline, linetype = "dashed", colour = "grey50") +
    ggplot2::geom_vline(xintercept = f, colour = "black", linewidth = 0.4) +
    .shap_signed_fill_scale() +
    ggplot2::scale_y_continuous(limits = c(0.3, 1.7), breaks = NULL) +
    ggplot2::labs(x = sprintf("Prediction (dashed: baseline E[f(x)] = %.3f; solid: f(x) = %.3f)",
                              b$baseline, f), y = NULL, fill = NULL) +
    themefuncml() +
    ggplot2::theme(legend.position = "bottom", panel.grid.major.y = ggplot2::element_blank())
}

shap_plot_importance <- function(df) {
  features <- unique(df$feature)
  ord <- .shap_feature_order(df, features)
  imp_df <- data.frame(
    feature = ord,
    importance = vapply(ord, function(feat) mean(abs(df$shap[df$feature == feat])), numeric(1)),
    stringsAsFactors = FALSE
  )
  imp_df$feature <- factor(imp_df$feature, levels = imp_df$feature)
  ggplot2::ggplot(imp_df, ggplot2::aes(x = importance, y = feature)) +
    ggplot2::geom_col(fill = "grey35") +
    ggplot2::geom_text(
      ggplot2::aes(label = sprintf("%.3f", importance)),
      hjust = -0.15, size = 3.1, colour = "grey20"
    ) +
    ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.15))) +
    ggplot2::labs(x = "Mean |SHAP value|", y = NULL) +
    themefuncml()
}

.shap_beeswarm_colour_scale <- function() {
  ggplot2::scale_colour_gradient(
    low = "#1E88E5", high = "#FF0D57", na.value = "grey60",
    breaks = c(0, 1), labels = c("Low", "High"), name = "Feature value"
  )
}

shap_plot_beeswarm <- function(df, v = NULL) {
  features <- if (!is.null(v)) v else unique(df$feature)
  ord <- .shap_feature_order(df, features)

  plot_df <- df[df$feature %in% features, , drop = FALSE]
  plot_df$scaled_value <- stats::ave(plot_df$raw_value, plot_df$feature, FUN = function(x) {
    if (all(is.na(x)) || diff(range(x, na.rm = TRUE)) == 0) {
      return(rep(0.5, length(x)))
    }
    (x - min(x, na.rm = TRUE)) / diff(range(x, na.rm = TRUE))
  })
  plot_df$feature <- factor(plot_df$feature, levels = ord)

  ggplot2::ggplot(plot_df, ggplot2::aes(x = shap, y = feature, colour = scaled_value)) +
    ggplot2::geom_vline(xintercept = 0, colour = "black", linewidth = 0.4) +
    ggplot2::geom_jitter(height = 0.3, width = 0, alpha = 0.85, size = 1.8) +
    .shap_beeswarm_colour_scale() +
    ggplot2::labs(x = "SHAP value (impact on model output)", y = NULL) +
    themefuncml() +
    ggplot2::theme(axis.text.y = ggplot2::element_text(hjust = 0))
}

.shap_dependence_color_var <- function(df, v, features) {
  candidates <- setdiff(features, v)
  if (!length(candidates)) {
    return(NULL)
  }
  shap_v <- df$shap[df$feature == v]
  cors <- vapply(candidates, function(feat) {
    val <- suppressWarnings(as.numeric(df$raw_value[df$feature == feat]))
    if (all(is.na(val)) || stats::sd(val, na.rm = TRUE) == 0) {
      return(0)
    }
    abs(suppressWarnings(stats::cor(shap_v, val, use = "pairwise.complete.obs")))
  }, numeric(1))
  if (all(!is.finite(cors)) || all(cors == 0)) {
    return(NULL)
  }
  candidates[which.max(cors)]
}

shap_plot_dependence <- function(df, v, color_var = "auto", features = unique(df$feature)) {
  row_v <- df[df$feature == v, c("observation", "shap", "raw_value", "feature_value"), drop = FALSE]
  x_val <- suppressWarnings(as.numeric(row_v$raw_value))
  if (all(is.na(x_val))) {
    x_val <- row_v$feature_value
  }
  plot_df <- data.frame(x = x_val, shap = row_v$shap, stringsAsFactors = FALSE)

  color_var <- if (identical(color_var, "auto")) {
    .shap_dependence_color_var(df, v, features)
  } else if (identical(color_var, "none") || is.null(color_var)) {
    NULL
  } else {
    color_var
  }

  p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = x, y = shap))
  if (!is.null(color_var)) {
    color_val <- suppressWarnings(as.numeric(df$raw_value[df$feature == color_var]))
    plot_df$colour_value <- color_val
    p <- ggplot2::ggplot(plot_df, ggplot2::aes(x = x, y = shap, colour = colour_value)) +
      ggplot2::scale_colour_gradient(low = "#0072B2", high = "#D55E00", na.value = "grey60", name = color_var)
  }
  p +
    ggplot2::geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.3) +
    ggplot2::geom_point(alpha = 0.75, size = 1.6) +
    ggplot2::labs(x = v, y = "SHAP value") +
    themefuncml()
}

shap_plot_dependence2d <- function(df, x_var, y_var, s_inter = NULL) {
  row_x <- df[df$feature == x_var, c("observation", "raw_value", "feature_value"), drop = FALSE]
  row_y <- df[df$feature == y_var, c("observation", "raw_value", "feature_value"), drop = FALSE]
  x_val <- suppressWarnings(as.numeric(row_x$raw_value))
  if (all(is.na(x_val))) x_val <- row_x$feature_value
  y_val <- suppressWarnings(as.numeric(row_y$raw_value))
  if (all(is.na(y_val))) y_val <- row_y$feature_value

  fill_val <- if (!is.null(s_inter)) {
    obs_ids <- sort(unique(df$observation))
    vapply(obs_ids, function(id) s_inter[as.character(id), x_var, y_var], numeric(1))
  } else {
    row_x$shap <- df$shap[df$feature == x_var]
    row_y$shap <- df$shap[df$feature == y_var]
    row_x$shap + row_y$shap
  }

  plot_df <- data.frame(x = x_val, y = y_val, fill_val = fill_val, stringsAsFactors = FALSE)
  ggplot2::ggplot(plot_df, ggplot2::aes(x = x, y = y, colour = fill_val)) +
    ggplot2::geom_point(size = 2.2, alpha = 0.85) +
    ggplot2::scale_colour_gradient2(low = "#0072B2", mid = "grey90", high = "#D55E00", midpoint = 0) +
    ggplot2::labs(
      x = x_var, y = y_var, colour = "SHAP\ninteraction"
    ) +
    themefuncml()
}

.shap_interaction_pairs <- function(s_inter) {
  features <- dimnames(s_inter)[[2]]
  pairs <- utils::combn(features, 2, simplify = FALSE)
  do.call(rbind, lapply(pairs, function(pair) {
    vals <- s_inter[, pair[1], pair[2]]
    data.frame(
      pair = sprintf("%s:%s", pair[1], pair[2]),
      mean_abs = mean(abs(vals)),
      stringsAsFactors = FALSE
    )
  }))
}

shap_plot_interaction <- function(s_inter, kind = c("bar", "beeswarm")) {
  kind <- match.arg(kind)
  pair_df <- .shap_interaction_pairs(s_inter)
  pair_df <- pair_df[order(pair_df$mean_abs), , drop = FALSE]
  pair_df$pair <- factor(pair_df$pair, levels = pair_df$pair)

  if (kind == "bar") {
    return(
      ggplot2::ggplot(pair_df, ggplot2::aes(x = mean_abs, y = pair)) +
        ggplot2::geom_col(fill = "grey35") +
        ggplot2::geom_text(
          ggplot2::aes(label = sprintf("%.3f", mean_abs)),
          hjust = -0.15, size = 3.1, colour = "grey20"
        ) +
        ggplot2::scale_x_continuous(expand = ggplot2::expansion(mult = c(0, 0.15))) +
        ggplot2::labs(x = "Mean |SHAP interaction|", y = NULL) +
        themefuncml()
    )
  }

  obs_ids <- dimnames(s_inter)[[1]]
  features <- dimnames(s_inter)[[2]]
  pairs <- utils::combn(features, 2, simplify = FALSE)
  long <- do.call(rbind, lapply(pairs, function(pair) {
    data.frame(
      pair = sprintf("%s:%s", pair[1], pair[2]),
      value = s_inter[, pair[1], pair[2]],
      stringsAsFactors = FALSE
    )
  }))
  long$pair <- factor(long$pair, levels = levels(pair_df$pair))
  ggplot2::ggplot(long, ggplot2::aes(x = value, y = pair)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey70", linewidth = 0.3) +
    ggplot2::geom_jitter(height = 0.25, width = 0, alpha = 0.7, size = 1.4, colour = "grey35") +
    ggplot2::labs(x = "SHAP interaction value", y = NULL) +
    themefuncml()
}
