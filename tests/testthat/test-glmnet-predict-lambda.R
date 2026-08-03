test_that("glmnet predict_xy does not collapse to a degenerate constant when spec$lambda is unset at fit time", {
  set.seed(20260427)
  n <- 400; p <- 8
  X <- matrix(rnorm(n * p), n, p)
  beta <- c(2, -2, 1.5, rep(0, p - 3))
  y <- factor(ifelse(rbinom(n, 1, plogis(X %*% beta)) == 1, "pos", "neg"), levels = c("neg", "pos"))
  df <- data.frame(y = y, X)

  # spec omits lambda entirely -> fit_xy uses the default full regularization path,
  # which previously caused predict_xy to silently fall back to the most-regularized
  # (largest) lambda in that path, collapsing all predictions toward the null model.
  fit <- funcml::fit(y ~ ., data = df, model = "glmnet", spec = list(alpha = 0.5))
  p_pred <- funcml:::predict.funcml_fit(fit, newdata = df, type = "prob")[, "pos"]

  expect_gt(length(unique(round(p_pred, 6))), 1L)
  expect_gt(diff(range(p_pred)), 0.05)

  auroc <- {
    yy <- as.integer(y == "pos")
    r <- rank(p_pred)
    n1 <- sum(yy == 1); n0 <- sum(yy == 0)
    (sum(r[yy == 1]) - n1 * (n1 + 1) / 2) / (n1 * n0)
  }
  expect_gt(auroc, 0.6)
})

test_that("glmnet predict_xy uses the same lambda that was actually fit when spec$lambda is set", {
  set.seed(20260427)
  n <- 300; p <- 6
  X <- matrix(rnorm(n * p), n, p)
  beta <- c(1.5, -1.5, 1, rep(0, p - 3))
  y <- factor(ifelse(rbinom(n, 1, plogis(X %*% beta)) == 1, "pos", "neg"), levels = c("neg", "pos"))
  df <- data.frame(y = y, X)

  fit <- funcml::fit(y ~ ., data = df, model = "glmnet", spec = list(alpha = 0.5, lambda = 0.05))
  p_pred <- funcml:::predict.funcml_fit(fit, newdata = df, type = "prob")[, "pos"]

  expect_gt(length(unique(round(p_pred, 6))), 1L)
})

test_that("glmnet fit_xy always fits the full regularization path, never a single cold lambda", {
  # Requesting a single lambda directly in glmnet::glmnet() (rather than fitting the
  # full path and extracting via predict(..., s=)) relies on cold-starting the
  # coordinate-descent solver with no warm start. On wide/high-cardinality design
  # matrices this can fail to converge and glmnet silently returns an empty,
  # all-zero-coefficient model (fit$lambda == Inf), which then predicts a constant
  # probability for every observation regardless of predict_xy's lambda selection.
  # This test asserts the underlying invariant that prevents that failure mode by
  # construction: fit_xy must always produce a multi-point path.
  set.seed(20260427)
  n <- 300; p <- 6
  X <- matrix(rnorm(n * p), n, p)
  beta <- c(1.5, -1.5, 1, rep(0, p - 3))
  y <- factor(ifelse(rbinom(n, 1, plogis(X %*% beta)) == 1, "pos", "neg"), levels = c("neg", "pos"))
  df <- data.frame(y = y, X)

  fit <- funcml::fit(y ~ ., data = df, model = "glmnet", spec = list(alpha = 0.5, lambda = 0.05))

  expect_gt(length(fit$state$state$lambda), 1L)
  expect_true(is.finite(fit$state$state$lambda[1]))
  expect_equal(fit$state$lambda, 0.05)
})
