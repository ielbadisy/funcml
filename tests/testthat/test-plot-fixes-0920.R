heart_like <- function() {
  set.seed(3); n <- 150
  d <- data.frame(age = rnorm(n, 55, 8), bp = rnorm(n, 130, 15), sex = factor(sample(c("F", "M"), n, TRUE)))
  d$y <- factor(ifelse(plogis(-8 + 0.1 * d$age + 0.02 * d$bp + (d$sex == "M")) > runif(n), "Yes", "No"))
  d
}

test_that("force plot segments tile [f - P, f + N] without overlap", {
  d <- heart_like(); f <- fit(y ~ ., d, model = "glm")
  s <- interpret(f, d, method = "shap", newdata = d[1, ], nsim = 50, seed = 1)
  b <- ggplot2::ggplot_build(plot(s, kind = "force"))$data[[1]]
  r <- b[order(b$xmin), c("xmin", "xmax")]
  expect_equal(r$xmin[-1], r$xmax[-nrow(r)], tolerance = 1e-8)
  sh <- s$result$shap
  expect_equal(diff(range(c(r$xmin, r$xmax))), sum(abs(sh)), tolerance = 1e-8)
})

test_that("engine importance is not labelled as a permutation drop", {
  d <- heart_like(); f <- fit(y ~ ., d, model = "ranger", seed = 1)
  v <- interpret(f, d, method = "vip", importance_type = "model")
  expect_false(grepl("permutation", plot(v)$labels$x))
  expect_match(plot(interpret(f, d, method = "vip", seed = 1))$labels$x, "permutation")
})

test_that("predict loads the engines of a fit and of ensemble base learners", {
  d <- heart_like(); f <- fit(y ~ ., d, model = "stacking", spec = list(learners = c("glm", "rpart", "kknn")))
  expect_setequal(.load_engines(f), c("rpart", "kknn"))
  expect_equal(.load_engines(fit(y ~ ., d, model = "ranger", seed = 1)), "ranger")
})

test_that("force plot labels in the same row do not overlap", {
  d <- heart_like(); f <- fit(y ~ ., d, model = "glm")
  s <- interpret(f, d, method = "shap", newdata = d[1, ], nsim = 50, seed = 1)
  b <- ggplot2::ggplot_build(plot(s, kind = "force"))$data
  cw <- diff(range(unlist(b[[1]][c("xmin", "xmax")]))) / 85
  t <- b[[3]]; t$half <- nchar(sub("\n.*", "", t$label)) * cw / 2 + cw
  for (r in split(t, t$y)) if (nrow(r) > 1) {
    r <- r[order(r$x), ]
    expect_true(all(head(r$x + r$half, -1) <= tail(r$x - r$half, -1) + 1e-12))
  }
})
