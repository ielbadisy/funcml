test_that("binary brier equals the standard mean((p - y)^2)", {
  y <- factor(c("no", "yes", "yes", "no"), levels = c("no", "yes"))
  p <- cbind(no = c(0.8, 0.2, 0.6, 0.7), yes = c(0.2, 0.8, 0.4, 0.3))
  expect_equal(brier(y, p), mean((p[, "yes"] - (y == "yes"))^2))

  y3 <- factor(c("a", "b", "c"), levels = c("a", "b", "c"))
  p3 <- rbind(c(0.7, 0.2, 0.1), c(0.1, 0.8, 0.1), c(0.2, 0.2, 0.6))
  colnames(p3) <- levels(y3)
  onehot <- diag(3)
  expect_equal(brier(y3, p3), mean(rowSums((p3 - onehot)^2)))
})

test_that("evaluate() names the model columns that contain NA", {
  d <- mtcars
  d$wt[3] <- NA
  expect_error(
    evaluate(d, mpg ~ wt + hp, model = "glm", resampling = cv(3, seed = 1), metrics = "rmse"),
    "missing values.*'wt'"
  )
})

test_that("time_cv never puts the same time value in train and test", {
  td <- data.frame(t = rep(1:10, each = 3))
  res <- funcml:::generate_folds(30, resampling = time_cv(initial = 5, assess = 2, time = "t"), data = td)
  expect_true(length(res$folds) >= 1L)
  for (f in res$folds) {
    expect_length(intersect(td$t[f$train], td$t[f$test]), 0L)
    expect_true(max(td$t[f$train]) < min(td$t[f$test]))
  }
  expect_equal(sort(unique(td$t[res$folds[[1]]$train])), 1:5)
  expect_equal(sort(unique(td$t[res$folds[[1]]$test])), 6:7)
})

test_that("evaluate() offers a Nadeau-Bengio corrected standard error", {
  ev_n <- evaluate(mtcars, mpg ~ wt, model = "glm", resampling = cv(5, seed = 1), metrics = "rmse")
  ev_c <- evaluate(mtcars, mpg ~ wt, model = "glm", resampling = cv(5, seed = 1), metrics = "rmse",
                   se_method = "corrected")
  sd_val <- ev_n$summary$sd
  ratio <- funcml:::.test_train_ratio(ev_c$resampling$folds)
  expect_equal(ev_c$summary$std_error, sqrt((1 / 5 + ratio) * sd_val^2))
  expect_true(ev_c$summary$std_error > ev_n$summary$std_error)
  expect_output(print(ev_n), "too narrow")
})

test_that("binary PDP defaults to the positive (second) level", {
  set.seed(1)
  dd <- data.frame(x = rnorm(200))
  dd$y <- factor(ifelse(runif(200) < stats::plogis(2 * dd$x), "yes", "no"), levels = c("no", "yes"))
  fo <- fit(y ~ x, dd, "glm")
  pd <- interpret(fo, dd, method = "pdp", features = "x")
  pd_yes <- interpret(fo, dd, method = "pdp", features = "x", class_level = "yes")
  expect_equal(pd$result$curves$yhat, pd_yes$result$curves$yhat)
  expect_true(cor(pd$result$curves$value, pd$result$curves$yhat) > 0)
})
