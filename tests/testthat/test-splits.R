test_that("splits() returns holdout indices that partition the rows", {
  s <- splits(holdout(prop = 0.75, seed = 1), mtcars)
  expect_s3_class(s, "funcml_cv")
  expect_length(s$train, floor(0.75 * nrow(mtcars)))
  expect_setequal(c(s$train, s$test), seq_len(nrow(mtcars)))
  expect_length(intersect(s$train, s$test), 0L)
  expect_identical(s$train, s$folds[[1]]$train)
})

test_that("splits() matches the folds evaluate() draws and is reused", {
  d <- iris
  d$Species <- factor(d$Species == "setosa")
  rs <- cv(4, seed = 11)
  s <- splits(rs, d, formula = Species ~ Sepal.Length)
  ev <- evaluate(d, Species ~ Sepal.Length, model = "glm", resampling = rs,
                 metrics = "accuracy")
  expect_identical(
    lapply(s$folds, `[[`, "test"),
    lapply(ev$resampling$folds, `[[`, "test")
  )
  ev2 <- evaluate(d, Species ~ Sepal.Length, model = "glm", resampling = s,
                  metrics = "accuracy")
  expect_identical(ev2$resampling$folds, s$folds)
  # stratified: each test fold keeps the class balance
  props <- vapply(s$folds, function(f) mean(d$Species[f$test] == "TRUE"), numeric(1))
  expect_true(all(abs(props - 1 / 3) < 0.05))
})

test_that("splits() checks its inputs", {
  expect_error(splits(list(), mtcars), "resampling")
  expect_error(splits(cv(3), mtcars, outcome = "nope"), "outcome")
})
