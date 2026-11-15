#' Bootstrap validation: optimism correction, .632 and .632+.
#'
#' Internal validation of a learner by the bootstrap. Each of the `B`
#' replicates draws `n` rows with replacement, fits the learner on them, and
#' scores the fit on three sets of rows: the bootstrap sample itself, the
#' original data, and the out-of-bag (OOB) rows not drawn.
#'
#' With `app` the apparent performance (the learner fitted and scored on all
#' rows), the returned estimates are:
#'
#' * Optimism correction (Harrell, Lee and Mark 1996), as in
#'   `rms::validate()`: `optimism = mean_b(boot_b - orig_b)` and
#'   `corrected = app - optimism`.
#' * Leave-one-out bootstrap `oob = mean_b(oob_b)`, the OOB metric averaged
#'   over replicates.
#' * `.632` (Efron 1983): `0.368 * app + 0.632 * oob`.
#' * `.632+` (Efron and Tibshirani 1997): `(1 - w) * app + w * oob'` with
#'   `w = 0.632 / (1 - 0.368 * R)`, relative overfitting rate
#'   `R = (oob' - app) / (gamma - app)` (set to 0 when `oob` is no worse than
#'   `app`, or `gamma` is no worse than `app`), and `oob'` the OOB value
#'   capped at `gamma`. The no-information value `gamma` is the metric
#'   computed on every pairing of an observed outcome with an apparent
#'   prediction (a random sample of 250,000 pairings when `n^2` exceeds
#'   that). Higher-is-better metrics (`auc`, `accuracy`, `rsq`, ...) are
#'   handled on the corresponding loss scale, so "worse" means lower.
#'
#' The OOB metric is computed per replicate and averaged, which for
#' non-additive metrics (`auc`, `ece`) is the usual approximation of the
#' per-observation leave-one-out bootstrap.
#'
#' @param data Data frame.
#' @param formula Model formula.
#' @param model Learner id.
#' @param spec Optional hyperparameter list.
#' @param B Number of bootstrap replicates.
#' @param metrics Character vector of metric names. Defaults to
#'   `c("rmse", "mse", "rsq")` for regression and
#'   `c("auc", "brier", "logloss", "accuracy")` for classification.
#' @param seed Optional seed for the bootstrap draws.
#' @param ncores Optional number of CPU cores for the replicates.
#' @param ... Passed to [fit()].
#' @return A `funcml_bootvalidate` object: a list with `summary` (one row
#'   per metric: `apparent`, `optimism`, `corrected`, `oob`, `est632`,
#'   `est632plus`, `gamma`, `n_boot`), `replicates` (one row per replicate
#'   and metric with the `boot`, `orig` and `oob` values), `indices` (the
#'   bootstrap row indices of each replicate), `n_failed`, `task` and
#'   `model`.
#' @references
#' Harrell FE, Lee KL, Mark DB (1996). Multivariable prognostic models.
#' Statistics in Medicine 15, 361-387.
#'
#' Efron B, Tibshirani R (1997). Improvements on cross-validation: the .632+
#' bootstrap method. Journal of the American Statistical Association 92,
#' 548-560.
#' @examples
#' bv <- bootvalidate(mtcars, mpg ~ wt + hp, model = "glm", B = 20, seed = 1)
#' bv
#' @export
bootvalidate <- function(data, formula, model, spec = NULL, B = 200,
                         metrics = NULL, seed = NULL, ncores = NULL, ...) {
  if (!is.numeric(B) || length(B) != 1L || !is.finite(B) || B < 2) {
    stop("`B` must be a single number of at least 2.", call. = FALSE)
  }
  B <- as.integer(B)
  ncores <- .validate_ncores(ncores)
  .check_no_missing_model_vars(
    formula, data,
    outcome_only = isTRUE(funcml_registry(model)$supports$na) && is.null(list(...)$na_action),
    caller = "bootvalidate"
  )
  y_all <- stats::model.response(stats::model.frame(formula, data, na.action = stats::na.pass))
  task <- infer_task(y_all)
  if (task == "classification") {
    y_all <- factor(y_all)
  }
  if (is.null(metrics)) {
    metrics <- if (task == "regression") c("rmse", "mse", "rsq") else c("auc", "brier", "logloss", "accuracy")
  }
  n <- nrow(data)

  if (!is.null(seed)) set.seed(seed)
  draw <- function() {
    repeat {
      idx <- sample.int(n, n, replace = TRUE)
      ok <- length(unique(idx)) < n
      if (task == "classification") {
        ok <- ok && all(table(y_all[idx]) > 0) && all(table(y_all[-unique(idx)]) > 0)
      }
      if (ok) return(idx)
    }
  }
  indices <- lapply(seq_len(B), function(b) draw())

  full_fit <- fit(formula, data, model, spec = spec, ...)
  app_scored <- .bv_score(full_fit, data, y_all, task, metrics)
  apparent <- app_scored$values
  gamma <- .bv_noinfo(y_all, app_scored, task, metrics)

  reps <- .funcml_map(seq_len(B), function(b) {
    idx <- indices[[b]]
    oob <- setdiff(seq_len(n), idx)
    boot_data <- data[idx, , drop = FALSE]
    fb <- tryCatch(fit(formula, boot_data, model, spec = spec, ...), error = function(e) NULL)
    if (is.null(fb)) {
      return(NULL)
    }
    data.frame(
      replicate = b,
      metric = metrics,
      boot = .bv_score(fb, boot_data, y_all[idx], task, metrics)$values,
      orig = .bv_score(fb, data, y_all, task, metrics)$values,
      oob = .bv_score(fb, data[oob, , drop = FALSE], y_all[oob], task, metrics)$values,
      stringsAsFactors = FALSE
    )
  }, ncores = ncores)
  n_failed <- sum(vapply(reps, is.null, logical(1)))
  replicates <- .rbind_dt(reps)
  if (!nrow(replicates)) {
    stop("All bootstrap fits failed.", call. = FALSE)
  }

  summary_df <- .rbind_dt(lapply(seq_along(metrics), function(j) {
    m <- metrics[j]
    r <- replicates[replicates$metric == m, , drop = FALSE]
    est <- .bv_estimates(apparent[j], r$boot, r$orig, r$oob, gamma[j], metric_direction(m))
    data.frame(metric = m, as.data.frame(as.list(est)), n_boot = nrow(r), stringsAsFactors = FALSE)
  }))

  out <- list(
    summary = summary_df,
    replicates = replicates,
    indices = indices,
    n_failed = n_failed,
    task = task,
    model = model,
    call = match.call()
  )
  class(out) <- "funcml_bootvalidate"
  out
}

#' @export
print.funcml_bootvalidate <- function(x, digits = 4L, ...) {
  cat(sprintf(
    "<funcml_bootvalidate> model: %s | task: %s | B = %d (failed: %d)\n",
    x$model, x$task, max(x$summary$n_boot), x$n_failed
  ))
  print(.round_numeric_df(x$summary, digits = digits))
  invisible(x)
}

# Score a fitted model on `newdata`; keeps the predictions for the
# no-information rate.
.bv_score <- function(fit_obj, newdata, truth, task, metrics) {
  prob_metrics <- c("logloss", "brier", "auc", "auc_weighted", "ece", "mce")
  if (task == "regression") {
    pred <- as.numeric(predict(fit_obj, newdata = newdata, type = "response"))
    vals <- vapply(metrics, function(m) .loss(truth, pred, task, m), numeric(1))
    return(list(values = unname(vals), pred = pred, prob = NULL))
  }
  if (any(metrics %in% prob_metrics)) {
    prob <- as.matrix(predict(fit_obj, newdata = newdata, type = "prob"))
    if (is.null(colnames(prob))) colnames(prob) <- fit_obj$levels
    pred <- factor(fit_obj$levels[max.col(prob, ties.method = "first")], levels = fit_obj$levels)
  } else {
    prob <- NULL
    pred <- factor(predict(fit_obj, newdata = newdata, type = "class"), levels = fit_obj$levels)
  }
  vals <- vapply(metrics, function(m) .loss(truth, pred, task, m, prob_matrix = prob), numeric(1))
  list(values = unname(vals), pred = pred, prob = prob)
}

# No-information value: the metric on outcomes paired with predictions at
# random (all n^2 pairings, or a random sample of them for large n).
.bv_noinfo <- function(truth, scored, task, metrics, max_pairs = 250000L) {
  n <- length(truth)
  if (as.numeric(n)^2 <= max_pairs) {
    i <- rep(seq_len(n), times = n)
    j <- rep(seq_len(n), each = n)
  } else {
    i <- sample.int(n, max_pairs, replace = TRUE)
    j <- sample.int(n, max_pairs, replace = TRUE)
  }
  prob <- if (is.null(scored$prob)) NULL else scored$prob[j, , drop = FALSE]
  vapply(metrics, function(m) {
    suppressWarnings(.loss(truth[i], scored$pred[j], task, m, prob_matrix = prob))
  }, numeric(1), USE.NAMES = FALSE)
}

.bv_estimates <- function(app, boot, orig, oob, gamma, direction) {
  optimism <- mean(boot - orig)
  oob_mean <- mean(oob)
  # .632+ on the loss scale (larger = worse).
  s <- if (identical(direction, "min")) 1 else -1
  a <- s * app
  e1 <- s * oob_mean
  g <- s * gamma
  e1p <- min(e1, g)
  R <- if (e1 > a && g > a) (e1p - a) / (g - a) else 0
  R <- min(max(R, 0), 1)
  w <- 0.632 / (1 - 0.368 * R)
  c(
    apparent = app,
    optimism = optimism,
    corrected = app - optimism,
    oob = oob_mean,
    est632 = 0.368 * app + 0.632 * oob_mean,
    est632plus = s * ((1 - w) * a + w * e1p),
    gamma = gamma
  )
}
