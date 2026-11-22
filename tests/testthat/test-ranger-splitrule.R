test_that("ranger forwards splitrule and keeps the engine default otherwise", {
  skip_if_not_installed("ranger")
  op <- options(ranger.num.threads = 1); on.exit(options(op))
  d <- transform(mtcars, am = factor(am))
  sr <- function(...) fit(am ~ mpg + wt + hp, d, model = "ranger", seed = 1, ...)$state$state$splitrule
  expect_equal(sr(spec = list(num.trees = 20)), "gini")
  expect_equal(sr(spec = list(num.trees = 20, splitrule = "extratrees")), "extratrees")
  expect_equal(sr(spec = list(num.trees = 20, splitrule = "hellinger")), "hellinger")
  r <- fit(mpg ~ wt + hp, mtcars, model = "ranger", spec = list(num.trees = 20, splitrule = "extratrees"))
  expect_equal(r$state$state$splitrule, "extratrees")
  expect_length(predict(r, mtcars[1:3, ]), 3)
})
