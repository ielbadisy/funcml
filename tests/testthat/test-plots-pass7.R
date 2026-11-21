test_that("bootvalidate optimism strips use the compare/evaluate direction labels", {
  d <- transform(mtcars, am = factor(am))
  bv <- suppressWarnings(bootvalidate(d, am ~ wt + hp, model = "glm", B = 10, metrics = c("auc", "calslope"),
                                      seed = 1))
  p <- plot(bv, what = "optimism")
  expect_equal(levels(p$data$metric), c("auc (higher is better)", "calslope (closer to 1 is better)"))
  expect_equal(levels(p$layers[[2]]$data$metric), levels(p$data$metric))
})

test_that("pdp/ice/ale plots take per-feature axis titles", {
  f <- fit(mpg ~ wt + hp + disp, data = mtcars, model = "glm")
  a <- interpret(f, mtcars, method = "ale", features = c("wt", "hp"))
  expect_equal(plot(a)$labels$x, "Feature value")
  lb <- c(wt = "Weight (1000 lb)", hp = "Gross horsepower")
  for (m in c("ale", "pdp", "ice")) {
    p <- plot(interpret(f, mtcars, method = m, features = c("wt", "hp"), nsamples = 10), labels = lb)
    expect_null(p$labels$x)
    s <- ggplot2::ggplot_build(p)$layout$layout
    expect_setequal(p$facet$params$labeller(s["feature"])[[1]], unname(lb))
  }
})
