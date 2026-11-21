test_that("gbm fits and predicts multiclass outcomes", {
  skip_if_not_installed("gbm")
  set.seed(1); i <- sample(150, 100)
  f <- fit(Species ~ ., iris[i, ], model = "gbm", spec = list(n.trees = 50), seed = 1)
  p <- predict(f, iris[-i, ], type = "prob")
  expect_equal(dim(p), c(50L, 3L)); expect_equal(colnames(p), levels(iris$Species))
  expect_equal(unname(rowSums(p)), rep(1, 50), tolerance = 1e-8)
  cl <- predict(f, iris[-i, ], type = "class")
  expect_identical(levels(cl), levels(iris$Species))
  expect_gt(mean(cl == iris$Species[-i]), 0.85)
  e <- evaluate(iris, Species ~ ., model = "gbm", spec = list(n.trees = 50),
                resampling = cv(3, seed = 1), metrics = c("accuracy", "logloss", "auc_weighted"))
  expect_true(all(is.finite(e$summary$mean)))
})
