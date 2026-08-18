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

.shap_signed_scale <- function() {
  ggplot2::scale_colour_manual(values = c(Positive = "#2ca25f", Negative = "#de2d26"))
}

shap_plot_waterfall <- function(df, row_id = NULL, max_display = 10L) {
  row_id <- row_id %||% min(df$observation)
  built <- .shap_waterfall_data(df, row_id, max_display = max_display)
  ggplot2::ggplot(built$data, ggplot2::aes(y = y)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = start, xend = end, yend = y, colour = sign),
      linewidth = 6, lineend = "butt"
    ) +
    ggplot2::geom_vline(xintercept = built$baseline, linetype = "dashed", colour = "grey50") +
    .shap_signed_scale() +
    ggplot2::labs(
      x = sprintf("Prediction (baseline = %.3f)", built$baseline),
      y = NULL, colour = NULL,
      title = sprintf("SHAP waterfall (observation %s, prediction = %.3f)", row_id, built$prediction)
    ) +
    theme_funcml()
}

shap_plot_force <- function(df, row_id = NULL) {
  row_id <- row_id %||% min(df$observation)
  built <- .shap_waterfall_data(df, row_id, max_display = nrow(df[df$observation == row_id, ]))
  built$data$y <- "Force"
  ggplot2::ggplot(built$data, ggplot2::aes(y = y)) +
    ggplot2::geom_segment(
      ggplot2::aes(x = start, xend = end, yend = y, colour = sign),
      linewidth = 10, lineend = "butt"
    ) +
    ggplot2::geom_vline(xintercept = built$baseline, linetype = "dashed", colour = "grey50") +
    ggplot2::geom_vline(xintercept = built$prediction, colour = "black", linewidth = 0.4) +
    .shap_signed_scale() +
    ggplot2::labs(
      x = sprintf("Prediction (baseline = %.3f)", built$baseline),
      y = NULL, colour = NULL,
      title = sprintf("SHAP force (observation %s, prediction = %.3f)", row_id, built$prediction)
    ) +
    theme_funcml() +
    ggplot2::theme(axis.text.y = ggplot2::element_blank(), axis.ticks.y = ggplot2::element_blank())
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
    ggplot2::labs(x = "Mean |SHAP value|", y = NULL, title = "SHAP feature importance") +
    theme_funcml()
}

shap_plot_beeswarm <- function(df) {
  features <- unique(df$feature)
  ord <- .shap_feature_order(df, features)
  plot_df <- df[df$feature %in% features, , drop = FALSE]
  plot_df$feature <- factor(plot_df$feature, levels = ord)
  plot_df$scaled_value <- unlist(lapply(split(plot_df$raw_value, plot_df$feature), function(v) {
    if (all(is.na(v)) || diff(range(v, na.rm = TRUE)) == 0) {
      return(rep(0.5, length(v)))
    }
    (v - min(v, na.rm = TRUE)) / diff(range(v, na.rm = TRUE))
  }), use.names = FALSE)
  ggplot2::ggplot(plot_df, ggplot2::aes(x = shap, y = feature, colour = scaled_value)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey70", linewidth = 0.3) +
    ggplot2::geom_jitter(height = 0.25, width = 0, alpha = 0.7, size = 1.4) +
    ggplot2::scale_colour_gradient(
      low = "#0072B2", high = "#D55E00", na.value = "grey60",
      breaks = c(0, 1), labels = c("Low", "High")
    ) +
    ggplot2::labs(x = "SHAP value", y = NULL, colour = "Feature value", title = "SHAP summary") +
    theme_funcml()
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
    ggplot2::labs(x = v, y = "SHAP value", title = sprintf("SHAP dependence: %s", v)) +
    theme_funcml()
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
      x = x_var, y = y_var, colour = "SHAP\ninteraction",
      title = sprintf("SHAP interaction: %s x %s", x_var, y_var)
    ) +
    theme_funcml()
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
        ggplot2::labs(x = "Mean |SHAP interaction|", y = NULL, title = "SHAP interaction strength") +
        theme_funcml()
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
    ggplot2::labs(x = "SHAP interaction value", y = NULL, title = "SHAP interaction strength") +
    theme_funcml()
}
