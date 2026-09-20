library(funcml)

# Data with factor levels whose dummy-column names are not syntactic, in the style of
# age bands (`grp35-44`, `grp75+`), a binary outcome, and a noisy numeric signal.
make_special_names <- function(n = 240, seed = 7) {
  set.seed(seed)
  grp <- factor(sample(c("35-44", "45-54", "75+", "e f"), n, replace = TRUE))
  x1 <- stats::rnorm(n)
  x2 <- stats::runif(n)
  eta <- 1.2 * x1 + ifelse(grp == "75+", 1, -0.3)
  y <- factor(ifelse(stats::runif(n) < stats::plogis(eta), "yes", "no"), levels = c("no", "yes"))
  data.frame(y = y, grp = grp, x1 = x1, x2 = x2)
}

auc_of <- function(prob, y, positive) {
  r <- rank(prob)
  pos <- y == positive
  (sum(r[pos]) - sum(pos) * (sum(pos) + 1) / 2) / (sum(pos) * sum(!pos))
}

test_that("compare() keeps per-fold details when run on several cores", {
  skip_on_os("windows")
  cmp <- compare(
    data = mtcars, formula = mpg ~ wt + hp, models = c("glm", "rpart"),
    resampling = cv(3, seed = 1), metrics = c("rmse", "mae"), ncores = 2, seed = 1
  )
  expect_true(all(vapply(cmp$details, function(x) is.data.frame(x$folds) && nrow(x$folds) > 0L, logical(1))))
  seq_cmp <- compare(
    data = mtcars, formula = mpg ~ wt + hp, models = c("glm", "rpart"),
    resampling = cv(3, seed = 1), metrics = c("rmse", "mae"), ncores = 1, seed = 1
  )
  expect_equal(cmp$results, seq_cmp$results)
})

test_that("default glmnet is not an intercept-only model", {
  skip_if_not_installed("glmnet")
  d <- transform(mtcars, am = factor(am))
  fit_g <- fit(am ~ wt + hp + mpg, d, "glmnet")
  prob <- predict(fit_g, d, type = "prob")
  expect_gt(stats::sd(prob[, 2]), 0.05)
  expect_gt(auc_of(prob[, 2], d$am, "1"), 0.8)
})

test_that("glmnet with a given lambda fits along a path and does not return an empty model", {
  skip_if_not_installed("glmnet")
  set.seed(3)
  n <- 3000
  d <- data.frame(matrix(stats::rnorm(n * 40), n, 40))
  d$y <- factor(ifelse(stats::runif(n) < stats::plogis(d$X1 - d$X2 + 0.5 * d$X3), "yes", "no"), levels = c("no", "yes"))
  fit_g <- fit(y ~ ., d, "glmnet", spec = list(alpha = 0, lambda = 1e-4))
  path <- fit_g$state$state$lambda
  expect_gt(length(path), 1L)
  expect_true(any(abs(path - 1e-4) < 1e-12))
  prob <- predict(fit_g, d, type = "prob")
  expect_gt(stats::sd(prob[, 2]), 0.05)
})

test_that("glmnet accepts a single predictor", {
  skip_if_not_installed("glmnet")
  fit_g <- fit(mpg ~ wt, mtcars, "glmnet")
  pred <- predict(fit_g, mtcars)
  expect_length(pred, nrow(mtcars))
  expect_gt(stats::cor(pred, mtcars$mpg), 0.7)
})

test_that("gam handles non-syntactic dummy names and low-cardinality predictors", {
  skip_if_not_installed("mgcv")
  d <- make_special_names()
  fit_g <- fit(y ~ ., d, "gam")
  prob <- predict(fit_g, d[1:30, ], type = "prob")
  expect_equal(dim(prob), c(30L, 2L))
  expect_false(anyNA(prob))
  # binary and few-valued numeric predictors enter linearly instead of failing
  fit_c <- fit(mpg ~ cyl + gear + am + wt, mtcars, "gam")
  expect_length(predict(fit_c, mtcars), nrow(mtcars))
})

test_that("randomForest predicts with non-syntactic dummy names", {
  skip_if_not_installed("randomForest")
  d <- make_special_names()
  fit_r <- fit(y ~ ., d[1:180, ], "randomForest")
  prob <- predict(fit_r, d[181:240, ], type = "prob")
  expect_equal(dim(prob), c(60L, 2L))
  expect_false(anyNA(prob))
})

test_that("adaboost handles non-syntactic names and keeps the class order", {
  skip_if_not_installed("ada")
  d <- make_special_names()
  fit_a <- fit(y ~ ., d, "adaboost")
  prob <- predict(fit_a, d, type = "prob")
  expect_equal(colnames(prob), levels(d$y))
  expect_gt(auc_of(prob[, "yes"], d$y, "yes"), 0.7)
  # levels whose sorted order differs from the factor order must not swap the columns
  d2 <- d
  d2$y <- factor(ifelse(d$y == "yes", "b_case", "a_control"), levels = c("b_case", "a_control"))
  fit_b <- fit(y ~ ., d2, "adaboost")
  prob_b <- predict(fit_b, d2, type = "prob")
  expect_equal(colnames(prob_b), levels(d2$y))
  expect_gt(auc_of(prob_b[, "b_case"], d2$y, "b_case"), 0.7)
})

test_that("ensemble default base learners exclude glm for a multiclass outcome", {
  multi <- funcml:::.ensemble_default_learners("classification", levels = c("a", "b", "c"))
  binary <- funcml:::.ensemble_default_learners("classification", levels = c("a", "b"))
  expect_false("glm" %in% multi)
  expect_true("glm" %in% binary)
  expect_true(length(multi) >= 2L)
})

test_that("stacking and superlearner run on a multiclass outcome", {
  d <- iris
  names(d)[5] <- "y"
  # explicit base learners without a torch dependency, so the test runs where torch is not installed
  for (id in c("stacking", "superlearner")) {
    fit_e <- fit(y ~ ., d, id, spec = list(learners = c("rpart", "kknn")))
    prob <- predict(fit_e, d[c(1, 51, 101), ], type = "prob")
    expect_equal(dim(prob), c(3L, 3L))
    expect_equal(unname(rowSums(prob)), rep(1, 3), tolerance = 1e-6)
  }
})

test_that("default_tune_grid() returns grids, and NULL for learners without hyperparameters", {
  g <- default_tune_grid("rpart")
  expect_s3_class(g, "data.frame")
  expect_gt(nrow(g), 1L)
  expect_true(all(c("cp", "minsplit") %in% names(g)))
  g_rf <- default_tune_grid("ranger", data = mtcars, formula = mpg ~ .)
  expect_true(all(g_rf$mtry >= 1L & g_rf$mtry <= 10L))
  for (id in c("glm", "lda", "qda", "fda", "stacking", "superlearner")) {
    expect_null(default_tune_grid(id))
  }
  expect_error(default_tune_grid("not_a_learner"), "Unknown learner")
})

test_that("tune() and compare(tune = TRUE) work without a grid", {
  tn <- tune(mtcars, mpg ~ wt + hp, "rpart", resampling = cv(3, seed = 1), metric = "rmse")
  expect_s3_class(tn, "funcml_tune")
  expect_error(
    tune(mtcars, mpg ~ wt + hp, "glm", resampling = cv(3, seed = 1), metric = "rmse"),
    "no tunable hyperparameters"
  )
  cmp <- compare(
    data = mtcars, formula = mpg ~ wt + hp, models = c("rpart", "glm"),
    resampling = cv(3, seed = 1), metrics = "rmse", tune = TRUE, metric = "rmse", seed = 1
  )
  expect_setequal(cmp$results$model, c("rpart", "glm"))
  expect_true(cmp$results$tuned[cmp$results$model == "rpart"])
  expect_false(cmp$results$tuned[cmp$results$model == "glm"])
  # a grid supplied for one learner is used, the other falls back to its default grid
  cmp2 <- compare(
    data = mtcars, formula = mpg ~ wt + hp, models = c("rpart", "kknn"),
    resampling = cv(3, seed = 1), metrics = "rmse", tune = TRUE, metric = "rmse",
    grids = list(rpart = data.frame(cp = c(0.01, 0.05))), seed = 1
  )
  expect_setequal(cmp2$results$model, c("rpart", "kknn"))
})
