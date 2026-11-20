test_that("calslope and citl match calibrationfit() and glm", {
  set.seed(1); p <- runif(300); y <- rbinom(300, 1, plogis(0.8 * qlogis(p) - 0.3))
  lp <- qlogis(p)
  expect_equal(calslope(y, p), unname(coef(glm(y ~ lp, family = binomial()))[2]))
  expect_equal(citl(y, p), unname(coef(glm(y ~ 1, family = binomial(), offset = lp))[1]))
  expect_true(all(c("calslope", "citl") %in% listmetrics()$metric))
})

test_that("bootvalidate() calibration slope matches rms::validate() Slope", {
  skip_if_not_installed("rms")
  set.seed(4); n <- 300
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  d$y <- factor(rbinom(n, 1, plogis(0.7 * d$x1 - 0.4 * d$x2)))
  f <- y ~ x1 + x2 + x3
  bv <- bootvalidate(d, f, "glm", B = 30, seed = 1, metrics = c("calslope", "citl"))
  s <- bv$summary
  set.seed(1); v <- rms::validate(rms::lrm(f, data = d, x = TRUE, y = TRUE), B = 30)
  expect_equal(s$apparent, c(1, 0), tolerance = 1e-6)
  expect_equal(s$corrected[1], v["Slope", "index.corrected"], tolerance = 1e-6)
  expect_true(all(is.na(s$est632plus)) && all(is.na(s$gamma)))
  # CITL optimism from scratch on the same bootstrap rows
  o <- vapply(bv$indices, function(i) {
    m <- glm(f, binomial, d[i, ]); lo <- function(dd) predict(m, dd)
    ci <- function(dd) coef(glm(dd$y ~ 1, family = binomial(), offset = lo(dd)))[1]
    ci(d[i, ]) - ci(d)
  }, numeric(1))
  expect_equal(s$optimism[2], mean(o), tolerance = 1e-6)
})

test_that("calibration metrics work in evaluate() and are refused by tune()", {
  set.seed(2); d <- data.frame(x = rnorm(200)); d$y <- factor(rbinom(200, 1, plogis(d$x)))
  ev <- evaluate(d, y ~ x, model = "glm", resampling = cv(3, seed = 1), metrics = c("calslope", "citl"))
  expect_true(all(is.finite(ev$summary$mean)))
  expect_error(tune(d, y ~ x, model = "glmnet", grid = data.frame(alpha = c(0, 1)), metric = "calslope"), "calibration")
})
