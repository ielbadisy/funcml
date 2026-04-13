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

test_that("plot labels follow method-specific semantics", {
  set.seed(10)
  dat <- data.frame(y = rnorm(40), x = rnorm(40), z = rnorm(40))
  dat$y <- 1.8 * dat$x - 0.7 * dat$z + rnorm(40, sd = 0.2)
  fit_obj <- fit(y ~ x + z, data = dat, model = "glm")

  perm <- interpret(fit_obj, dat, method = "permute", metric = "rmse", nsim = 5, seed = 1)
  pdp_obj <- interpret(fit_obj, dat, method = "pdp", features = "x", nsamples = 20)
  ale_obj <- interpret(fit_obj, dat, method = "ale", features = "x", nsamples = 20)
  sh_obj <- interpret(fit_obj, dat, method = "shap", newdata = dat[1:10, , drop = FALSE], nsim = 10, nsamples = 20, seed = 2)

  perm_plot <- plot(perm)
  pdp_plot <- plot(pdp_obj)
  ale_plot <- plot(ale_obj)
  sh_plot <- plot(sh_obj, kind = "summary")

  expect_match(perm_plot$labels$x, "Change in RMSE after permutation")
  expect_equal(pdp_plot$labels$y, "Partial dependence")
  expect_match(ale_plot$labels$y, "ALE on response scale")
  expect_equal(sh_plot$labels$x, "SHAP value")
})

test_that("shap supports dependence, 2d dependence, force, and interaction plots", {
  set.seed(12)
  dat <- data.frame(y = rnorm(40), x = rnorm(40), z = rnorm(40))
  dat$y <- 1.5 * dat$x - 0.8 * dat$z + rnorm(40, sd = 0.2)
  fit_obj <- fit(y ~ x + z, data = dat, model = "glm")

  sh_multi <- interpret(
    fit_obj,
    dat,
    method = "shap",
    newdata = dat[1:5, , drop = FALSE],
    nsim = 10,
    nsamples = 20,
    seed = 3
  )
  sh_one <- interpret(
    fit_obj,
    dat,
    method = "shap",
    newdata = dat[1, , drop = FALSE],
    nsim = 10,
    nsamples = 20,
    seed = 4
  )

  p_dep <- plot(sh_multi, kind = "dependence", v = "x")
  p_dep2d <- plot(sh_multi, kind = "dependence2d", feature_x = "x", feature_y = "z")
  p_force <- plot(sh_one, kind = "force")
  p_inter <- plot(sh_multi, kind = "interaction", interaction_kind = "bar", nsim = 6)

  expect_s3_class(p_dep, "ggplot")
  expect_s3_class(p_dep2d, "ggplot")
  expect_s3_class(p_force, "ggplot")
  expect_s3_class(p_inter, "ggplot")
})
