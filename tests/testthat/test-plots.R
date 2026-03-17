library(funcml)

test_that("lime alias returns a ggplot local explanation", {
  set.seed(5)
  dat <- data.frame(y = rnorm(30), x = rnorm(30), z = rnorm(30))
  dat$y <- 1.2 * dat$x - 0.4 * dat$z + rnorm(30, sd = 0.15)
  fit_obj <- fit(y ~ x + z, data = dat, model = "glm")

  lime_obj <- interpret(
    fit_obj,
    dat,
    method = "lime",
    newdata = dat[1, , drop = FALSE],
    nsamples = 20,
    k = 2
  )

  p <- plot(lime_obj)
  expect_s3_class(lime_obj, "funcml_lime")
  expect_s3_class(p, "ggplot")
})

test_that("shap plot returns ggplot objects", {
  set.seed(8)
  dat <- data.frame(
    y = rnorm(40),
    x = rnorm(40),
    z = rnorm(40)
  )
  dat$y <- 2 * dat$x - dat$z + rnorm(40, sd = 0.15)
  fit_obj <- fit(y ~ x + z, data = dat, model = "glm")

  sh <- interpret(
    fit_obj,
    dat,
    method = "shap",
    newdata = dat[1, , drop = FALSE],
    nsim = 25,
    nsamples = 25
  )

  expect_s3_class(plot(sh), "ggplot")
  expect_s3_class(plot(sh, kind = "waterfall"), "ggplot")
})
