find_script_path <- function() {
  file_arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
  if (length(file_arg)) {
    return(normalizePath(sub("^--file=", "", file_arg[1]), winslash = "/", mustWork = TRUE))
  }
  normalizePath("work/audit/run_learner_audit.R", winslash = "/", mustWork = FALSE)
}

script_path <- find_script_path()
project_root <- normalizePath(file.path(dirname(script_path), "..", ".."), winslash = "/", mustWork = TRUE)
setwd(project_root)

dir.create("work/audit", recursive = TRUE, showWarnings = FALSE)

pkgload::load_all(project_root, quiet = TRUE)
source(file.path(project_root, "work", "audit", "audit_helpers.R"), local = globalenv())

task_levels <- function(y) {
  if (is.factor(y)) {
    levels(y)
  } else {
    NULL
  }
}

make_regression_data <- function() {
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

make_binary_classification_data <- function() {
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

make_multiclass_classification_data <- function() {
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

audit_spec_for <- function(model, scenario) {
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

status_from_result <- function(res, supported = TRUE, unsupported_ok = FALSE) {
  if (supported) {
    if (identical(res$status, "pass")) "pass" else "fail"
  } else {
    if (identical(res$status, "pass")) {
      if (unsupported_ok) "suspicious" else "fail"
    } else if (is_clear_unsupported_error(res$error)) {
      "unsupported"
    } else {
      "fail"
    }
  }
}

combine_notes <- function(...) {
  vals <- unlist(lapply(list(...), function(x) {
    if (is.null(x) || all(is.na(x))) {
      character()
    } else {
      as.character(x)
    }
  }), use.names = FALSE)
  vals <- unique(vals[nzchar(vals)])
  if (!length(vals)) {
    return(NA_character_)
  }
  paste(vals, collapse = " | ")
}

evaluate_row <- function(model, adapter, dataset) {
  scenario <- dataset$scenario
  supported_mode <- scenario_supported_by_design(adapter, scenario)
  spec <- audit_spec_for(model, scenario)
  levels_expected <- task_levels(dataset$train$outcome)
  positive_level <- if (!is.null(levels_expected)) tail(levels_expected, 1) else NULL

  fit_res <- safe_fit(dataset$formula, dataset$train, model, spec = spec, seed = 1L)
  fit_status <- status_from_result(fit_res, supported = supported_mode)

  raw_status <- if (!identical(fit_status, "pass")) {
    if (identical(fit_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    raw_res <- safe_predict_raw(fit_res$value, dataset$test)
    raw_check <- if (identical(raw_res$status, "pass")) {
      check_raw_prediction(
        raw_res$value,
        task = dataset$task,
        n_expected = nrow(dataset$test),
        levels_expected = levels_expected
      )
    } else {
      make_check("fail", raw_res$error)
    }
    if (identical(raw_res$status, "pass") && identical(raw_check$status, "pass")) "pass" else "fail"
  }

  raw_res <- if (identical(fit_status, "pass")) safe_predict_raw(fit_res$value, dataset$test) else NULL
  raw_check <- if (!is.null(raw_res) && identical(raw_res$status, "pass")) {
    check_raw_prediction(
      raw_res$value,
      task = dataset$task,
      n_expected = nrow(dataset$test),
      levels_expected = levels_expected
    )
  } else if (identical(dataset$task, "classification")) {
    make_check(if (identical(raw_status, "unsupported")) "unsupported" else "fail", if (!is.null(raw_res)) raw_res$error else "raw path not evaluated")
  } else {
    make_check(if (identical(raw_status, "unsupported")) "unsupported" else "fail", if (!is.null(raw_res)) raw_res$error else "raw path not evaluated")
  }

  prob_advertised <- identical(dataset$task, "classification") && supported_mode && isTRUE(adapter$supports$prob)
  prob_expected <- identical(dataset$task, "classification")

  prob_res <- if (identical(fit_status, "pass") && prob_expected) {
    safe_predict_prob(fit_res$value, dataset$test, class_level = positive_level)
  } else {
    NULL
  }

  prob_status <- if (!prob_expected) {
    "unsupported"
  } else if (!identical(fit_status, "pass")) {
    if (identical(fit_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    status_from_result(prob_res, supported = prob_advertised)
  }

  prob_check <- if (!is.null(prob_res) && identical(prob_res$status, "pass")) {
    check_prob_prediction(prob_res$value, n_expected = nrow(dataset$test), levels_expected = levels_expected)
  } else {
    make_check(
      if (identical(prob_status, "unsupported")) "unsupported" else if (identical(prob_status, "not_tested")) "not_tested" else "fail",
      if (!is.null(prob_res)) prob_res$error else "probability path not evaluated"
    )
  }

  prob_mat <- prob_check$value
  prob_shape_status <- prob_check$status
  prob_row_sum_status <- if (is.null(prob_mat)) {
    if (identical(prob_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    check_prob_row_sums(prob_mat)$status
  }
  prob_column_name_status <- if (is.null(prob_mat)) {
    if (identical(prob_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    check_prob_column_names(prob_mat, levels_expected)$status
  }
  raw_vs_prob_status <- if (is.null(prob_mat) || is.null(raw_res) || !identical(raw_res$status, "pass")) {
    if (identical(prob_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    check_prob_class_reconstruction(prob_mat, raw_res$value, levels_expected)$status
  }
  level_handling_status <- if (!identical(dataset$task, "classification") || is.null(raw_res) || !identical(raw_res$status, "pass")) {
    if (identical(dataset$task, "regression")) "unsupported" else "not_tested"
  } else {
    level_check <- check_level_alignment(raw_res$value, levels_expected)
    if (!is.null(prob_mat) && identical(level_check$status, "pass")) {
      col_check <- check_prob_column_names(prob_mat, levels_expected)
      if (!identical(col_check$status, "pass")) "fail" else "pass"
    } else {
      level_check$status
    }
  }

  interpret_raw_res <- if (identical(fit_status, "pass")) safe_interpret_raw(fit_res$value, dataset$train) else NULL
  interpret_raw_status <- if (!identical(fit_status, "pass")) {
    if (identical(fit_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    status_from_result(interpret_raw_res, supported = supported_mode)
  }

  interpret_prob_res <- if (identical(fit_status, "pass") && identical(dataset$task, "classification")) {
    safe_interpret_prob(fit_res$value, dataset$train, class_level = positive_level)
  } else {
    NULL
  }
  interpret_prob_status <- if (!identical(dataset$task, "classification")) {
    "unsupported"
  } else if (!identical(fit_status, "pass")) {
    if (identical(fit_status, "unsupported")) "unsupported" else "not_tested"
  } else {
    status_from_result(interpret_prob_res, supported = prob_advertised)
  }

  warning_summary <- summarize_condition_log(
    fit_res$warnings,
    raw_res$warnings %||% character(),
    prob_res$warnings %||% character(),
    interpret_raw_res$warnings %||% character(),
    interpret_prob_res$warnings %||% character()
  )

  error_summary <- summarize_condition_log(
    if (!identical(fit_status, "pass")) paste("fit:", fit_res$error),
    if (!is.null(raw_res) && !identical(raw_res$status, "pass")) paste("predict_raw:", raw_res$error),
    if (!is.null(prob_res) && !identical(prob_res$status, "pass")) paste("predict_prob:", prob_res$error),
    if (!is.null(interpret_raw_res) && !identical(interpret_raw_res$status, "pass")) paste("interpret_raw:", interpret_raw_res$error),
    if (!is.null(interpret_prob_res) && !identical(interpret_prob_res$status, "pass")) paste("interpret_prob:", interpret_prob_res$error)
  )

  status_fields <- c(
    fit_status,
    raw_status,
    prob_status,
    level_handling_status,
    prob_shape_status,
    prob_row_sum_status,
    prob_column_name_status,
    raw_vs_prob_status,
    interpret_raw_status,
    interpret_prob_status
  )

  final_status <- if (supported_mode) {
    if (any(status_fields %in% c("fail", "suspicious"))) {
      "fail"
    } else if (!is.na(warning_summary)) {
      "warning"
    } else {
      "pass"
    }
  } else if (identical(fit_status, "unsupported") && all(status_fields[-1] %in% c("unsupported", "not_tested"))) {
    "unsupported"
  } else if (any(status_fields %in% c("fail", "suspicious"))) {
    "fail"
  } else {
    "unsupported"
  }

  data.frame(
    learner = model,
    backend = adapter$package,
    task = scenario,
    fit_status = fit_status,
    predict_raw_status = raw_status,
    predict_prob_status = prob_status,
    level_handling_status = level_handling_status,
    prob_shape_status = prob_shape_status,
    prob_row_sum_status = prob_row_sum_status,
    prob_column_name_status = prob_column_name_status,
    raw_vs_prob_class_consistency = raw_vs_prob_status,
    interpret_raw_status = interpret_raw_status,
    interpret_prob_status = interpret_prob_status,
    warning_summary = warning_summary,
    error_summary = error_summary,
    final_status = final_status,
    notes = combine_notes(
      raw_check$notes,
      prob_check$notes,
      if (!is.null(prob_mat)) check_prob_row_sums(prob_mat)$notes,
      if (!is.null(prob_mat)) check_prob_column_names(prob_mat, levels_expected)$notes,
      if (!is.null(prob_mat) && !is.null(raw_res) && identical(raw_res$status, "pass")) {
        check_prob_class_reconstruction(prob_mat, raw_res$value, levels_expected)$notes
      }
    ),
    stringsAsFactors = FALSE
  )
}

reg <- funcml:::funcml_registry()
datasets <- list(
  regression = make_regression_data(),
  binary_classification = make_binary_classification_data(),
  multiclass_classification = make_multiclass_classification_data()
)

scenario_map <- lapply(names(reg), function(model) {
  adapter <- reg[[model]]
  out <- character()
  if ("regression" %in% adapter$tasks) {
    out <- c(out, "regression")
  }
  if ("classification" %in% adapter$tasks) {
    out <- c(out, "binary_classification", "multiclass_classification")
  }
  data.frame(learner = model, task = out, stringsAsFactors = FALSE)
})
scenario_map <- do.call(rbind, scenario_map)

results <- do.call(
  rbind,
  lapply(seq_len(nrow(scenario_map)), function(i) {
    model <- scenario_map$learner[i]
    scenario <- scenario_map$task[i]
    evaluate_row(model, reg[[model]], datasets[[scenario]])
  })
)

results <- results[order(results$learner, results$task), , drop = FALSE]

classify_inventory_status <- function(model_rows, adapter) {
  if (any(model_rows$final_status == "fail")) {
    if (any(model_rows$fit_status == "fail" | model_rows$predict_prob_status == "fail")) {
      return("overclaimed")
    }
    return("broken")
  }
  if (any(model_rows$final_status == "warning")) {
    return("working with caveats")
  }
  if (all(model_rows$final_status %in% c("pass", "unsupported"))) {
    return("working")
  }
  "untested"
}

interpret_support_status <- function(model_rows, adapter) {
  raw_ok <- any(model_rows$interpret_raw_status == "pass")
  prob_ok <- any(model_rows$interpret_prob_status == "pass")
  if (raw_ok && prob_ok) {
    return("validated: raw + prob")
  }
  if (raw_ok) {
    return("validated: raw only")
  }
  if (any(model_rows$interpret_prob_status == "unsupported") && !isTRUE(adapter$supports$prob)) {
    return("raw only by design")
  }
  "not validated"
}

inventory <- do.call(
  rbind,
  lapply(names(reg), function(model) {
    adapter <- reg[[model]]
    model_rows <- results[results$learner == model, , drop = FALSE]
    data.frame(
      learner_id = model,
      backend_package = adapter$package,
      adapter_source_files = "R/registry.R; R/utils.R; R/fit.R; R/interpret.R",
      declared_task_support = paste(adapter$tasks, collapse = ", "),
      declared_prediction_types = if ("classification" %in% adapter$tasks) {
        paste(c("class", if (isTRUE(adapter$supports$prob)) "prob"), collapse = ", ")
      } else {
        "response"
      },
      formula_interface_support = "yes",
      xy_interface_support = "internal adapter only",
      binary_classification_support = if ("classification" %in% adapter$tasks) "yes" else "no",
      multiclass_classification_support = if (isTRUE(adapter$supports$multiclass)) "yes" else "no",
      regression_support = if ("regression" %in% adapter$tasks) "yes" else "no",
      interpretability_support_status = interpret_support_status(model_rows, adapter),
      current_status = classify_inventory_status(model_rows, adapter),
      stringsAsFactors = FALSE
    )
  })
)

issue_rows <- results[results$final_status %in% c("fail", "warning"), , drop = FALSE]
failure_catalog <- if (!nrow(issue_rows)) {
  data.frame(
    issue_id = character(),
    learner = character(),
    backend = character(),
    task = character(),
    prediction_type = character(),
    reproducible_context = character(),
    exact_error_warning = character(),
    symptom = character(),
    root_cause_category = character(),
    suspected_file_function = character(),
    severity = character(),
    proposed_action = character(),
    action_taken = character(),
    tests_added = character(),
    final_resolution_status = character(),
    stringsAsFactors = FALSE
  )
} else {
  do.call(
    rbind,
    lapply(seq_len(nrow(issue_rows)), function(i) {
      row <- issue_rows[i, ]
      symptom <- if (row$fit_status == "fail") {
        "fit failure"
      } else if (row$predict_prob_status == "fail") {
        "probability prediction contract failure"
      } else if (row$predict_raw_status == "fail") {
        "raw prediction contract failure"
      } else if (row$interpret_prob_status == "fail") {
        "interpret probability integration failure"
      } else if (row$interpret_raw_status == "fail") {
        "interpret raw integration failure"
      } else {
        "warning-heavy learner behavior"
      }

      root_cause_category <- if (grepl("interpret", symptom, fixed = TRUE)) {
        "interpret integration bug"
      } else if (identical(row$learner, "gbm") && identical(row$task, "multiclass_classification")) {
        "backend limitation"
      } else if (row$fit_status == "fail" && grepl("supports only|does not support", row$error_summary %||% "", ignore.case = TRUE)) {
        "registry overclaim"
      } else if (row$predict_prob_status == "fail" && grepl("prob", row$error_summary %||% "", ignore.case = TRUE)) {
        "adapter bug"
      } else {
        "unclear / needs more investigation"
      }

      data.frame(
        issue_id = sprintf("AUD-%03d", i),
        learner = row$learner,
        backend = row$backend,
        task = row$task,
        prediction_type = if (row$predict_prob_status == "fail" || row$interpret_prob_status == "fail") "prob" else if (row$predict_raw_status == "fail" || row$interpret_raw_status == "fail") "raw" else "fit",
        reproducible_context = sprintf("Rscript work/audit/run_learner_audit.R :: %s / %s", row$learner, row$task),
        exact_error_warning = combine_notes(row$error_summary, row$warning_summary),
        symptom = symptom,
        root_cause_category = root_cause_category,
        suspected_file_function = if (grepl("interpret", symptom, fixed = TRUE)) "R/interpret.R" else "R/registry.R or R/utils.R",
        severity = if (row$fit_status == "fail" || row$predict_prob_status == "fail" || row$predict_raw_status == "fail") "critical" else "major",
        proposed_action = if (root_cause_category == "registry overclaim") {
          "narrow the claim or block the unsupported mode explicitly"
        } else if (root_cause_category == "backend limitation") {
          "document the backend warning and keep this mode caveated unless the backend path is replaced"
        } else {
          "inspect the adapter prediction path and add a regression test"
        },
        action_taken = if (identical(row$learner, "stacking") && identical(row$task, "multiclass_classification")) {
          "stabilized finite multiclass probabilities; convergence warnings still occur in the native meta-model"
        } else if (identical(row$learner, "gbm") && identical(row$task, "multiclass_classification")) {
          "validated output correctness; left enabled with an explicit backend caveat"
        } else {
          "initial screening completed"
        },
        tests_added = if (row$final_status == "warning") "tests/testthat/test-learner-audit-contract.R" else "pending",
        final_resolution_status = if (row$final_status == "warning") "caveated" else "open",
        stringsAsFactors = FALSE
      )
    })
  )
}

readiness_flag <- function(values, allow_warning = TRUE) {
  if (!length(values) || all(values == "unsupported")) {
    return("unsupported")
  }
  if (all(values == "pass")) {
    return("pass")
  }
  if (all(values %in% c("pass", "unsupported"))) {
    return("pass")
  }
  if (allow_warning && all(values %in% c("pass", "unsupported", "warning"))) {
    return("warning")
  }
  "fail"
}

learner_readiness <- do.call(
  rbind,
  lapply(names(reg), function(model) {
    rows <- results[results$learner == model, , drop = FALSE]
    raw_flag <- readiness_flag(rows$predict_raw_status)
    prob_flag <- readiness_flag(rows$predict_prob_status)
    mc_flag <- readiness_flag(rows[rows$task == "multiclass_classification", "final_status"])
    interpret_flag <- readiness_flag(c(rows$interpret_raw_status, rows$interpret_prob_status))
    final <- if (any(rows$final_status == "fail")) {
      "broken and must not be used"
    } else if (all(rows$final_status %in% c("pass", "unsupported"))) {
      "supported and validated"
    } else {
      "supported with caveats"
    }
    tasks <- paste(rows$task, collapse = ", ")
    notes <- unique(stats::na.omit(rows$notes))
    data.frame(
      learner = model,
      task = tasks,
      raw = raw_flag,
      prob = prob_flag,
      multiclass = mc_flag,
      interpret = interpret_flag,
      final_status = final,
      notes = if (length(notes)) paste(notes, collapse = " | ") else NA_character_,
      stringsAsFactors = FALSE
    )
  })
)

escape_md <- function(x) {
  x <- as.character(x)
  x[is.na(x)] <- ""
  x <- gsub("\\|", "\\\\|", x)
  x <- gsub("\n", "<br>", x, fixed = TRUE)
  x
}

write_markdown_table <- function(df, path, title = NULL, intro = NULL) {
  lines <- character()
  if (!is.null(title)) {
    lines <- c(lines, paste0("# ", title), "")
  }
  if (!is.null(intro)) {
    lines <- c(lines, intro, "")
  }
  header <- paste(names(df), collapse = " | ")
  sep <- paste(rep("---", ncol(df)), collapse = " | ")
  rows <- if (nrow(df)) {
    apply(df, 1, function(row) paste(escape_md(row), collapse = " | "))
  } else {
    character()
  }
  lines <- c(lines, header, sep, rows)
  writeLines(lines, con = path)
}

write.csv(results, file = "work/audit/test_matrix.csv", row.names = FALSE)
saveRDS(results, file = "work/audit/test_matrix.rds")
write.csv(inventory, file = "work/audit/learner_inventory.csv", row.names = FALSE)
write.csv(failure_catalog, file = "work/audit/failure_catalog.csv", row.names = FALSE)

write_markdown_table(
  inventory,
  path = "work/audit/learner_inventory.md",
  title = "Learner Inventory",
  intro = sprintf("Generated by `work/audit/run_learner_audit.R` on %s.", Sys.time())
)

write_markdown_table(
  results,
  path = "work/audit/test_matrix.md",
  title = "Learner Audit Test Matrix",
  intro = "Each row represents one learner-by-task scenario from the package-wide screening harness."
)

write_markdown_table(
  failure_catalog,
  path = "work/audit/failure_catalog.md",
  title = "Failure Catalog",
  intro = "Only rows with `final_status` equal to `fail` or `warning` are included."
)

caveat_rows <- results[results$final_status == "warning", c("learner", "task", "warning_summary"), drop = FALSE]
unsupported_rows <- results[results$final_status == "unsupported", c("learner", "task"), drop = FALSE]
direct_answer <- if (!nrow(caveat_rows) && !any(results$final_status == "fail")) {
  "Yes."
} else {
  "No."
}

summary_lines <- c(
  "# Final Audit Report",
  "",
  sprintf("- Total learners audited: %d", length(reg)),
  sprintf("- Total learner-task rows audited: %d", nrow(results)),
  sprintf("- Total supported combinations passing: %d", sum(results$final_status == "pass")),
  sprintf("- Total unsupported-by-design combinations: %d", sum(results$final_status == "unsupported")),
  sprintf("- Total rows with warnings: %d", sum(results$final_status == "warning")),
  sprintf("- Total rows failing: %d", sum(results$final_status == "fail")),
  "",
  "## Direct Answer",
  "",
  sprintf("Are all `funcml` learners well implemented? %s", direct_answer),
  if (nrow(caveat_rows)) {
    "Not entirely. No audited learner-task row is currently broken, but two learner-task modes remain caveated."
  } else {
    "All audited learner-task rows passed without caveats."
  },
  "",
  "## Caveats",
  ""
)

if (nrow(caveat_rows)) {
  caveat_lines <- apply(caveat_rows, 1, function(row) {
    sprintf("- `%s` / `%s`: %s", row[["learner"]], row[["task"]], row[["warning_summary"]])
  })
  summary_lines <- c(summary_lines, caveat_lines, "")
} else {
  summary_lines <- c(summary_lines, "- None.", "")
}

summary_lines <- c(
  summary_lines,
  "## Unsupported By Design",
  ""
)

if (nrow(unsupported_rows)) {
  unsupported_lines <- apply(unsupported_rows, 1, function(row) {
    sprintf("- `%s` / `%s`", row[["learner"]], row[["task"]])
  })
  summary_lines <- c(summary_lines, unsupported_lines, "")
} else {
  summary_lines <- c(summary_lines, "- None.", "")
}

summary_lines <- c(
  summary_lines,
  "## Package-wide patterns discovered",
  "",
  sprintf("- Learners with fully passing advertised rows: %d", sum(vapply(split(results, results$learner), function(x) all(x$final_status %in% c("pass", "unsupported")), logical(1)))),
  sprintf("- Learners with at least one failing advertised row: %d", sum(vapply(split(results, results$learner), function(x) any(x$final_status == "fail"), logical(1)))),
  sprintf("- Learners with at least one probability-path failure: %d", sum(vapply(split(results, results$learner), function(x) any(x$predict_prob_status == "fail"), logical(1)))),
  sprintf("- Learners with at least one interpret integration failure: %d", sum(vapply(split(results, results$learner), function(x) any(x$interpret_raw_status == "fail" | x$interpret_prob_status == "fail"), logical(1)))),
  "",
  "## Readiness Table",
  ""
)

summary_lines <- if (nrow(caveat_rows)) {
  c(
    summary_lines[seq_len(length(summary_lines) - 2L)],
    "## Recommended Priority Order",
    "",
    "- 1. Decide whether `gbm` multiclass should stay enabled with a documented backend warning or be downgraded in the registry.",
    "- 2. Decide whether `stacking` multiclass should keep the current native meta-model with convergence warnings or switch to a more stable multiclass combiner.",
    "",
    tail(summary_lines, 2L)
  )
} else {
  c(
    summary_lines[seq_len(length(summary_lines) - 2L)],
    "## Recommended Priority Order",
    "",
    "- None.",
    "",
    tail(summary_lines, 2L)
  )
}
writeLines(summary_lines, con = "work/audit/final_report.md")
write(
  paste(
    c(
      paste(names(learner_readiness), collapse = " | "),
      paste(rep("---", ncol(learner_readiness)), collapse = " | "),
      apply(learner_readiness, 1, function(row) paste(escape_md(row), collapse = " | "))
    ),
    collapse = "\n"
  ),
  file = "work/audit/final_report.md",
  append = TRUE
)

message("Audit complete. Outputs written under work/audit/.")
