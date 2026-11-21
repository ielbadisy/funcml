test_that("tied probabilities give the same class whatever the RNG state", {
  d <- data.frame(y = factor(rep(c("a", "b"), each = 20)), x = rep(c(0, 1), 20))
  e1 <- evaluate(d, y ~ x, model = "rpart", metrics = "accuracy",
                 resampling = cv(4, seed = 1), seed = 1, spec = list(maxdepth = 1))
  set.seed(99); r <- runif(10)
  e2 <- evaluate(d, y ~ x, model = "rpart", metrics = "accuracy",
                 resampling = cv(4, seed = 1), spec = list(maxdepth = 1))
  expect_equal(e1$folds$value, e2$folds$value)
  expect_true(all(e1$predictions$.pred_class == "a"))
})
