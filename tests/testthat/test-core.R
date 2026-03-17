library(funcml)

skip_if_not_installed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    skip(paste("Package", pkg, "not installed"))
  }
}

test_that("glm fit and predict works", {
  f <- fit(mpg ~ wt + cyl, data = mtcars, model = "glm")
  preds <- predict(f, mtcars[1:5, ])
  expect_true(is.numeric(preds))
  expect_length(preds, 5)
})

test_that("rpart fit/predict skips gracefully", {
  skip_if_not_installed("rpart")
  f <- fit(Species ~ ., data = iris, model = "rpart")
  preds <- predict(f, iris[1:4, ], type = "class")
  expect_s3_class(preds, "factor")
})

test_that("design matrix mismatch errors clearly", {
  train <- data.frame(y = c(1,2,3,4), x = factor(c("a","a","b","b")))
  f <- fit(y ~ x, data = train, model = "glm")
  newdata <- data.frame(x = factor("c"))
  expect_error(predict(f, newdata), "Design matrix mismatch")
})

test_that("cv folds have no overlap", {
  res <- funcml:::generate_folds(20, y = factor(rep(LETTERS[1:2], each = 10)), resampling = cv(v = 5, seed = 1))
  for (fold in res$folds) {
    expect_length(intersect(fold$train, fold$test), 0)
  }
})

test_that("metrics are sane", {
  truth <- c(1,2,3)
  expect_equal(rmse(truth, truth), 0)
  expect_equal(mae(truth, truth), 0)
  truth_cls <- factor(c("a","b","a","b"))
  prob <- matrix(c(0.9,0.1, 0.2,0.8, 0.8,0.2, 0.1,0.9), ncol = 2, byrow = TRUE)
  colnames(prob) <- levels(truth_cls) <- c("a","b")
  expect_equal(auc(truth_cls, prob[,2]), 1)
})

test_that("permutation importance ranks signal", {
  set.seed(1)
  n <- 60
  x1 <- rnorm(n)
  x2 <- rnorm(n)
  y <- x1 * 2 + rnorm(n, 0, 0.1)
  dat <- data.frame(y = y, x1 = x1, x2 = x2)
  f <- fit(y ~ x1 + x2, data = dat, model = "glm")
  vi <- interpret(f, dat, method = "permute", metric = "rmse", nsim = 4)
  imp <- vi$result$scores
  expect_gt(imp$importance[imp$feature == "x1"], imp$importance[imp$feature == "x2"])
})

test_that("learners include stacking and superlearner", {
  ids <- learners()
  expect_true(all(c("stacking", "superlearner") %in% ids))
})

test_that("stacking and superlearner support regression", {
  skip_if_not_installed("rpart")
  set.seed(31)
  dat <- data.frame(
    x1 = rnorm(80),
    x2 = rnorm(80)
  )
  dat$y <- 1.5 * dat$x1 - 0.7 * dat$x2 + rnorm(80, sd = 0.2)

  stack_fit <- fit(
    y ~ x1 + x2,
    data = dat,
    model = "stacking",
    spec = list(learners = c("glm", "rpart"))
  )
  sl_fit <- fit(
    y ~ x1 + x2,
    data = dat,
    model = "superlearner",
    spec = list(learners = c("glm", "rpart"), resampling = cv(4, seed = 9))
  )

  stack_pred <- predict(stack_fit, dat[1:6, , drop = FALSE])
  sl_pred <- predict(sl_fit, dat[1:6, , drop = FALSE])

  expect_true(is.numeric(stack_pred))
  expect_true(is.numeric(sl_pred))
  expect_length(stack_pred, 6)
  expect_length(sl_pred, 6)
})

test_that("stacking and superlearner support binary classification probabilities", {
  skip_if_not_installed("rpart")
  set.seed(32)
  dat <- data.frame(
    x1 = rnorm(90),
    x2 = rnorm(90)
  )
  eta <- 1.1 * dat$x1 - 0.9 * dat$x2
  dat$y <- factor(ifelse(runif(90) < stats::plogis(eta), "yes", "no"), levels = c("no", "yes"))

  stack_fit <- fit(
    y ~ x1 + x2,
    data = dat,
    model = "stacking",
    spec = list(learners = c("glm", "rpart"))
  )
  sl_fit <- fit(
    y ~ x1 + x2,
    data = dat,
    model = "superlearner",
    spec = list(learners = c("glm", "rpart"), resampling = cv(4, seed = 7))
  )

  stack_prob <- predict(stack_fit, dat[1:8, , drop = FALSE], type = "prob")
  sl_prob <- predict(sl_fit, dat[1:8, , drop = FALSE], type = "prob")
  stack_cls <- predict(stack_fit, dat[1:8, , drop = FALSE], type = "class")
  sl_cls <- predict(sl_fit, dat[1:8, , drop = FALSE], type = "class")

  expect_equal(dim(stack_prob), c(8, 2))
  expect_equal(dim(sl_prob), c(8, 2))
  expect_s3_class(stack_cls, "factor")
  expect_s3_class(sl_cls, "factor")
})
