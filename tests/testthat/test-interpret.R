library(funcml)

test_that("shap additivity approximately holds", {
  set.seed(1)
  dat <- data.frame(y = rnorm(30), x = rnorm(30), z = rnorm(30))
  f <- fit(y ~ x + z, data = dat, model = "glm")
  sh <- interpret(f, dat, method = "shap", nsim = 20, nsamples = 20)
  preds <- predict(f, dat[1, , drop = FALSE])
  baseline <- sh$result$baseline[1]
  approx_sum <- sum(sh$result$shap) + baseline
  expect_true(abs(approx_sum - preds[1]) < 1)
})

test_that("classification interpretability supports subsetted features", {
  set.seed(11)
  dat <- data.frame(
    x1 = rnorm(80),
    x2 = rnorm(80),
    x3 = rnorm(80)
  )
  eta <- 1.2 * dat$x1 - 0.8 * dat$x2 + 0.4 * dat$x3
  pr <- stats::plogis(eta)
  dat$y <- factor(ifelse(runif(80) < pr, "yes", "no"), levels = c("no", "yes"))

  fit_obj <- fit(y ~ x1 + x2 + x3, data = dat, model = "glm")

  vi <- interpret(
    fit_obj, dat,
    method = "vip",
    features = c("x1", "x2"),
    metric = "logloss",
    nsim = 3,
    seed = 1
  )
  loc <- interpret(
    fit_obj, dat,
    method = "local_model",
    features = c("x1", "x2"),
    newdata = dat[1, , drop = FALSE],
    nsamples = 40,
    class_level = "yes",
    k = 2
  )
  sh <- interpret(
    fit_obj, dat,
    method = "shap",
    features = c("x1", "x2"),
    newdata = dat[1, , drop = FALSE],
    nsim = 12,
    nsamples = 50,
    class_level = "yes",
    seed = 2
  )

  expect_true(all(c("x1", "x2") %in% vi$result$scores$feature))
  expect_gt(nrow(loc$result$results), 0)
  expect_equal(sort(sh$result$feature), c("x1", "x2"))
})

test_that("ICE handles vectorized feature grids for numeric predictors", {
  fit_obj <- fit(mpg ~ wt + hp, data = mtcars, model = "glm")

  ice <- interpret(
    fit_obj,
    mtcars,
    method = "ice",
    features = "wt",
    nsamples = 10
  )

  expect_s3_class(ice, "funcml_ice")
  expect_gt(nrow(ice$result$curves), 0)
  expect_true(all(c("id", "feature", "value", "yhat") %in% names(ice$result$curves)))
})
