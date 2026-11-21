test_that("fit(seed = ) reaches native engines", {
  for (m in c("densemlp", "mlp", "fastgbm")) {
    skip_if_not_installed(if (m == "fastgbm") "fastgbm" else "densemlp")
    sp <- if (m == "fastgbm") list(nrounds = 20, subsample = 0.5) else list(epochs = 5)
    p <- function(s) predict(fit(mpg ~ ., mtcars, model = m, spec = sp, seed = s), mtcars)
    expect_equal(p(1), p(1))
    expect_false(isTRUE(all.equal(p(1), p(2))))
    ps <- predict(fit(mpg ~ ., mtcars, model = m, spec = c(sp, seed = 7L), seed = 1), mtcars)
    expect_equal(ps, predict(fit(mpg ~ ., mtcars, model = m, spec = c(sp, seed = 7L), seed = 2), mtcars))
  }
})
