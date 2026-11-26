test_that("profile-type interpretations accept integer and double features together", {
  set.seed(1)
  d <- data.frame(a = rnorm(100), b = sample(1:50, 100, TRUE), y = factor(rbinom(100, 1, .5)))
  f <- fit(y ~ ., d, model = "glm")
  for (m in c("ceteris_paribus", "pdp", "ice", "ale", "profile")) {
    r <- interpret(f, d, method = m, newdata = d[1, ], features = c("a", "b"))
    expect_s3_class(plot(r), "ggplot")
  }
  cp <- interpret(f, d, method = "ceteris_paribus", newdata = d[1, ], features = c("a", "b"))
  expect_type(cp$result$curves$value, "double")
  expect_setequal(unique(cp$result$curves$feature), c("a", "b"))
})
