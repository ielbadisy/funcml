.funcml_okabe_ito <- c(
  orange = "#E69F00", sky_blue = "#56B4E9", green = "#009E73",
  yellow = "#F0E442", blue = "#0072B2", vermillion = "#D55E00",
  pink = "#CC79A7", black = "#000000", grey = "#999999"
)

.funcml_palette <- list(
  ink = "#000000",
  panel = "white",
  grid = "grey92",
  accent = unname(.funcml_okabe_ito["blue"]),
  accent_alt = unname(.funcml_okabe_ito["grey"]),
  positive = unname(.funcml_okabe_ito["green"]),
  negative = unname(.funcml_okabe_ito["vermillion"]),
  neutral = unname(.funcml_okabe_ito["grey"]),
  context = unname(.funcml_okabe_ito["grey"])
)

#' FuncML plotting theme.
#'
#' A custom ggplot2 theme used across `funcml` plots, built on
#' `theme_classic()` with an Okabe-Ito colorblind-safe palette. It keeps a
#' clean background, restrained grid lines, and high-contrast labels so
#' package figures remain consistent and publication-friendly.
#'
#' @param base_size Base text size passed to the theme.
#' @return A ggplot2 theme object.
#' @examples
#' ggplot2::ggplot(mtcars, ggplot2::aes(wt, mpg)) +
#'   ggplot2::geom_point() +
#'   themefuncml()
#' @export
themefuncml <- function(base_size = 10) {
  ggplot2::theme_classic(base_size = base_size, base_family = "sans") +
    ggplot2::theme(
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"),
      legend.key.size = ggplot2::unit(0.4, "cm"),
      plot.title = ggplot2::element_text(face = "bold", size = base_size),
      panel.grid.major = ggplot2::element_line(colour = .funcml_palette$grid, linewidth = 0.3)
    )
}

.funcml_direction <- function(x) {
  ifelse(x >= 0, "Positive", "Negative")
}

.funcml_direction_scale_fill <- function(...) {
  ggplot2::scale_fill_manual(
    values = c(Positive = .funcml_palette$positive, Negative = .funcml_palette$negative),
    ...
  )
}

.funcml_direction_scale_colour <- function(...) {
  ggplot2::scale_colour_manual(
    values = c(Positive = .funcml_palette$positive, Negative = .funcml_palette$negative),
    ...
  )
}

# Title, subtitle and caption of every plot method; NULL (the default) leaves the text out.
.ttl <- function(title = NULL, subtitle = NULL, caption = NULL) {
  ggplot2::labs(title = title, subtitle = subtitle, caption = caption)
}

# Facet strip label stating which way a metric improves.
.metric_strip <- function(m) {
  m <- as.character(m)
  d <- vapply(m, function(z) {
    dir <- metric_direction(z)
    if (dir == "target") sprintf("closer to %g is better", .target_metrics[[z]]) else
      sprintf("%s is better", if (dir == "max") "higher" else "lower")
  }, character(1))
  u <- unique(m)
  factor(sprintf("%s (%s)", m, d), levels = sprintf("%s (%s)", u, d[match(u, m)]))
}

# Free value axes per metric facet with room between panels so tick labels do not collide.
.metric_facets <- function(scales = "free_x") {
  list(ggplot2::facet_wrap(~metric, scales = scales),
       ggplot2::scale_x_continuous(n.breaks = 4, expand = ggplot2::expansion(mult = 0.1)),
       ggplot2::theme(panel.spacing.x = ggplot2::unit(1.5, "lines")))
}
