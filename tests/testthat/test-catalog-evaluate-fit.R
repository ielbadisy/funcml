test_that("catalog lists all interpret() methods", {
  m <- sub('interpret\\(method = "(.*)"\\)', "\\1", listinterpretabilitymethods()$compute)
  expect_setequal(m, eval(formals(interpret)$method))
})

test_that("evaluate(fit = ) works without a formula", {
  f <- fit(mpg ~ wt + hp, mtcars, model = "glm")
  e <- evaluate(mtcars, fit = f, resampling = cv(3, seed = 1), metrics = "rmse")
  e2 <- evaluate(mtcars, mpg ~ wt + hp, model = "glm", resampling = cv(3, seed = 1), metrics = "rmse")
  expect_equal(e$summary$mean, e2$summary$mean)
})
