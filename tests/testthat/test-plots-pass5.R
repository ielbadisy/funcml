# Book pass 5 plot issues (0.9.15).
pass5 <- function() {
  set.seed(1); n <- 400
  g <- data.frame(age = round(runif(n, 55, 90)), height = round(rnorm(n, 162, 7)), bmi = rnorm(n, 27, 4))
  g$y <- factor(rbinom(n, 1, plogis(-1.4 + 0.05 * (g$age - 70) - 1.2 * (g$height < 150))), labels = c("No", "Yes"))
  g
}
lyr <- function(p) vapply(p$layers, function(l) class(l$geom)[1], character(1))

test_that("compare plot: one value axis per metric, direction strips, best model on top, no title", {
  g <- pass5()
  cmp <- compare(g, y ~ ., models = c("glm", "rpart"), metrics = c("auc", "brier"), resampling = cv(3, seed = 1))
  p <- plot(cmp)
  expect_null(p$labels$title)
  expect_equal(p$facet$params$free, list(x = TRUE, y = FALSE))
  expect_false(inherits(p$coordinates, "CoordFlip"))
  expect_equal(levels(p$data$metric), c("auc (higher is better)", "brier (lower is better)"))
  r <- cmp$results[cmp$results$metric == "auc", ]
  expect_equal(tail(levels(p$data$model), 1), r$model[which.max(r$mean)])
  expect_equal(p$data$mean, cmp$results$mean)
  expect_equal(plot(cmp, title = "T", caption = "C")$labels[c("title", "caption")], list(title = "T", caption = "C"))
  expect_false(plot(cmp, scales = "fixed")$facet$params$free$x)
})

test_that("evaluate plot: free metric panels with direction strips, grey/black only", {
  g <- pass5()
  ev <- evaluate(g, y ~ ., model = "glm", resampling = cv(3, seed = 1), metrics = c("auc", "brier", "calslope"))
  p <- plot(ev)
  expect_null(p$labels$title)
  expect_true(p$facet$params$free$x)
  expect_equal(levels(p$data$metric),
               c("auc (higher is better)", "brier (lower is better)", "calslope (closer to 1 is better)"))
  b <- ggplot2::ggplot_build(p)
  cols <- unique(unlist(lapply(b$data, function(d) d$colour)))
  expect_false(any(c("#0072B2", "#2b8cbe") %in% cols))
})

test_that("ALE keeps the tails, anchors the first cut and matches iml", {
  skip_if_not_installed("iml")
  m <- fit(mpg ~ wt + hp + disp, mtcars, model = "glm")
  a <- interpret(m, mtcars, method = "ale", features = "wt")$result$curves
  expect_equal(range(a$value), range(mtcars$wt))
  pr <- iml::Predictor$new(stats::lm(mpg ~ wt + hp + disp, mtcars), data = mtcars[, c("wt", "hp", "disp")],
                           y = mtcars$mpg)
  fe <- iml::FeatureEffect$new(pr, "wt", method = "ale", grid.size = 20)$results
  expect_equal(a$value, fe$wt)
  expect_equal(a$effect, fe$.value, tolerance = 1e-8)
  # non-additive model, explicit grid
  m3 <- fit(mpg ~ wt + hp, mtcars, model = "rpart", spec = list(minsplit = 5, cp = 0.001))
  pr3 <- iml::Predictor$new(m3, data = mtcars[, c("wt", "hp")], y = mtcars$mpg,
                            predict.function = function(model, newdata) predict(model, newdata))
  fe3 <- iml::FeatureEffect$new(pr3, "hp", method = "ale", grid.size = 8)$results
  a3 <- interpret(m3, mtcars, method = "ale", features = "hp", grid = list(hp = fe3$hp))$result$curves
  expect_equal(a3$effect, fe3$.value, tolerance = 1e-8)
})

test_that("ALE shows the drop inside the first bin of height", {
  g <- pass5()
  m <- fit(y ~ ., g, model = "rpart", spec = list(cp = 0.005, minsplit = 10))
  a <- interpret(m, g, method = "ale", features = "height", grid.resolution = 10)$result$curves
  expect_equal(a$value[1], min(g$height))
  expect_equal(nrow(a), length(unique(stats::quantile(g$height, 0:10 / 10, type = 1))))
})

test_that("interaction heatmap uses one feature order on both axes", {
  m <- fit(mpg ~ wt + hp + disp, mtcars, model = "rpart", spec = list(minsplit = 5))
  p <- plot(interpret(m, mtcars, method = "interaction", features = c("wt", "hp", "disp"), nsamples = 20,
                      grid_size = 4))
  expect_equal(levels(p$data$feature_x), rev(levels(p$data$feature_y)))
  b <- ggplot2::ggplot_build(p)$data[[1]]
  expect_true(all(p$data$interaction[b$x + b$y == 4] == 0)) # self-pairs fall on one diagonal
  d <- p$data; k <- paste(d$feature_x, d$feature_y)
  expect_equal(d$interaction, d$interaction[match(paste(d$feature_y, d$feature_x), k)]) # symmetric
  expect_equal(p$theme$axis.text.x$angle, 45)
  expect_null(p$labels$title)
})

test_that("permutation importance defaults to AUC for probabilities; explicit metrics unchanged", {
  g <- pass5()
  m <- fit(y ~ ., g, model = "glm")
  d <- interpret(m, g, method = "permute", nsim = 3, seed = 1)
  expect_equal(d$result$metric %||% d$metric, "auc")
  expect_equal(d$type, "prob")
  expect_equal(d$result$scores,
               interpret(m, g, method = "permute", nsim = 3, seed = 1, metric = "auc")$result$scores)
  acc <- interpret(m, g, method = "permute", nsim = 3, seed = 1, metric = "accuracy")
  expect_equal(acc$type, "class")
  expect_equal(acc$result$scores,
               interpret(m, g, method = "permute", nsim = 3, seed = 1, type = "class")$result$scores)
  expect_equal(plot(d)$labels$x, "Drop in AUC after permutation")
  r <- interpret(fit(mpg ~ wt + hp, mtcars, model = "glm"), mtcars, method = "permute", nsim = 2, seed = 1)
  expect_equal(r$result$metric %||% r$metric, "rmse")
})

test_that("no plot method writes an automatic title; title/subtitle/caption are honoured", {
  g <- pass5()
  m <- fit(y ~ ., g, model = "glm")
  p <- predict(m, g, type = "prob")[, "Yes"]
  objs <- list(
    roccurve(g$y, p), dca(g$y, p), calibrationcurve(g$y, p), calibrationfit(g$y, p),
    interpret(m, g, method = "dca"), interpret(m, g, method = "calibration"),
    interpret(m, g, method = "pdp", features = "age", nsamples = 30),
    interpret(m, g, method = "ice", features = "age", nsamples = 20),
    interpret(m, g, method = "ale", features = "age"),
    interpret(m, g, method = "permute", nsim = 2, seed = 1),
    interpret(m, g, method = "shap", newdata = g[1, ], nsim = 5, seed = 1),
    evaluate(g, y ~ ., model = "glm", resampling = cv(3, seed = 1)),
    tune(g, y ~ ., model = "rpart", grid = data.frame(cp = c(0.01, 0.05)), resampling = cv(3, seed = 1))
  )
  for (o in objs) {
    expect_null(plot(o)$labels$title)
    expect_null(plot(o)$labels$subtitle)
    l <- plot(o, title = "a", subtitle = "b", caption = "c")$labels
    expect_equal(l[c("title", "subtitle", "caption")], list(title = "a", subtitle = "b", caption = "c"))
  }
})

test_that("calibration plots: Wilson intervals and no fixed coordinate system", {
  g <- pass5()
  p <- predict(fit(y ~ ., g, model = "glm"), g, type = "prob")[, "Yes"]
  cc <- calibrationcurve(g$y, p, bins = 5)
  pl <- plot(cc)
  expect_true("GeomLinerange" %in% lyr(pl))
  ref <- t(vapply(seq_len(nrow(cc)), function(i) {
    stats::prop.test(round(cc$observed[i] * cc$n[i]), cc$n[i], correct = FALSE)$conf.int[1:2]
  }, numeric(2)))
  expect_equal(unname(as.matrix(pl$data[, c("cilo", "cihi")])), ref, tolerance = 1e-10)
  expect_false("GeomLinerange" %in% lyr(plot(cc, ci = FALSE)))
  expect_no_message(pl + ggplot2::coord_cartesian(xlim = c(0, 0.6)))
  expect_equal(pl$theme$aspect.ratio, 1)
})

test_that("calibrationfit() has a class, keeps its numbers and plots the recalibration curve", {
  g <- pass5()
  p <- predict(fit(y ~ ., g, model = "glm"), g, type = "prob")[, "Yes"]
  cf <- calibrationfit(g$y, p)
  expect_s3_class(cf, c("funcml_calfit", "data.frame"))
  expect_equal(names(cf), c("term", "estimate", "se", "lower", "upper"))
  lp <- stats::qlogis(p); yy <- as.integer(g$y == "Yes")
  expect_equal(cf$estimate[2], unname(stats::coef(stats::glm(yy ~ lp, family = stats::binomial()))[2]))
  pl <- plot(cf)
  expect_s3_class(pl, "ggplot")
  rc <- pl$layers[[which(lyr(pl) == "GeomLine")[2]]]$data
  expect_equal(rc$observed, stats::plogis(cf$estimate[3] + cf$estimate[2] * stats::qlogis(rc$mean_pred)))
  expect_true("GeomText" %in% lyr(pl))
  expect_false("GeomText" %in% lyr(plot(cf, stats = FALSE)))
})

test_that("bootvalidate plot shows the optimism distribution with its mean", {
  g <- pass5()
  bv <- bootvalidate(g, y ~ ., model = "glm", B = 20, metrics = c("auc", "calslope"), seed = 1)
  p <- plot(bv)
  expect_s3_class(p, "ggplot")
  r <- bv$replicates
  expect_equal(p$data$value, r$boot - r$orig)
  vl <- p$layers[[2]]$data
  expect_equal(unname(vl$v[vl$k == "mean"]), bv$summary$optimism, tolerance = 1e-12)
  po <- plot(bv, what = "orig", metrics = "calslope")
  expect_equal(po$data$value, r$orig[r$metric == "calslope"])
  expect_equal(po$layers[[2]]$data$v[2], 1)
  expect_null(p$labels$title)
})

test_that("SHAP waterfall runs from the baseline to the prediction with feature values and Okabe-Ito colours", {
  m <- fit(mpg ~ wt + hp + disp, mtcars, model = "glm")
  sh <- interpret(m, mtcars, method = "shap", newdata = mtcars[3, ], nsim = 20, seed = 1)
  p <- plot(sh)
  d <- p$data
  expect_equal(tail(d$end, 1), sh$result$prediction[1], tolerance = 1e-10)
  expect_equal(d$start[1], sh$result$baseline[1], tolerance = 1e-10)
  expect_true(all(grepl(" = ", d$feature_label)))
  fills <- unique(ggplot2::ggplot_build(p)$data[[3]]$fill)
  expect_true(all(fills %in% c("#D55E00", "#0072B2")))
  expect_null(p$labels$title)
})
