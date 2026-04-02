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
  expect_error(predict(f, newdata), "Unseen factor levels in `x`")
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
  expect_equal(mse(truth, truth), 0)
  expect_equal(medae(truth, truth), 0)
  expect_equal(mape(truth, truth), 0)
  truth_cls <- factor(c("a","b","a","b"))
  pred_cls <- factor(c("a", "b", "b", "b"), levels = levels(truth_cls))
  prob <- matrix(c(0.9,0.1, 0.2,0.8, 0.8,0.2, 0.1,0.9), ncol = 2, byrow = TRUE)
  colnames(prob) <- levels(truth_cls) <- c("a","b")
  expect_equal(auc(truth_cls, prob[,2]), 1)
  expect_equal(accuracy(truth_cls, pred_cls), 0.75)
  expect_equal(precision(truth_cls, pred_cls), 5 / 6)
  expect_equal(recall(truth_cls, pred_cls), 0.75)
  expect_equal(specificity(truth_cls, pred_cls), 0.75)
  expect_equal(f1(truth_cls, pred_cls), 0.7894737, tolerance = 1e-7)
  expect_equal(balanced_accuracy(truth_cls, pred_cls), 0.75)
  curve <- calibration_curve(truth_cls, prob[, 2], bins = 2, strategy = "uniform")
  expect_equal(nrow(curve), 2)
  expect_true(is.finite(ece(truth_cls, prob[, 2], bins = 2, strategy = "uniform")))
  expect_true(is.finite(mce(truth_cls, prob[, 2], bins = 2, strategy = "uniform")))
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

test_that("learners include newly added backends", {
  ids <- learners()
  expect_true(all(c("fda", "adaboost", "pls", "ctree", "cforest", "gam", "naivebayes", "bart") %in% ids))
})

test_that("new learner task support is registered correctly", {
  expect_equal(sort(funcml:::funcml_registry("gam")$tasks), c("classification", "regression"))
  expect_equal(sort(funcml:::funcml_registry("bart")$tasks), c("classification", "regression"))
  expect_equal(sort(funcml:::funcml_registry("ctree")$tasks), c("classification", "regression"))
  expect_equal(sort(funcml:::funcml_registry("cforest")$tasks), c("classification", "regression"))
  expect_equal(funcml:::funcml_registry("pls")$tasks, "regression")
  expect_equal(funcml:::funcml_registry("naivebayes")$tasks, "classification")
  expect_equal(funcml:::funcml_registry("fda")$tasks, "classification")
  expect_equal(funcml:::funcml_registry("adaboost")$tasks, "classification")
})

test_that("gam fit and predict works for regression", {
  skip_if_not_installed("mgcv")
  f <- fit(mpg ~ wt + hp, data = mtcars, model = "gam")
  preds <- predict(f, mtcars[1:5, , drop = FALSE])
  expect_true(is.numeric(preds))
  expect_length(preds, 5)
})

test_that("gam supports binary classification probabilities and rejects multiclass", {
  skip_if_not_installed("mgcv")

  iris_bin <- subset(iris, Species != "setosa")
  iris_bin$Species <- droplevels(iris_bin$Species)
  gam_fit <- fit(Species ~ Sepal.Length + Sepal.Width + Petal.Length + Petal.Width, data = iris_bin, model = "gam")
  gam_prob <- predict(gam_fit, iris_bin[1:4, , drop = FALSE], type = "prob")
  expect_equal(dim(gam_prob), c(4, 2))

  expect_error(
    fit(Species ~ ., data = iris, model = "gam"),
    "does not support multiclass classification|supports only binary classification"
  )
})

test_that("ctree and cforest support classification probabilities", {
  skip_if_not_installed("partykit")

  ctree_fit <- fit(Species ~ ., data = iris, model = "ctree")
  cforest_fit <- fit(Species ~ ., data = iris, model = "cforest", spec = list(ntree = 50))

  ctree_prob <- predict(ctree_fit, iris[1:4, , drop = FALSE], type = "prob")
  cforest_prob <- predict(cforest_fit, iris[1:4, , drop = FALSE], type = "prob")

  expect_equal(dim(ctree_prob), c(4, 3))
  expect_equal(dim(cforest_prob), c(4, 3))
})

test_that("ctree and cforest support regression predictions", {
  skip_if_not_installed("partykit")

  ctree_fit <- fit(mpg ~ wt + hp, data = mtcars, model = "ctree")
  cforest_fit <- fit(mpg ~ wt + hp, data = mtcars, model = "cforest", spec = list(ntree = 50))

  ctree_pred <- predict(ctree_fit, mtcars[1:4, , drop = FALSE])
  cforest_pred <- predict(cforest_fit, mtcars[1:4, , drop = FALSE])

  expect_true(is.numeric(ctree_pred))
  expect_true(is.numeric(cforest_pred))
  expect_length(ctree_pred, 4)
  expect_length(cforest_pred, 4)
})

test_that("bart supports regression and binary classification probabilities", {
  skip_if_not_installed("dbarts")

  set.seed(41)
  reg_dat <- data.frame(x1 = rnorm(60), x2 = rnorm(60))
  reg_dat$y <- reg_dat$x1 - 0.5 * reg_dat$x2 + rnorm(60, sd = 0.2)
  reg_fit <- fit(y ~ x1 + x2, data = reg_dat, model = "bart", spec = list(ndpost = 20, nskip = 5))
  reg_pred <- predict(reg_fit, reg_dat[1:5, , drop = FALSE])
  expect_true(is.numeric(reg_pred))
  expect_length(reg_pred, 5)

  cls_dat <- data.frame(x1 = rnorm(70), x2 = rnorm(70))
  eta <- cls_dat$x1 - 0.8 * cls_dat$x2
  cls_dat$y <- factor(ifelse(runif(70) < stats::plogis(eta), "yes", "no"), levels = c("no", "yes"))
  cls_fit <- fit(y ~ x1 + x2, data = cls_dat, model = "bart", spec = list(ndpost = 20, nskip = 5))
  cls_prob <- predict(cls_fit, cls_dat[1:6, , drop = FALSE], type = "prob")
  expect_equal(dim(cls_prob), c(6, 2))
})

test_that("bart rejects multiclass classification", {
  skip_if_not_installed("dbarts")
  expect_error(
    fit(Species ~ ., data = iris, model = "bart", spec = list(ndpost = 20, nskip = 5)),
    "does not support multiclass classification|supports only binary classification"
  )
})

test_that("gbm rejects multiclass classification", {
  skip_if_not_installed("gbm")
  expect_error(
    fit(Species ~ ., data = iris, model = "gbm", spec = list(n.trees = 20, interaction.depth = 2)),
    "does not support multiclass classification"
  )
})

test_that("regression-only and classification-only learners reject unsupported tasks", {
  expect_error(
    fit(Species ~ ., data = iris, model = "pls"),
    "does not support classification"
  )
  expect_error(
    fit(mpg ~ wt + hp, data = mtcars, model = "naivebayes"),
    "does not support regression"
  )
  expect_error(
    fit(mpg ~ wt + hp, data = mtcars, model = "fda"),
    "does not support regression"
  )
  expect_error(
    fit(mpg ~ wt + hp, data = mtcars, model = "adaboost"),
    "does not support regression"
  )
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

test_that("xgboost supports regression and classification", {
  skip_if_not_installed("xgboost")

  reg_fit <- fit(
    mpg ~ wt + hp + qsec,
    data = mtcars,
    model = "xgboost",
    spec = list(nrounds = 20, max_depth = 3, eta = 0.1)
  )
  reg_pred <- predict(reg_fit, mtcars[1:5, , drop = FALSE])
  expect_true(is.numeric(reg_pred))
  expect_length(reg_pred, 5)

  iris_bin <- subset(iris, Species != "setosa")
  iris_bin$Species <- droplevels(iris_bin$Species)
  cls_fit <- fit(
    Species ~ Sepal.Length + Sepal.Width + Petal.Length + Petal.Width,
    data = iris_bin,
    model = "xgboost",
    spec = list(nrounds = 20, max_depth = 3, eta = 0.1)
  )
  cls_prob <- predict(cls_fit, iris_bin[1:4, , drop = FALSE], type = "prob")
  cls_pred <- predict(cls_fit, iris_bin[1:4, , drop = FALSE], type = "class")
  expect_equal(dim(cls_prob), c(4, 2))
  expect_s3_class(cls_pred, "factor")
})

test_that("xgboost and lightgbm reconstruct multiclass probabilities column-wise", {
  skip_if_not_installed("xgboost")
  skip_if_not_installed("lightgbm")

  set.seed(99)
  x1 <- c(rnorm(40, -3, 0.6), rnorm(40, 0, 0.6), rnorm(40, 3, 0.6))
  x2 <- c(rnorm(40, -3, 0.6), rnorm(40, 3, 0.6), rnorm(40, 0, 0.6))
  dat <- data.frame(
    Activity = factor(rep(c("A", "B", "C"), each = 40), levels = c("A", "B", "C")),
    x1 = x1,
    x2 = x2
  )

  fit_xgb <- fit(
    Activity ~ .,
    data = dat,
    model = "xgboost",
    spec = list(nrounds = 100, max_depth = 4, eta = 0.1, subsample = 1, colsample_bytree = 1),
    seed = 1
  )
  prob_xgb <- predict(fit_xgb, newdata = dat, type = "prob")
  pred_xgb <- predict(fit_xgb, newdata = dat, type = "class")

  expect_identical(colnames(prob_xgb), levels(dat$Activity))
  expect_true(all(abs(rowSums(prob_xgb) - 1) < 1e-6))
  expect_gt(mean(pred_xgb == dat$Activity), 0.95)

  fit_lgb <- fit(
    Activity ~ .,
    data = dat,
    model = "lightgbm",
    spec = list(
      nrounds = 100,
      num_leaves = 31,
      learning_rate = 0.05,
      feature_fraction = 1,
      bagging_fraction = 1,
      bagging_freq = 0,
      max_depth = -1
    ),
    seed = 1
  )
  prob_lgb <- predict(fit_lgb, newdata = dat, type = "prob")
  pred_lgb <- predict(fit_lgb, newdata = dat, type = "class")

  expect_identical(colnames(prob_lgb), levels(dat$Activity))
  expect_true(all(abs(rowSums(prob_lgb) - 1) < 1e-6))
  expect_gt(mean(pred_lgb == dat$Activity), 0.95)
})

test_that("compare_learners compares multiple models across metrics", {
  skip_if_not_installed("rpart")

  cmp <- compare_learners(
    mtcars,
    mpg ~ wt + hp + qsec,
    models = c("glm", "rpart"),
    metrics = c("rmse", "mae"),
    resampling = cv(v = 4, seed = 1)
  )

  expect_s3_class(cmp, "funcml_compare")
  expect_equal(sort(unique(cmp$results$model)), c("glm", "rpart"))
  expect_equal(sort(unique(cmp$results$metric)), c("mae", "rmse"))
  expect_true(all(c("model", "metric", "mean", "sd", "tuned", "rank") %in% names(cmp$results)))
  expect_s3_class(plot(cmp), "ggplot")
})

test_that("compare_learners supports tuned comparisons with multiple reported metrics", {
  skip_if_not_installed("rpart")
  skip_if_not_installed("xgboost")

  cmp <- compare_learners(
    mtcars,
    mpg ~ wt + hp + qsec,
    models = c("rpart", "xgboost"),
    tune = TRUE,
    metric = "rmse",
    metrics = c("rmse", "mae"),
    grids = list(
      rpart = expand.grid(cp = c(0.001, 0.01), minsplit = c(5, 10)),
      xgboost = expand.grid(max_depth = c(2, 3), eta = c(0.05, 0.1), nrounds = c(10, 20))
    ),
    resampling = cv(v = 3, seed = 2),
    subsample = 1,
    colsample_bytree = 1
  )

  expect_s3_class(cmp, "funcml_compare")
  expect_true(all(cmp$results$tuned))
  expect_equal(sort(unique(cmp$results$model)), c("rpart", "xgboost"))
  expect_equal(sort(unique(cmp$results$metric)), c("mae", "rmse"))
  expect_true(all(c("best_spec", "opt_metric") %in% names(cmp$results)))
})
