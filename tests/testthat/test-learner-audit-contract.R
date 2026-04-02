library(funcml)

if (requireNamespace("pkgload", quietly = TRUE)) {
  pkgload::load_all(".", quiet = TRUE, export_all = FALSE)
}

source(testthat::test_path("..", "..", "work", "audit", "audit_helpers.R"), local = FALSE)

audit_regression_data <- function() {
  make_split <- function(seed, n) {
    set.seed(seed)
    x1 <- rnorm(n)
    x2 <- rnorm(n)
    x3 <- rnorm(n)
    y <- 2 * x1 - 1.5 * x2 + 0.7 * x3 + rnorm(n, sd = 0.35)
    data.frame(outcome = y, x1 = x1, x2 = x2, x3 = x3)
  }
  list(
    scenario = "regression",
    formula = outcome ~ x1 + x2 + x3,
    train = make_split(20260401L, 72L),
    test = make_split(20260402L, 24L),
    task = "regression"
  )
}

audit_binary_data <- function() {
  make_split <- function(seed, n) {
    set.seed(seed)
    x1 <- rnorm(n)
    x2 <- rnorm(n)
    x3 <- rnorm(n)
    eta <- 1.1 * x1 - 0.8 * x2 + 0.6 * x3
    pr <- stats::plogis(eta)
    y <- ifelse(runif(n) < pr, "zeta", "alpha")
    data.frame(
      outcome = factor(y, levels = c("zeta", "alpha")),
      x1 = x1,
      x2 = x2,
      x3 = x3
    )
  }
  list(
    scenario = "binary_classification",
    formula = outcome ~ x1 + x2 + x3,
    train = make_split(20260403L, 84L),
    test = make_split(20260404L, 28L),
    task = "classification"
  )
}

audit_multiclass_data <- function() {
  make_split <- function(seed, n) {
    set.seed(seed)
    x1 <- rnorm(n)
    x2 <- rnorm(n)
    x3 <- rnorm(n)
    s1 <- 1.0 * x1 - 0.4 * x2 + 0.2 * x3 + rnorm(n, sd = 0.15)
    s2 <- -0.3 * x1 + 1.1 * x2 - 0.2 * x3 + rnorm(n, sd = 0.15)
    s3 <- 0.2 * x1 - 0.1 * x2 + 1.0 * x3 + rnorm(n, sd = 0.15)
    cls <- c("zeta", "alpha", "mu")[max.col(cbind(s1, s2, s3), ties.method = "first")]
    data.frame(
      outcome = factor(cls, levels = c("zeta", "alpha", "mu")),
      x1 = x1,
      x2 = x2,
      x3 = x3
    )
  }
  list(
    scenario = "multiclass_classification",
    formula = outcome ~ x1 + x2 + x3,
    train = make_split(20260405L, 96L),
    test = make_split(20260406L, 30L),
    task = "classification"
  )
}

audit_spec_for_test <- function(model, scenario) {
  switch(
    model,
    rpart = list(cp = 0.001, minsplit = 5L),
    glmnet = list(alpha = 0.5),
    ranger = list(num.trees = 80L, min.node.size = 3L),
    nnet = list(size = 4L, decay = 0.01, maxit = 150L),
    randomForest = list(ntree = 80L),
    gbm = list(n.trees = 60L, interaction.depth = 2L, shrinkage = 0.05, n.minobsinnode = 5L),
    C50 = list(trials = 5L),
    kknn = list(k = 5L, distance = 2),
    earth = list(degree = 1L),
    naivebayes = list(laplace = 1),
    adaboost = list(iter = 20L, nu = 0.1, type = "discrete"),
    pls = list(ncomp = 2L),
    ctree = list(mincriterion = 0.8),
    cforest = list(ntree = 80L, mincriterion = 0),
    lightgbm = list(nrounds = 40L, num_leaves = 15L, learning_rate = 0.1),
    catboost = list(iterations = 40L, depth = 4L, learning_rate = 0.1),
    bart = list(ntree = 40L, ndpost = 40L, nskip = 10L, keeptrees = TRUE, verbose = FALSE),
    xgboost = list(nrounds = 40L, max_depth = 4L, eta = 0.1, subsample = 1, colsample_bytree = 1),
    stacking = list(
      learners = if (identical(scenario, "multiclass_classification")) c("rpart", "kknn") else c("glm", "rpart"),
      learner_specs = list(),
      meta_model = "glmnet"
    ),
    superlearner = list(
      learners = if (identical(scenario, "multiclass_classification")) c("rpart", "kknn") else c("glm", "rpart"),
      learner_specs = list(),
      meta_model = "glmnet",
      resampling = cv(v = 3, seed = 1)
    ),
    list()
  )
}

scenario_supported_by_design <- function(adapter, scenario) {
  if (identical(scenario, "regression")) {
    return("regression" %in% adapter$tasks)
  }
  if (!("classification" %in% adapter$tasks)) {
    return(FALSE)
  }
  if (identical(scenario, "multiclass_classification")) {
    return(isTRUE(adapter$supports$multiclass))
  }
  TRUE
}

audit_datasets <- list(
  regression = audit_regression_data(),
  binary_classification = audit_binary_data(),
  multiclass_classification = audit_multiclass_data()
)

test_that("learner registry support metadata is coherent", {
  reg <- funcml:::funcml_registry()

  expect_equal(length(reg), 26L)
  expect_true(all(vapply(reg, function(x) is.character(x$package) && nzchar(x$package), logical(1))))
  expect_true(all(vapply(reg, function(x) is.list(x$supports), logical(1))))
  expect_true(all(vapply(reg, function(x) is.function(x$fit_xy), logical(1))))
  expect_true(all(vapply(reg, function(x) is.function(x$predict_xy), logical(1))))
  expect_true(all(vapply(reg, function(x) all(x$tasks %in% c("classification", "regression")), logical(1))))
})

test_that("advertised learner raw and probability contracts hold package-wide", {
  reg <- funcml:::funcml_registry()
  scenario_map <- do.call(
    rbind,
    lapply(names(reg), function(model) {
      adapter <- reg[[model]]
      out <- character()
      if ("regression" %in% adapter$tasks) out <- c(out, "regression")
      if ("classification" %in% adapter$tasks) out <- c(out, "binary_classification", "multiclass_classification")
      data.frame(learner = model, task = out, stringsAsFactors = FALSE)
    })
  )

  failures <- character()

  for (i in seq_len(nrow(scenario_map))) {
    model <- scenario_map$learner[i]
    scenario <- scenario_map$task[i]
    adapter <- reg[[model]]
    ds <- audit_datasets[[scenario]]
    supported_mode <- scenario_supported_by_design(adapter, scenario)
    spec <- audit_spec_for_test(model, scenario)
    fit_res <- safe_fit(ds$formula, ds$train, model, spec = spec, seed = 1L)

    if (!supported_mode) {
      if (identical(fit_res$status, "pass")) {
        failures <- c(failures, sprintf("%s/%s: unsupported mode fit succeeded", model, scenario))
      } else if (!is_clear_unsupported_error(fit_res$error)) {
        failures <- c(failures, sprintf("%s/%s: unsupported mode error was unclear: %s", model, scenario, fit_res$error))
      }
      next
    }

    if (!identical(fit_res$status, "pass")) {
      failures <- c(failures, sprintf("%s/%s: fit failed: %s", model, scenario, fit_res$error))
      next
    }

    raw_res <- safe_predict_raw(fit_res$value, ds$test)
    if (!identical(raw_res$status, "pass")) {
      failures <- c(failures, sprintf("%s/%s: raw predict failed: %s", model, scenario, raw_res$error))
      next
    }

    raw_check <- check_raw_prediction(
      raw_res$value,
      task = ds$task,
      n_expected = nrow(ds$test),
      levels_expected = if (is.factor(ds$train$outcome)) levels(ds$train$outcome) else NULL
    )
    if (!identical(raw_check$status, "pass")) {
      failures <- c(failures, sprintf("%s/%s: raw contract failed: %s", model, scenario, paste(raw_check$notes, collapse = "; ")))
    }

    if (identical(ds$task, "classification")) {
      prob_res <- safe_predict_prob(fit_res$value, ds$test)
      if (isTRUE(adapter$supports$prob)) {
        if (!identical(prob_res$status, "pass")) {
          failures <- c(failures, sprintf("%s/%s: prob predict failed: %s", model, scenario, prob_res$error))
          next
        }
        prob_check <- check_prob_prediction(prob_res$value, n_expected = nrow(ds$test), levels_expected = levels(ds$train$outcome))
        if (!identical(prob_check$status, "pass")) {
          failures <- c(failures, sprintf("%s/%s: prob contract failed: %s", model, scenario, paste(prob_check$notes, collapse = "; ")))
        } else {
          prob_mat <- prob_check$value
          if (!identical(check_prob_row_sums(prob_mat)$status, "pass")) {
            failures <- c(failures, sprintf("%s/%s: probability row sums invalid", model, scenario))
          }
          if (!identical(check_prob_column_names(prob_mat, levels(ds$train$outcome))$status, "pass")) {
            failures <- c(failures, sprintf("%s/%s: probability columns misaligned", model, scenario))
          }
          if (!identical(check_prob_class_reconstruction(prob_mat, raw_res$value, levels(ds$train$outcome))$status, "pass")) {
            failures <- c(failures, sprintf("%s/%s: argmax(prob) mismatched raw classes", model, scenario))
          }
        }
      } else {
        if (identical(prob_res$status, "pass")) {
          failures <- c(failures, sprintf("%s/%s: unsupported prob path succeeded", model, scenario))
        } else if (!is_clear_unsupported_error(prob_res$error)) {
          failures <- c(failures, sprintf("%s/%s: unsupported prob error was unclear: %s", model, scenario, prob_res$error))
        }
      }
    }
  }

  expect_equal(length(failures), 0L, info = paste(failures, collapse = "\n"))
})

test_that("interpretability contract holds for supported learner paths", {
  reg <- funcml:::funcml_registry()
  failures <- character()

  for (model in names(reg)) {
    adapter <- reg[[model]]

    for (scenario in c("regression", "binary_classification", "multiclass_classification")) {
      ds <- audit_datasets[[scenario]]
      if (identical(ds$task, "regression") && !("regression" %in% adapter$tasks)) next
      if (identical(ds$task, "classification") && !("classification" %in% adapter$tasks)) next

      supported_mode <- scenario_supported_by_design(adapter, scenario)
      spec <- audit_spec_for_test(model, scenario)
      fit_res <- safe_fit(ds$formula, ds$train, model, spec = spec, seed = 1L)

      if (!supported_mode) {
        next
      }
      if (!identical(fit_res$status, "pass")) {
        failures <- c(failures, sprintf("%s/%s: fit failed before interpret checks: %s", model, scenario, fit_res$error))
        next
      }

      raw_interpret <- safe_interpret_raw(fit_res$value, ds$train)
      if (!identical(raw_interpret$status, "pass")) {
        failures <- c(failures, sprintf("%s/%s: interpret raw failed: %s", model, scenario, raw_interpret$error))
      }

      if (identical(ds$task, "classification")) {
        prob_interpret <- safe_interpret_prob(fit_res$value, ds$train)
        if (isTRUE(adapter$supports$prob)) {
          if (!identical(prob_interpret$status, "pass")) {
            failures <- c(failures, sprintf("%s/%s: interpret prob failed: %s", model, scenario, prob_interpret$error))
          }
        } else if (identical(prob_interpret$status, "pass")) {
          failures <- c(failures, sprintf("%s/%s: interpret prob succeeded for unsupported learner", model, scenario))
        }
      }
    }
  }

  expect_equal(length(failures), 0L, info = paste(failures, collapse = "\n"))
})

test_that("catboost fitting does not create repo-local output files", {
  skip_if_not_installed("catboost")

  ds <- audit_binary_data()
  tmp <- tempfile("funcml-catboost-clean-")
  dir.create(tmp)
  old <- setwd(tmp)
  on.exit(setwd(old), add = TRUE)

  fit_res <- safe_fit(
    ds$formula,
    ds$train,
    "catboost",
    spec = audit_spec_for_test("catboost", "binary_classification"),
    seed = 1L
  )

  expect_identical(fit_res$status, "pass")
  expect_identical(list.files(tmp, all.files = TRUE, no.. = TRUE), character())
})
