test_that("auc and bootvalidate work for large n (no integer overflow)", {
  set.seed(1); d <- data.frame(x = rnorm(400)); d$y <- factor(rbinom(400, 1, plogis(d$x)))
  bv <- bootvalidate(d, y ~ x, "glm", B = 3, seed = 1, metrics = "auc")
  expect_true(all(is.finite(unlist(bv$summary[, -1]))))
  expect_identical(bv$summary$gamma, 0.5)
  y <- rep(0:1, 60000); p <- runif(120000)
  expect_equal(auc(factor(y), p), mean(outer(p[y == 1][1:300], p[y == 0][1:300], ">")), tolerance = 0.05)
  expect_true(is.finite(auc(factor(y), p)))
})

test_that("bootvalidate() gives finite estimates for every metric at n = 5000", {
  set.seed(2); d <- data.frame(x = rnorm(5000), z = rnorm(5000)); d$y <- factor(rbinom(5000, 1, plogis(d$x)))
  ms <- c("auc", "auc_weighted", "brier", "logloss", "accuracy", "precision", "recall", "specificity",
          "f1", "balanced_accuracy", "ece", "mce")
  s <- bootvalidate(d, y ~ x + z, "glm", B = 4, seed = 1, metrics = ms)$summary
  expect_true(all(is.finite(as.matrix(s[, -1]))))
  expect_equal(s$gamma[1:2], c(0.5, 0.5))
  expect_true(all(s$est632plus >= pmin(s$apparent, s$gamma) - 1e-12 &
                  s$est632plus <= pmax(s$apparent, s$oob, s$gamma) + 1e-12))
  # all-pairs Brier: mean over i, j of (y_i - p_j)^2 (estimated from sampled pairs)
  yy <- d$y == "1"; pp <- fitted(glm(y ~ x + z, binomial, d))
  expect_equal(s$gamma[s$metric == "brier"], mean(yy) - 2 * mean(yy) * mean(pp) + mean(pp^2), tolerance = 0.01)
})

test_that("bootvalidate() optimism-corrected C matches rms::validate() at n = 600", {
  skip_if_not_installed("rms")
  set.seed(4); n <- 600
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n))
  d$y <- factor(rbinom(n, 1, plogis(0.7 * d$x1 - 0.4 * d$x2)))
  f <- y ~ x1 + x2 + x3
  s <- bootvalidate(d, f, "glm", B = 40, seed = 1, metrics = "auc")$summary
  set.seed(1); v <- rms::validate(rms::lrm(f, data = d, x = TRUE, y = TRUE), B = 40)
  expect_equal(s$corrected, 0.5 + v["Dxy", "index.corrected"] / 2, tolerance = 0.01)
})

test_that("coef() on a glmnet fit returns the coefficients at the selected lambda", {
  set.seed(3); d <- data.frame(x = rnorm(200), z = rnorm(200)); d$y <- factor(rbinom(200, 1, plogis(d$x)))
  m <- fit(y ~ x + z, d, "glmnet")
  ref <- as.matrix(coef(enginemodel(m), s = m$state$lambda_sel))
  expect_equal(coef(m), setNames(ref[, 1], rownames(ref)))
  m1 <- fit(y ~ x, d, "glmnet", spec = list(lambda = 0.01))
  expect_named(coef(m1), c("(Intercept)", "x"))
  mm <- fit(Species ~ ., iris, "glmnet")
  expect_equal(dim(coef(mm)), c(5L, 3L))
  expect_equal(colnames(coef(mm)), levels(iris$Species))
})

test_that("quantile calibration bins honour `bins` on tied scores", {
  p <- rep(c(0.02, 0.1, 0.3, 0.6, 0.9, 0.97), c(380, 50, 50, 40, 30, 150))
  set.seed(1); y <- rbinom(length(p), 1, p)
  cc <- calibrationcurve(y, p, bins = 5)
  expect_equal(nrow(cc), 5L)
  expect_equal(sum(cc$n), length(p))
  expect_true(all(cc$n > 0))
  expect_equal(nrow(calibrationcurve(y, p, bins = 10)), 6L)
  expect_equal(nrow(calibrationcurve(y, rep(0.4, length(y)), bins = 5)), 1L)
  # untied scores keep the plain quantile bins
  q <- runif(200); z <- rbinom(200, 1, q)
  expect_equal(calibrationcurve(z, q, bins = 4)$n, rep(50L, 4))
  expect_equal(ece(y, p, bins = 5), sum(cc$n / sum(cc$n) * cc$abs_gap))
})

test_that("calibrationfit() matches glm and rms::val.prob()", {
  set.seed(1); p <- runif(500); y <- rbinom(500, 1, plogis(0.7 * qlogis(p) - 0.3))
  cf <- calibrationfit(y, p)
  expect_equal(cf$term, c("intercept", "slope", "recalintercept"))
  m0 <- glm(y ~ 1, binomial, offset = qlogis(p)); m1 <- glm(y ~ qlogis(p), binomial)
  expect_equal(cf$estimate, unname(c(coef(m0), coef(m1)[2:1])), tolerance = 1e-8)
  expect_equal(cf$lower[2], unname(confint.default(m1)[2, 1]), tolerance = 1e-8)
  if (requireNamespace("rms", quietly = TRUE)) {
    vp <- rms::val.prob(p, y, pl = FALSE)
    expect_equal(cf$estimate[2:3], unname(vp[c("Slope", "Intercept")]), tolerance = 1e-6)
  }
  f <- factor(ifelse(y == 1, "yes", "no"))
  expect_equal(calibrationfit(f, p, positive = "yes")$estimate, cf$estimate)
})
