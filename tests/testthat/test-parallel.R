library(funcml)

test_that("evaluate matches sequential results when parallelized across folds", {
  seq_eval <- evaluate(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    model = "glm",
    metrics = c("rmse", "mae"),
    resampling = cv(v = 4, seed = 2),
    seed = 11
  )

  par_eval <- evaluate(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    model = "glm",
    metrics = c("rmse", "mae"),
    resampling = cv(v = 4, seed = 2),
    seed = 11,
    ncores = 2
  )

  expect_equal(par_eval$folds, seq_eval$folds)
  expect_equal(par_eval$summary, seq_eval$summary)
})

test_that("tune matches sequential results when parallelized across configs and outer folds", {
  skip_if_not_installed("rpart")

  grid <- expand.grid(
    cp = c(0.001, 0.01),
    minsplit = c(5, 10),
    stringsAsFactors = FALSE
  )

  seq_tune <- tune(
    data = mtcars,
    formula = mpg ~ wt + hp,
    model = "rpart",
    grid = grid,
    resampling = cv(v = 3, seed = 1),
    outer_resampling = cv(v = 4, seed = 2),
    metric = "rmse",
    seed = 7
  )

  par_tune <- tune(
    data = mtcars,
    formula = mpg ~ wt + hp,
    model = "rpart",
    grid = grid,
    resampling = cv(v = 3, seed = 1),
    outer_resampling = cv(v = 4, seed = 2),
    metric = "rmse",
    seed = 7,
    ncores = 2
  )

  expect_equal(par_tune$results, seq_tune$results)
  expect_equal(par_tune$best, seq_tune$best)
  expect_equal(par_tune$nested$folds, seq_tune$nested$folds)
  expect_equal(par_tune$nested$summary, seq_tune$nested$summary)
})

test_that("compare_learners matches sequential results when parallelized across models", {
  skip_if_not_installed("rpart")

  seq_cmp <- compare_learners(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    models = c("glm", "rpart"),
    metrics = c("rmse", "mae"),
    resampling = cv(v = 4, seed = 1),
    seed = 5
  )

  par_cmp <- compare_learners(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    models = c("glm", "rpart"),
    metrics = c("rmse", "mae"),
    resampling = cv(v = 4, seed = 1),
    seed = 5,
    ncores = 2
  )

  expect_equal(par_cmp$results, seq_cmp$results)
})

test_that("tuned compare_learners matches sequential results when parallelized across models", {
  skip_if_not_installed("rpart")
  skip_if_not_installed("glmnet")

  grids <- list(
    rpart = expand.grid(cp = c(0.001, 0.01), minsplit = c(5, 10), stringsAsFactors = FALSE),
    glmnet = expand.grid(alpha = c(0, 1), lambda = c(0.01, 0.1), stringsAsFactors = FALSE)
  )

  seq_cmp <- compare_learners(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    models = c("rpart", "glmnet"),
    tune = TRUE,
    metric = "rmse",
    metrics = c("rmse", "mae"),
    grids = grids,
    resampling = cv(v = 3, seed = 2),
    seed = 13
  )

  par_cmp <- compare_learners(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    models = c("rpart", "glmnet"),
    tune = TRUE,
    metric = "rmse",
    metrics = c("rmse", "mae"),
    grids = grids,
    resampling = cv(v = 3, seed = 2),
    seed = 13,
    ncores = 2
  )

  expect_equal(par_cmp$results, seq_cmp$results)
})

test_that("parallel ncores must be a positive integer when supplied", {
  expect_error(
    funcml:::`.validate_ncores`(0),
    "`ncores` must be NULL or a single positive integer"
  )
})

test_that("parallel tuning preserves the downstream workflow pipeline", {
  skip_if_not_installed("rpart")

  tune_grid <- expand.grid(
    cp = c(0.001, 0.01),
    minsplit = c(5, 10),
    stringsAsFactors = FALSE
  )

  tune_obj <- tune(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    model = "rpart",
    grid = tune_grid,
    resampling = cv(v = 3, seed = 1),
    metric = "rmse",
    seed = 19,
    ncores = 2
  )

  preds <- predict(tune_obj$fit_best, mtcars[1:5, , drop = FALSE])
  eval_obj <- evaluate(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    fit = tune_obj$fit_best,
    metrics = c("rmse", "mae"),
    resampling = cv(v = 3, seed = 3),
    seed = 23,
    ncores = 2
  )
  cmp_obj <- compare_learners(
    data = mtcars,
    formula = mpg ~ wt + hp + qsec,
    models = c("glm", "rpart"),
    metrics = c("rmse", "mae"),
    resampling = cv(v = 3, seed = 4),
    seed = 29,
    ncores = 2
  )

  expect_true(is.numeric(preds))
  expect_length(preds, 5)
  expect_s3_class(tune_obj$fit_best, "funcml_fit")
  expect_false("ncores" %in% names(tune_obj$fit_best$spec))
  expect_s3_class(eval_obj, "funcml_eval")
  expect_equal(sort(eval_obj$summary$metric), c("mae", "rmse"))
  expect_s3_class(cmp_obj, "funcml_compare")
})
