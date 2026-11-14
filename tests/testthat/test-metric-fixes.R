library(funcml)

test_that("brier() and logloss() accept a positive-class probability vector", {
  truth <- factor(c("a", "b", "b", "a", "b"), levels = c("a", "b"))
  p <- c(0.2, 0.7, 0.4, 0.5, 0.9)
  expect_equal(brier(truth, p), mean((p - (truth == "b"))^2))
  expect_equal(brier(truth, p), brier(truth, cbind(a = 1 - p, b = p)))
  expect_equal(logloss(truth, p), -mean(log(ifelse(truth == "b", p, 1 - p))), tolerance = 1e-10)
  expect_equal(logloss(truth, p), logloss(truth, cbind(a = 1 - p, b = p)))
  truth3 <- factor(c("a", "b", "c"))
  expect_error(brier(truth3, c(0.2, 0.3, 0.4)), "binary")
})

test_that("binary recall, precision, specificity and f1 use the positive class", {
  t <- factor(c(0, 0, 0, 0, 1, 1, 1, 1, 1, 1))
  p <- factor(c(0, 0, 1, 1, 1, 1, 1, 1, 0, 0))
  expect_equal(recall(t, p), 4 / 6)
  expect_equal(precision(t, p), 4 / 6)
  expect_equal(specificity(t, p), 2 / 4)
  expect_equal(f1(t, p), 4 / 6)
  expect_equal(balancedaccuracy(t, p), (4 / 6 + 2 / 4) / 2)
  expect_equal(recall(t, p, average = "macro"), balancedaccuracy(t, p))
  expect_equal(recall(t, p, positive = "0"), 2 / 4)
  expect_false(isTRUE(all.equal(recall(t, p), balancedaccuracy(t, p))))
})

test_that("multiclass class metrics stay macro-averaged", {
  t <- factor(c("a", "a", "b", "b", "c", "c"))
  p <- factor(c("a", "b", "b", "b", "c", "a"), levels = levels(t))
  expect_equal(recall(t, p), mean(c(1 / 2, 1, 1 / 2)))
  expect_equal(recall(t, p), recall(t, p, average = "macro"))
})

test_that("compare() reports distinct recall, specificity and balanced accuracy", {
  set.seed(5)
  d <- data.frame(x1 = rnorm(200), x2 = rnorm(200))
  d$y <- factor(ifelse(runif(200) < plogis(-1 + d$x1), "yes", "no"), levels = c("no", "yes"))
  ev <- evaluate(d, y ~ x1 + x2, model = "glm", resampling = cv(3, seed = 1),
                 metrics = c("recall", "specificity", "balanced_accuracy"))
  s <- ev$summary
  vals <- s$mean[match(c("recall", "specificity", "balanced_accuracy"), s$metric)]
  expect_false(isTRUE(all.equal(vals[1], vals[3])))
  expect_equal(vals[3], (vals[1] + vals[2]) / 2, tolerance = 0.05)
})
