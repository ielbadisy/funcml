library(funcml)

test_that("estimate_vip returns a causal importance object for ATE refit mode", {
  set.seed(101)
  n <- 300
  dat <- data.frame(
    x1 = rnorm(n),
    x2 = rnorm(n)
  )
  dat$trt <- rbinom(n, 1, stats::plogis(1.1 * dat$x1))
  dat$y <- 1.4 * dat$trt + 0.9 * dat$x1 + rnorm(n, sd = 0.4)

  est <- estimate(dat, y ~ trt + x1 + x2, model = "glm", estimand = "ATE")
  vip <- estimate_vip(est, mode = "refit", nsim = 8, seed = 7)
  p <- plot(vip)

  expect_s3_class(vip, "funcml_estimand_vip")
  expect_equal(vip$estimand_role, "scalar_contrast")
  expect_true(all(c("variable", "importance", "std_dev", "rank") %in% names(vip$result$scores)))
  expect_s3_class(p, "ggplot")
  expect_equal(vip$result$scores$variable[1], "x1")
  expect_gt(vip$result$scores$importance[vip$result$scores$variable == "x1"], 0)
})

test_that("estimate_vip isolates effect modifiers for IATE evaluate mode", {
  set.seed(102)
  n <- 240
  dat <- data.frame(
    trt = rbinom(n, 1, 0.5),
    x1 = rnorm(n),
    x2 = rnorm(n),
    x3 = rnorm(n)
  )
  dat$y <- 0.5 + dat$x2 + dat$trt * (1 + 1.8 * dat$x1) + rnorm(n, sd = 0.3)

  est <- estimate(dat, y ~ trt * x1 + x2 + x3, model = "glm", estimand = "IATE")
  vip <- estimate_vip(est, mode = "evaluate", nsim = 6, seed = 11)

  expect_equal(vip$estimand_role, "individualized_profile")
  expect_equal(vip$result$scores$variable[1], "x1")
  expect_gt(vip$result$scores$importance[vip$result$scores$variable == "x1"], 0)
  expect_equal(vip$result$scores$importance[vip$result$scores$variable == "x2"], 0, tolerance = 1e-8)
  expect_equal(vip$result$scores$importance[vip$result$scores$variable == "x3"], 0, tolerance = 1e-8)
})

test_that("estimate_vip uses stored target data for CATE objects", {
  set.seed(103)
  dat <- data.frame(
    trt = rbinom(120, 1, 0.5),
    x1 = rnorm(120),
    x2 = rnorm(120)
  )
  dat$y <- 0.8 * dat$trt + 0.6 * dat$x1 + rnorm(120, sd = 0.4)

  est <- estimate(
    dat,
    y ~ trt + x1 + x2,
    model = "glm",
    estimand = "CATE",
    newdata = dat[1:10, , drop = FALSE]
  )

  vip <- estimate_vip(est, mode = "evaluate", nsim = 3, seed = 5)

  expect_s3_class(vip, "funcml_estimand_vip")
  expect_equal(vip$estimand_role, "target_average_contrast")
  expect_equal(sort(vip$result$scores$variable), c("x1", "x2"))
})
