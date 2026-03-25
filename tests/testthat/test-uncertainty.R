library(funcml)

skip_if_not_installed <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    skip(paste("Package", pkg, "not installed"))
  }
}

test_that("evaluate reports fold-based uncertainty intervals", {
  ev <- evaluate(
    mtcars,
    mpg ~ wt + hp + qsec,
    model = "glm",
    resampling = cv(v = 4, seed = 1)
  )

  expect_s3_class(ev, "funcml_eval")
  expect_true(all(c("mean", "sd", "n", "std_error", "conf_level", "conf_low", "conf_high") %in% names(ev$summary)))
  expect_true(all(ev$summary$n == 4))
  expect_true(all(ev$summary$conf_level == 0.95))
  expect_true(all(ev$summary$conf_low <= ev$summary$mean))
  expect_true(all(ev$summary$conf_high >= ev$summary$mean))
})

test_that("compare_learners carries uncertainty columns through summaries", {
  skip_if_not_installed("rpart")

  cmp <- compare_learners(
    mtcars,
    mpg ~ wt + hp + qsec,
    models = c("glm", "rpart"),
    metrics = c("rmse", "mae"),
    resampling = cv(v = 4, seed = 1)
  )

  expect_s3_class(cmp, "funcml_compare")
  expect_true(all(c("n", "std_error", "conf_level", "conf_low", "conf_high") %in% names(cmp$results)))
  expect_true(all(cmp$results$n == 4))
  expect_s3_class(plot(cmp), "ggplot")
})

test_that("estimate supports bootstrap uncertainty intervals", {
  dat <- transform(mtcars, am = factor(am, levels = c(0, 1), labels = c("auto", "manual")))

  est <- estimate(
    dat,
    mpg ~ am + wt + hp,
    model = "glm",
    interval = "bootstrap",
    n_boot = 30,
    seed = 1
  )

  expect_s3_class(est, "funcml_estimand")
  expect_equal(est$interval_method, "bootstrap")
  expect_equal(est$conf_level, 0.95)
  expect_true(is.finite(est$conf_int[["lower"]]))
  expect_true(is.finite(est$conf_int[["upper"]]))
  expect_lte(est$conf_int[["lower"]], est$estimate)
  expect_gte(est$conf_int[["upper"]], est$estimate)
})
