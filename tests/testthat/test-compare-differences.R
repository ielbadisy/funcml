test_that("compare() paired differences use the Nadeau-Bengio corrected t", {
  cmp <- compare(mtcars, mpg ~ wt + hp, models = c("glm", "rpart"), metrics = c("rmse", "mae"),
                 resampling = cv(4, repeats = 3, seed = 1), se_method = "corrected")
  d <- with(cmp$details, rpart$folds$value - glm$folds$value)[cmp$details$glm$folds$metric == "rmse"]
  J <- length(d); r <- 1 / 3
  se <- sd(d) * sqrt(1 / J + r)
  dr <- cmp$differences[cmp$differences$metric == "rmse", ]
  expect_equal(dr$model, "rpart"); expect_equal(dr$reference, "glm")
  expect_equal(dr$difference, mean(d)); expect_equal(dr$std_error, se)
  expect_equal(dr$p_value, 2 * pt(-abs(mean(d) / se), J - 1))
  r1 <- cmp$results[cmp$results$model == "glm" & cmp$results$metric == "rmse", ]
  g <- cmp$details$glm$folds
  expect_equal(r1$std_error, sd(g$value[g$metric == "rmse"]) * sqrt(1 / 12 + r))
  expect_output(print(cmp), "Nadeau-Bengio")
  cmp2 <- compare(mtcars, mpg ~ wt, models = c("glm", "rpart"), metrics = "rmse",
                  resampling = cv(3, seed = 1), reference = "rpart")
  expect_equal(cmp2$differences$model, "glm")
  expect_error(compare(mtcars, mpg ~ wt, models = "glm", reference = "x"), "reference")
})

test_that("tune() accepts se_method = 'corrected'", {
  t1 <- tune(mtcars, mpg ~ wt + hp, model = "rpart", grid = data.frame(cp = c(0.01, 0.1)),
             resampling = cv(4, seed = 1), se_method = "corrected")
  t0 <- tune(mtcars, mpg ~ wt + hp, model = "rpart", grid = data.frame(cp = c(0.01, 0.1)),
             resampling = cv(4, seed = 1))
  expect_equal(t1$results$mean, t0$results$mean)
  expect_equal(t1$results$std_error, t0$results$std_error * sqrt(1 + 4 * 1 / 3))
})
