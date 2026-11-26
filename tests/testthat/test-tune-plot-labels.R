test_that("plot(tune()) labels round hyperparameter values and keep configurations distinct", {
  res <- data.frame(cost = c(0.25, 1, 4), gamma = c(0.0123456789, 1 / 3, 0.0123456), mean = c(.7, .8, .75),
                    conf_low = 0.6, conf_high = 0.9)
  lab <- funcml:::.format_tune_config(res)
  expect_equal(lab, c("cost=0.25, gamma=0.0123", "cost=1, gamma=0.333", "cost=4, gamma=0.0123"))
  t <- structure(list(results = rbind(res, transform(res[1, ], mean = 0.1)), best = res[2, ], metric = "auc",
                      direction = "max"), class = "funcml_tune")
  p <- plot(t)
  lv <- levels(p$data$config_label)
  expect_length(lv, 4)
  expect_false(any(grepl("  |0\\.012345", lv)))
  expect_equal(as.character(p$data$config_label[1]), "cost=1, gamma=0.333")
})
