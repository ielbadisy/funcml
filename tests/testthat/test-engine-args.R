test_that("ctree and cforest forward ctree_control arguments", {
  nn <- function(t) length(partykit::nodeids(t))
  f <- fit(mpg ~ ., mtcars, "ctree", spec = list(mincriterion = 0.01, maxdepth = 1))
  expect_equal(nn(f$state$state), 3)
  expect_gt(nn(fit(mpg ~ ., mtcars, "ctree", spec = list(mincriterion = 0.01))$state$state), 3)
  expect_equal(fit(mpg ~ ., mtcars, "ctree", spec = list(minbucket = 13))$state$state$info$control$minbucket, 13)
  cf <- fit(mpg ~ ., mtcars, "cforest", spec = list(ntree = 5, maxdepth = 1), seed = 1)
  expect_true(all(vapply(1:5, function(i) nn(partykit::gettree(cf$state$state, i)), 1) <= 3))
})

test_that("lightgbm forwards max_bin, lambda and num_threads", {
  set.seed(1); d <- data.frame(x1 = rnorm(400), x2 = rnorm(400)); d$y <- sin(2 * d$x1) + d$x2 + rnorm(400, sd = .3)
  f <- function(...) fit(y ~ ., d, "lightgbm", spec = list(nrounds = 20, num_leaves = 4, num_threads = 1, ...))
  par <- function(...) f(...)$state$state$params
  expect_equal(par(lambda = 3)$lambda_l2, 3)
  expect_equal(par(lambda_l1 = 2)$lambda_l1, 2)
  expect_equal(par(num_threads = 1)$num_threads, 1)
  expect_equal(par(max_bin = 4)$max_bin, 4)
  expect_false(isTRUE(all.equal(predict(f(), d), predict(f(lambda = 50), d))))
  expect_false(isTRUE(all.equal(predict(f(), d), predict(f(max_bin = 3), d))))
})

test_that("xgboost forwards lambda, alpha, gamma, min_child_weight and tree_method", {
  f <- function(...) fit(mpg ~ ., mtcars, "xgboost", spec = list(nrounds = 20, nthread = 1, ...))
  p0 <- predict(f(), mtcars)
  for (a in list(list(lambda = 50), list(alpha = 20), list(gamma = 10), list(min_child_weight = 10)))
    expect_false(isTRUE(all.equal(p0, predict(do.call(f, a), mtcars))), info = names(a))
  expect_equal(predict(f(lambda = 1, alpha = 0), mtcars), p0)
  upd <- function(...) xgboost::xgb.config(f(...)$state$state)$learner$gradient_booster$updater$name
  expect_true("grow_colmaker" %in% upd(tree_method = "exact"))
  expect_false("grow_colmaker" %in% upd())
})

test_that("fastgbm defaults to OMP_NUM_THREADS or one thread", {
  withr_env <- function(v, code) {
    old <- Sys.getenv("OMP_NUM_THREADS", NA); on.exit(if (is.na(old)) Sys.unsetenv("OMP_NUM_THREADS")
                                                      else Sys.setenv(OMP_NUM_THREADS = old))
    if (is.na(v)) Sys.unsetenv("OMP_NUM_THREADS") else Sys.setenv(OMP_NUM_THREADS = v)
    code
  }
  expect_equal(withr_env(NA, funcml:::.default_threads()), 1L)
  expect_equal(withr_env("3", funcml:::.default_threads()), 3L)
  expect_null(funcml:::funcml_registry("fastgbm")$defaults$threads)
})
