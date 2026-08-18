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
#'   theme_funcml()
#' @export
theme_funcml <- function(base_size = 10) {
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
