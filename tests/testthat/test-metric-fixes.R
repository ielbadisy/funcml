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
