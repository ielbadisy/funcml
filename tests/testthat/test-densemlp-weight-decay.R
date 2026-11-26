test_that("densemlp and mlp forward weight_decay and min_epochs to the engine", {
  skip_if_not(utils::packageVersion("densemlp") >= "0.9.3")
  sp <- list(hidden_units = 8L, epochs = 30L, early_stopping = FALSE, validation = 0)
  f <- function(model, ...) fit(mpg ~ wt + hp, mtcars, model, spec = c(sp, list(...)), seed = 1)
  p <- function(...) predict(f(...), mtcars)
  for (m in c("densemlp", "mlp")) {
    expect_equal(f(m, weight_decay = 5)$state$state$weight_decay, 5)
    expect_equal(p(m), p(m, weight_decay = 0))
    expect_false(isTRUE(all.equal(p(m), p(m, weight_decay = 5))))
  }
  g <- fit(mpg ~ wt + hp, mtcars, "densemlp", seed = 1,
           spec = list(hidden_units = 4L, epochs = 40L, min_epochs = 40L, patience = 1L, min_delta = 1e6))
  expect_equal(g$state$state$epochs_run, 40L)
})
