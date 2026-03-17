.funcml_palette <- list(
  ink = "#18212F",
  panel = "#F6F1E8",
  grid = "#D9CDBB",
  accent = "#C45A3C",
  accent_alt = "#2C6E73",
  positive = "#2F8F6B",
  negative = "#C45A3C",
  neutral = "#6E6A63",
  context = "#9C7A5B"
)

#' FuncML plotting theme.
#'
#' A custom ggplot2 theme used across `funcml` plots. It favors warm paper
#' panels, high-contrast text, and restrained accent colors so interpretability
#' plots share one visual language.
#'
#' @param base_size Base text size passed to the theme.
#' @return A ggplot2 theme object.
#' @export
theme_funcml <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      plot.title.position = "plot",
      plot.title = ggplot2::element_text(face = "bold", colour = .funcml_palette$ink, size = base_size + 2.5),
      plot.subtitle = ggplot2::element_text(colour = .funcml_palette$neutral, margin = ggplot2::margin(b = 8)),
      axis.title = ggplot2::element_text(colour = .funcml_palette$ink, face = "bold"),
      axis.text = ggplot2::element_text(colour = .funcml_palette$ink),
      panel.background = ggplot2::element_rect(fill = .funcml_palette$panel, colour = NA),
      plot.background = ggplot2::element_rect(fill = "white", colour = NA),
      plot.margin = ggplot2::margin(10, 14, 10, 10),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(colour = .funcml_palette$grid, linewidth = 0.4),
      axis.line = ggplot2::element_line(colour = .funcml_palette$grid, linewidth = 0.35),
      strip.background = ggplot2::element_rect(fill = "#E9E0D1", colour = NA),
      strip.text = ggplot2::element_text(face = "bold", colour = .funcml_palette$ink, margin = ggplot2::margin(4, 4, 4, 4)),
      legend.title = ggplot2::element_text(face = "bold", colour = .funcml_palette$ink),
      legend.text = ggplot2::element_text(colour = .funcml_palette$ink),
      legend.background = ggplot2::element_rect(fill = grDevices::adjustcolor("white", alpha.f = 0.9), colour = NA),
      legend.key = ggplot2::element_rect(fill = .funcml_palette$panel, colour = NA)
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
