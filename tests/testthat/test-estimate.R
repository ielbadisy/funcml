library(funcml)

test_that("estimate recovers a positive ATE in regression", {
  set.seed(21)
  dat <- data.frame(
    trt = rbinom(250, 1, 0.5),
    x1 = rnorm(250),
    x2 = rnorm(250)
  )
  dat$y <- 2 * dat$trt + 0.6 * dat$x1 - 0.4 * dat$x2 + rnorm(250, sd = 0.5)

  ate <- estimate(dat, y ~ trt + x1 + x2, model = "glm", estimand = "ATE")
  att <- estimate(dat, y ~ trt + x1 + x2, model = "glm", estimand = "ATT")

  expect_s3_class(ate, "funcml_estimand")
  expect_gt(ate$estimate, 1)
  expect_gt(att$estimate, 1)
})

test_that("estimate supports binary outcome probabilities", {
  set.seed(22)
  dat <- data.frame(
    trt = factor(rbinom(220, 1, 0.45), levels = c(0, 1)),
    x1 = rnorm(220),
    x2 = rnorm(220)
  )
  lp <- -0.2 + 0.9 * (dat$trt == 1) + 0.5 * dat$x1 - 0.3 * dat$x2
  dat$y <- factor(ifelse(runif(220) < stats::plogis(lp), "no", "yes"), levels = c("no", "yes"))

  est <- estimate(dat, y ~ trt + x1 + x2, model = "glm", estimand = "ATE")
  p <- plot(est)
  p_effects <- plot(est, style = "effects")

  expect_s3_class(est, "funcml_estimand")
  expect_true(is.finite(est$estimate))
  expect_s3_class(p, "ggplot")
  expect_equal(p$labels$x, "Predicted outcome")
  expect_equal(p$labels$y, "Density")
  expect_match(p$labels$title, "ATE potential outcome distributions")
  expect_s3_class(p_effects, "ggplot")
  expect_equal(p_effects$labels$x, "Estimated unit-level effect")
  expect_equal(p_effects$labels$y, "Count")
  expect_match(p_effects$labels$title, "ATE estimate")
})

test_that("CATE requires newdata and returns weighted average over target rows", {
  set.seed(23)
  dat <- data.frame(
    trt = rbinom(120, 1, 0.5),
    x1 = rnorm(120),
    x2 = rnorm(120)
  )
  dat$y <- 1.1 * dat$trt + dat$x1 + rnorm(120, sd = 0.5)

  expect_error(
    estimate(dat, y ~ trt + x1 + x2, model = "glm", estimand = "CATE"),
    "newdata"
  )

  est <- estimate(
    dat, y ~ trt + x1 + x2, model = "glm",
    estimand = "CATE",
    newdata = dat[1:10, , drop = FALSE]
  )
  expect_equal(nrow(est$effects), 10)
})

test_that("IATE returns row-wise individualized effects", {
  set.seed(24)
  dat <- data.frame(
    trt = rbinom(100, 1, 0.5),
    x1 = rnorm(100),
    x2 = rnorm(100)
  )
  dat$y <- 0.8 * dat$trt + 0.5 * dat$x1 + rnorm(100, sd = 0.4)

  est <- estimate(
    dat, y ~ trt + x1 + x2, model = "glm",
    estimand = "IATE",
    newdata = dat[1:7, , drop = FALSE]
  )

  expect_true(is.na(est$estimate))
  expect_equal(nrow(est$effects), 7)
  expect_true(all(c("row_id", "effect", "mu1", "mu0", "weight") %in% names(est$effects)))
})
