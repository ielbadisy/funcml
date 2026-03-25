library(funcml)

test_that("local_model, interaction, and surrogate return structured results", {
  set.seed(12)
  dat <- data.frame(
    y = rnorm(50),
    x = rnorm(50),
    z = rnorm(50)
  )
  dat$y <- 1.5 * dat$x - 0.2 * dat$z + rnorm(50, sd = 0.1)
  fit_obj <- fit(y ~ x + z, data = dat, model = "glm")

  loc <- interpret(fit_obj, dat, method = "local_model", newdata = dat[1, , drop = FALSE], nsamples = 20, k = 2)
  ia <- interpret(fit_obj, dat, method = "interaction", nsamples = 30, grid_size = 8)
  sur <- interpret(fit_obj, dat, method = "surrogate", maxdepth = 2)

  expect_s3_class(loc, "funcml_iml_local_model")
  expect_true(all(c("results", "fidelity", "weights", "model") %in% names(loc$result)))
  expect_true(all(c("feature", "beta", "effect") %in% names(loc$result$results)))

  expect_s3_class(ia, "funcml_interaction")
  expect_true(all(c("results", "anchor_feature") %in% names(ia$result)))
  expect_true(all(c("feature", "interaction") %in% names(ia$result$results)))

  expect_s3_class(sur, "funcml_surrogate")
  expect_true(all(c("model", "fidelity") %in% names(sur$result)))
})
