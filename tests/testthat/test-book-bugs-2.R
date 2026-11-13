test_that("compare() shares the same folds across learners with default cv()", {
  cmp <- compare(mtcars, mpg ~ wt + hp, models = c("glm", "rpart"),
                 resampling = cv(4), metrics = "rmse", seed = 11)
  f1 <- cmp$details$glm$resampling$folds
  f2 <- cmp$details$rpart$resampling$folds
  expect_identical(lapply(f1, `[[`, "test"), lapply(f2, `[[`, "test"))
  expect_identical(lapply(f1, `[[`, "test"), lapply(cmp$resampling$folds, `[[`, "test"))
  cmp2 <- compare(mtcars, mpg ~ wt + hp, models = c("glm", "rpart"),
                  resampling = cv(4), metrics = "rmse", seed = 11)
  expect_equal(cmp$results$mean, cmp2$results$mean)
})

test_that("compare() returns out-of-fold predictions on shared rows", {
  d <- mtcars
  d$am <- factor(d$am, labels = c("no", "yes"))
  cmp <- compare(d, am ~ qsec, models = c("glm", "rpart"),
                 resampling = cv(3), metrics = c("auc", "brier"), seed = 2)
  p <- cmp$predictions
  expect_true(all(c("model", "row", "fold", "truth", ".pred_class", ".prob_no", ".prob_yes") %in% names(p)))
  expect_equal(nrow(p), 2L * nrow(d))
  expect_identical(p$row[p$model == "glm"], p$row[p$model == "rpart"])
  expect_true(all(p$truth == d$am[p$row]))
})

test_that("compare(tune = TRUE) uses nested resampling by default", {
  grid <- data.frame(cp = c(0.001, 0.05, 0.2), minsplit = 5)
  cmp <- compare(mtcars, mpg ~ wt + hp + qsec, models = "rpart",
                 resampling = cv(3), metrics = "rmse", seed = 3,
                 tune = TRUE, grids = list(rpart = grid))
  expect_true(cmp$nested)
  expect_true(isTRUE(cmp$details$rpart$evaluate$nested))
  expect_equal(nrow(cmp$details$rpart$selected_specs), 3L)
  expect_equal(nrow(cmp$predictions), nrow(mtcars))
  flat <- compare(mtcars, mpg ~ wt + hp + qsec, models = "rpart",
                  resampling = cv(3), metrics = "rmse", seed = 3,
                  tune = TRUE, grids = list(rpart = grid), nested = FALSE)
  expect_false(flat$nested)
  # The non-nested estimate is the minimum over the grid on the same folds,
  # so it is never worse than the corresponding tune() result.
  expect_equal(flat$results$mean, min(flat$details$rpart$tune$results$mean))
})

test_that("evaluate(pooled = TRUE) gives pooled out-of-fold metrics", {
  set.seed(1)
  n <- 300
  d <- data.frame(x = rnorm(n))
  d$y <- factor(ifelse(runif(n) < plogis(d$x), "yes", "no"))
  ev <- evaluate(d, y ~ x, model = "glm", resampling = cv(5, seed = 1),
                 metrics = c("ece", "brier"), pooled = TRUE)
  expect_true(is.data.frame(ev$pooled))
  p <- ev$predictions
  expect_equal(ev$pooled$value[ev$pooled$metric == "ece"], ece(p$truth, p$.prob_yes))
  expect_equal(ev$pooled$value[ev$pooled$metric == "brier"],
               mean((p$.prob_yes - (p$truth == "yes"))^2))
  expect_lt(ev$pooled$value[1], ev$summary$mean[ev$summary$metric == "ece"])
  expect_null(evaluate(d, y ~ x, model = "glm", resampling = cv(3, seed = 1), metrics = "brier")$pooled)
})

test_that("fastgbm accepts NA predictors natively and permutation importance stays aligned", {
  skip_if_not_installed("fastgbm")
  set.seed(4)
  n <- 200
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  d$y <- 3 * d$x1 + d$x2 + rnorm(n, sd = 0.3)
  d$x1[sample(n, 20)] <- NA
  d$x3[sample(n, 20)] <- NA
  f <- fit(y ~ x1 + x2 + x3, d, "fastgbm", ntrees = 50L, threads = 1L)
  expect_equal(f$n, n)
  expect_length(predict(f, d), n)
  expect_s3_class(enginemodel(f), "fastgbm")
  expect_error(fit(y ~ x1 + x2 + x3, d, "fastgbm", na_action = stats::na.fail))
  imp <- expect_silent(interpret(f, data = d, method = "permute", nsim = 5, seed = 1))
  vi <- imp$result$scores
  expect_equal(vi$feature[1], "x1")
  expect_gt(vi$importance[vi$feature == "x1"], 0)
  ev <- evaluate(d, y ~ x1 + x2 + x3, model = "fastgbm", resampling = cv(3, seed = 1),
                 metrics = "rmse", ntrees = 50L, threads = 1L)
  expect_true(is.finite(ev$summary$mean))
  d$y[1] <- NA
  expect_error(fit(y ~ x1 + x2 + x3, d, "fastgbm"), "outcome")
})

test_that("enginemodel() returns the stored engine object", {
  f <- fit(mpg ~ wt, mtcars, "glm")
  expect_s3_class(enginemodel(f), "glm")
  expect_error(enginemodel(list()), "funcml_fit")
})
