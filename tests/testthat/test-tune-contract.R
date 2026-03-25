library(funcml)

test_that("tune supports random search with an evaluation budget", {
  grid <- expand.grid(
    intercept = c(TRUE, FALSE),
    stringsAsFactors = FALSE
  )

  tr <- tune(
    mtcars,
    mpg ~ wt + hp,
    model = "glm",
    grid = grid,
    search = "random",
    n_evals = 1,
    resampling = cv(v = 3, seed = 1),
    seed = 1
  )

  expect_s3_class(tr, "funcml_tune")
  expect_equal(tr$search, "random")
  expect_equal(tr$n_evals, 1)
  expect_equal(tr$candidates, nrow(grid))
  expect_equal(nrow(tr$results), 1)
  expect_true(all(c("mean", "sd", "conf_low", "conf_high") %in% names(tr$results)))
  expect_s3_class(plot(tr), "ggplot")
})

test_that("predict errors clearly for missing required columns", {
  fit_obj <- fit(mpg ~ wt + hp, data = mtcars, model = "glm")
  expect_error(
    predict(fit_obj, data.frame(wt = mtcars$wt[1:3])),
    "missing required columns: hp"
  )
})

test_that("predict errors clearly for unseen factor levels", {
  train <- data.frame(y = c(1, 2, 3, 4), x = factor(c("a", "a", "b", "b")))
  fit_obj <- fit(y ~ x, data = train, model = "glm")
  newdata <- data.frame(x = factor("c"))

  expect_error(
    predict(fit_obj, newdata),
    "Unseen factor levels in `x`: c"
  )
})

test_that("probability outputs are normalized to package conventions", {
  prob <- funcml:::`.normalize_prob_matrix`(
    matrix(c(2, 1, 1, 3), ncol = 2, byrow = TRUE),
    levels = c("no", "yes")
  )

  expect_equal(dim(prob), c(2, 2))
  expect_equal(rowSums(prob), c(1, 1))
  expect_equal(colnames(prob), c("no", "yes"))
})
