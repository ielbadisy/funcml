test_that("bootvalidate() optimism correction matches rms::validate()", {
  skip_if_not_installed("rms")
  set.seed(3)
  n <- 150
  d <- data.frame(x1 = rnorm(n), x2 = rnorm(n), x3 = rnorm(n), x4 = rnorm(n))
  d$y <- factor(rbinom(n, 1, plogis(0.8 * d$x1 - 0.5 * d$x2)))
  f <- y ~ x1 + x2 + x3 + x4
  bv <- bootvalidate(d, f, model = "glm", B = 60, seed = 1, metrics = c("auc", "brier"))
  # rms draws its bootstrap samples with the same sample() call, so with the
  # same seed both use the same replicates (no redraw happened here).
  fr <- rms::lrm(f, data = d, x = TRUE, y = TRUE)
  set.seed(1)
  v <- rms::validate(fr, B = 60)
  s <- bv$summary
  expect_equal(s$apparent[s$metric == "auc"], 0.5 + v["Dxy", "index.orig"] / 2, tolerance = 1e-6)
  expect_equal(s$optimism[s$metric == "auc"], v["Dxy", "optimism"] / 2, tolerance = 1e-6)
  expect_equal(s$corrected[s$metric == "auc"], 0.5 + v["Dxy", "index.corrected"] / 2, tolerance = 1e-6)
  expect_equal(s$corrected[s$metric == "brier"], v["B", "index.corrected"], tolerance = 1e-6)

  o <- rms::ols(mpg ~ wt + hp + qsec, data = mtcars, x = TRUE, y = TRUE)
  set.seed(2)
  vo <- rms::validate(o, B = 50)
  bvr <- bootvalidate(mtcars, mpg ~ wt + hp + qsec, model = "glm", B = 50, seed = 2,
                      metrics = c("mse", "rsq"))
  expect_equal(bvr$summary$corrected, unname(vo[c("MSE", "R-square"), "index.corrected"]),
               tolerance = 1e-6)
})

test_that("bootvalidate() .632 and .632+ follow the hand formulas", {
  bv <- bootvalidate(mtcars, mpg ~ wt + hp + qsec, model = "glm", B = 30, seed = 5,
                     metrics = c("mse", "rsq"))
  # replicates can be rebuilt by hand from the stored indices
  idx <- bv$indices[[4]]
  oob <- setdiff(seq_len(nrow(mtcars)), idx)
  g <- stats::lm(mpg ~ wt + hp + qsec, data = mtcars[idx, ])
  r4 <- bv$replicates[bv$replicates$replicate == 4 & bv$replicates$metric == "mse", ]
  expect_equal(r4$boot, mean(stats::residuals(g)^2))
  expect_equal(r4$orig, mean((mtcars$mpg - stats::predict(g, mtcars))^2))
  expect_equal(r4$oob, mean((mtcars$mpg[oob] - stats::predict(g, mtcars[oob, ]))^2))

  full <- stats::lm(mpg ~ wt + hp + qsec, data = mtcars)
  y <- mtcars$mpg
  yhat <- stats::fitted(full)
  app <- mean((y - yhat)^2)
  gamma <- mean(outer(y, yhat, "-")^2)
  rr <- bv$replicates[bv$replicates$metric == "mse", ]
  err1 <- mean(rr$oob)
  R <- (min(err1, gamma) - app) / (gamma - app)
  w <- 0.632 / (1 - 0.368 * R)
  s <- bv$summary[bv$summary$metric == "mse", ]
  expect_equal(s$gamma, gamma)
  expect_equal(s$est632, 0.368 * app + 0.632 * err1)
  expect_equal(s$est632plus, (1 - w) * app + w * min(err1, gamma))
  expect_equal(s$corrected, app - mean(rr$boot - rr$orig))
  # higher-is-better metric: .632+ lies between apparent and no-information
  sr <- bv$summary[bv$summary$metric == "rsq", ]
  expect_lt(sr$est632plus, sr$apparent)
  expect_gt(sr$est632plus, sr$gamma)
})

test_that("bootvalidate() checks inputs and missing values", {
  expect_error(bootvalidate(mtcars, mpg ~ wt, model = "glm", B = 1), "B")
  d <- mtcars
  d$wt[1] <- NA
  expect_error(bootvalidate(d, mpg ~ wt, model = "glm", B = 5), "bootvalidate")
})
