test_that("kknn uses exactly k neighbours and the requested kernel", {
  skip_if_not_installed("kknn")
  d <- mtcars
  for (kern in c("rectangular", "triangular")) {
    f <- fit(mpg ~ wt + hp, d[1:24, ], model = "kknn",
             spec = list(k = 5, distance = 2, kernel = kern))
    ref <- kknn::kknn(mpg ~ wt + hp, train = d[1:24, ], test = d[25:32, ],
                      k = 5, distance = 2, kernel = kern)
    expect_equal(as.numeric(predict(f, d[25:32, ])), as.numeric(ref$fitted.values))
    expect_equal(enginemodel(f)$best.parameters$k, 5)
  }
  # rectangular kernel = plain mean of the k nearest outcomes (scaled X)
  f <- fit(mpg ~ wt + hp, d[1:24, ], model = "kknn",
           spec = list(k = 3, kernel = "rectangular"))
  X <- scale(d[1:24, c("wt", "hp")])
  xn <- scale(d[25, c("wt", "hp")], center = attr(X, "scaled:center"),
              scale = attr(X, "scaled:scale"))
  dist <- sqrt(colSums((t(X) - as.numeric(xn))^2))
  expect_equal(as.numeric(predict(f, d[25, ])), mean(d$mpg[1:24][order(dist)[1:3]]))
})

test_that("e1071_svm passes epsilon to support vector regression", {
  skip_if_not_installed("e1071")
  d <- mtcars
  for (eps in c(0.01, 1)) {
    f <- fit(mpg ~ wt + hp, d, model = "e1071_svm", spec = list(epsilon = eps))
    ref <- e1071::svm(mpg ~ wt + hp, data = d, type = "eps-regression",
                      kernel = "radial", cost = 1, gamma = 1 / 2, epsilon = eps)
    expect_equal(enginemodel(f)$epsilon, eps)
    expect_equal(as.numeric(predict(f, d)), as.numeric(predict(ref, d)), tolerance = 1e-6)
  }
  f_lo <- fit(mpg ~ wt + hp, d, model = "e1071_svm", spec = list(epsilon = 0.01))
  f_hi <- fit(mpg ~ wt + hp, d, model = "e1071_svm", spec = list(epsilon = 0.5))
  expect_gt(enginemodel(f_lo)$tot.nSV, enginemodel(f_hi)$tot.nSV)
})
