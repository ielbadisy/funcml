test_that("nnet standardises predictors with training moments", {
  d <- MASS::Pima.tr; d2 <- transform(d, glu = glu * 1000, bp = bp + 500)
  sp <- list(size = 3, decay = 0, maxit = 200)
  p <- function(dat, ...) predict(fit(type ~ ., dat, "nnet", spec = c(sp, list(...)), seed = 1),
                                 dat[1:50, ], type = "prob")
  expect_equal(p(d), p(d2), tolerance = 1e-4)
  f <- fit(type ~ ., d, "nnet", spec = sp, seed = 1)
  expect_equal(f$state$center, colMeans(as.matrix(d[, 1:7])))
  # Raw-scale inputs saturate the hidden units; scaled inputs give a useful model.
  pr <- predict(f, d, type = "prob")[, "Yes"]
  expect_gt(stats::cor(pr, d$type == "Yes"), 0.4)
  expect_false(isTRUE(all.equal(p(d), p(d, standardize = FALSE))))
})
