test_that("convex meta-learner solves the simplex-constrained least squares problem", {
  skip_if_not_installed("quadprog")
  set.seed(1); n <- 300
  Z <- cbind(a = rnorm(n), b = rnorm(n), c = rnorm(n)); y <- drop(Z %*% c(.7, .3, -.5)) + rnorm(n)
  w <- funcml:::.ensemble_fit_meta(Z, y, "regression", meta_model = "convex")$weights
  qp <- quadprog::solve.QP(crossprod(Z), crossprod(Z, y), cbind(1, diag(3)), c(1, 0, 0, 0), meq = 1)$solution
  expect_equal(unname(w), qp, tolerance = 1e-6)
})

test_that("superlearner uses non-negative weights summing to one by default", {
  d <- MASS::Pima.tr
  sp <- list(learners = c("glm", "rpart", "kknn"))
  f <- fit(type ~ ., d, "superlearner", spec = sp)
  w <- f$state$meta_fit$weights
  expect_identical(f$state$meta_fit$engine, "convex")
  expect_true(all(w >= 0)); expect_equal(sum(w), 1)
  z <- qlogis(pmin(pmax(f$state$meta_x, 1e-6), 1 - 1e-6))
  ll <- function(w) { p <- plogis(drop(z %*% w)); -mean(ifelse(d$type == "Yes", log(p), log(1 - p))) }
  for (v in list(c(1, 0, 0), c(0, 1, 0), c(0, 0, 1), c(1, 1, 1) / 3)) expect_lte(ll(w), ll(v) + 1e-10)
  p <- predict(f, d[1:5, ], type = "prob")
  expect_equal(unname(rowSums(p)), rep(1, 5))
  r <- fit(mpg ~ wt + hp, mtcars, "superlearner", spec = list(learners = c("glm", "rpart")))
  expect_equal(sum(r$state$meta_fit$weights), 1)
  m <- fit(Species ~ ., iris, "superlearner", spec = list(learners = c("lda", "rpart")))
  expect_equal(sum(m$state$meta_fit$weights), 1)
  expect_equal(unname(rowSums(predict(m, iris[c(1, 51, 101), ], type = "prob"))), rep(1, 3), tolerance = 1e-5)
  # Ridge meta-learner stays available, and stays the stacking default.
  expect_identical(fit(type ~ ., d, "superlearner", spec = c(sp, meta_model = "glmnet"))$state$meta_fit$engine,
                   "glmnet_binomial")
  expect_identical(fit(type ~ ., d, "stacking", spec = sp)$state$meta_fit$engine, "glmnet_binomial")
  expect_identical(fit(type ~ ., d, "stacking", spec = c(sp, meta_model = "convex"))$state$meta_fit$engine,
                   "convex")
})
