test_that("xgboost regression objective is passed through (Poisson)", {
  skip_if_not_installed("xgboost")
  set.seed(4)
  n <- 300
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n))
  d$y <- rpois(n, exp(0.5 + 0.6 * d$x1))
  spec <- list(objective = "count:poisson", nrounds = 50, max_depth = 2, eta = 0.1)
  f <- fit(y ~ x1 + x2, d, model = "xgboost", spec = spec)
  expect_identical(xgboost::xgb.config(enginemodel(f))$learner$objective$name, "count:poisson")
  X <- as.matrix(d[, c("x1", "x2")])
  ref <- xgboost::xgb.train(
    params = list(max_depth = 2, eta = 0.1, subsample = 1, colsample_bytree = 1,
                  objective = "count:poisson"),
    data = xgboost::xgb.DMatrix(X, label = d$y), nrounds = 50, verbose = 0
  )
  p <- predict(f, d)
  expect_equal(as.numeric(p), as.numeric(predict(ref, xgboost::xgb.DMatrix(X))), tolerance = 1e-6)
  expect_true(all(p > 0))
  # mean-scale predictions track the true mean better than a constant
  expect_lt(mean((p - exp(0.5 + 0.6 * d$x1))^2), stats::var(exp(0.5 + 0.6 * d$x1)))
  d$y[1] <- -1
  expect_error(fit(y ~ x1 + x2, d, model = "xgboost", spec = spec), "non-negative")
})
