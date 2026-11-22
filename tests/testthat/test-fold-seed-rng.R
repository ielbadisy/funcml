test_that("a fold seed does not reset the caller's random stream", {
  set.seed(7); a <- runif(1); set.seed(7)
  generate_folds(50, resampling = cv(5, seed = 1)); expect_equal(runif(1), a)
})

test_that("superlearner bootstrap replicates differ in estimate()", {
  d <- data.frame(x = rnorm(120), a = factor(sample(c("No", "Yes"), 120, TRUE)))
  d$y <- d$x + (d$a == "Yes") + rnorm(120)
  e <- estimate(d, y ~ a + x, model = "superlearner", treatment = "a", n_boot = 20, seed = 1,
    spec = list(learners = c("glm", "rpart")))
  expect_gt(e$std_error, 0)
})
