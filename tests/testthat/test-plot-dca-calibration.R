# Book pass 4: plot() on dca()/calibrationcurve() results drew a pairs plot (plain data frames).
# Simulated stand-in for the book's glow500 repro (n = 500, about 25% events).
glow <- function() {
  set.seed(2024); n <- 500
  g <- data.frame(age = rnorm(n, 69, 9), prior = rbinom(n, 1, 0.25), mom = rbinom(n, 1, 0.12))
  g$y <- rbinom(n, 1, plogis(-1.4 + 0.04 * (g$age - 69) + 0.8 * g$prior + 0.6 * g$mom))
  g$fracture <- factor(ifelse(g$y == 1, "Yes", "No"), c("No", "Yes"))
  m <- stats::glm(y ~ age + prior + mom, binomial, g)
  transform(g, p = stats::fitted(m), p0 = stats::fitted(stats::update(m, . ~ age)))
}

test_that("dca() and calibrationcurve() dispatch to their own plot methods", {
  g <- glow()
  dc <- dca(g$fracture, g$p, thresholds = seq(0.01, 0.6, by = 0.01))
  expect_s3_class(dc, c("funcml_dcacurve", "data.frame"))
  pl <- plot(dc)
  expect_s3_class(pl, "ggplot")
  expect_equal(levels(pl$data$s), c("Model", "Treat all", "Treat none"))
  expect_equal(pl$coordinates$limits$y, c(-0.05, max(dc$model, dc$treat_all)))
  expect_equal(pl$labels$y, "Net benefit")
  p2 <- plot(dc, Age = dca(g$fracture, g$p0, thresholds = dc$threshold), labels = c("Full", "Age"))
  expect_equal(levels(p2$data$s), c("Full", "Age", "Treat all", "Treat none"))
  expect_equal(nrow(p2$data), 4 * nrow(dc))
  cc <- calibrationcurve(g$fracture, g$p)
  expect_s3_class(cc, c("funcml_calcurve", "data.frame"))
  expect_s3_class(plot(cc), "ggplot")
  expect_equal(ece(g$fracture, g$p), sum(cc$n * cc$abs_gap) / sum(cc$n))
})

test_that("plotted net benefit equals dcurves::dca()", {
  skip_if_not_installed("dcurves")
  g <- glow(); pt <- seq(0.05, 0.5, by = 0.05)
  dc <- dca(g$fracture, g$p, thresholds = pt)
  d <- plot(dc)$data
  ref <- dcurves::dca(y ~ p, data = g, thresholds = pt)$dca
  nb <- function(v) ref$net_benefit[ref$variable == v]
  expect_equal(d$nb[d$s == "Model"], nb("p"), tolerance = 1e-10)
  expect_equal(d$nb[d$s == "Treat all"], nb("all"), tolerance = 1e-10)
  expect_equal(d$nb[d$s == "Treat none"], nb("none"), tolerance = 1e-10)
})

test_that("interpret() dca and calibration plots still draw", {
  f <- fit(am ~ wt + hp, data = transform(mtcars, am = factor(am)), model = "glm")
  d <- interpret(f, data = transform(mtcars, am = factor(am)), method = "dca")
  expect_equal(levels(plot(d)$data$s), c("Model", "Treat all", "Treat none"))
  cal <- interpret(f, data = transform(mtcars, am = factor(am)), method = "calibration")
  expect_s3_class(plot(cal), "ggplot")
})
