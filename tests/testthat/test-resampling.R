library(funcml)

test_that("holdout creates one disjoint split", {
  res <- funcml:::generate_folds(
    20,
    y = factor(rep(c("a", "b"), each = 10)),
    resampling = holdout(prop = 0.7, seed = 1)
  )

  expect_length(res$folds, 1)
  fold <- res$folds[[1]]
  expect_length(intersect(fold$train, fold$test), 0)
  expect_equal(sort(c(fold$train, fold$test)), 1:20)
  expect_true(length(fold$train) > length(fold$test))
})

test_that("grouped CV keeps groups intact across train and test", {
  dat <- data.frame(
    y = rnorm(12),
    x = rnorm(12),
    grp = rep(letters[1:4], each = 3)
  )

  res <- funcml:::generate_folds(
    n = nrow(dat),
    resampling = group_cv(v = 2, group = "grp", seed = 1),
    data = dat
  )

  expect_length(res$folds, 2)
  for (fold in res$folds) {
    train_groups <- unique(dat$grp[fold$train])
    test_groups <- unique(dat$grp[fold$test])
    expect_length(intersect(train_groups, test_groups), 0)
  }
})

test_that("time-aware CV respects ordering and evaluates end to end", {
  dat <- data.frame(
    y = seq_len(12) + rnorm(12, sd = 0.01),
    x = seq_len(12),
    t = seq.Date(as.Date("2024-01-01"), by = "day", length.out = 12)
  )

  res <- funcml:::generate_folds(
    n = nrow(dat),
    resampling = time_cv(initial = 6, assess = 2, time = "t"),
    data = dat
  )

  expect_true(length(res$folds) >= 2)
  for (fold in res$folds) {
    expect_true(max(fold$train) < min(fold$test))
  }

  ev <- evaluate(
    dat,
    y ~ x,
    model = "glm",
    resampling = time_cv(initial = 6, assess = 2, time = "t")
  )

  expect_s3_class(ev, "funcml_eval")
  expect_true(all(c("rmse", "mae", "mse", "medae", "mape", "rsq") %in% ev$summary$metric))
})
