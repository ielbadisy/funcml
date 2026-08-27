# Registry wrapper around the `dmlp` package.
#
# funcml also ships a lightweight, dependency-free MLP (`mlp`, see
# mlp_internal.R). `dmlp` is a separate package with richer architecture
# options (residual connections, gated blocks, dropout, feature
# interactions, moving-average weights, LR schedules, internal ensembles)
# implemented natively in C++ via RcppArmadillo (no `torch`/`libtorch`
# dependency), and is wired in here as an additional learner rather than a
# replacement. Replaces the former `densemlp` learner (torch-backed).

.dmlp_fit <- function(X, y, spec, task, levels, ...) {
  assert_package("dmlp", "dmlp")

  dmlp_task <- if (identical(task, "regression")) {
    "regression"
  } else if (length(levels) > 2L) {
    "multiclass"
  } else {
    "binary"
  }

  fit <- dmlp::dmlp(
    x = X,
    y = y,
    task = dmlp_task,
    hidden_units = spec$hidden_units %||% c(64L, 32L),
    dropout = spec$dropout %||% 0,
    residual = spec$residual %||% FALSE,
    gated = spec$gated %||% FALSE,
    interaction = spec$interaction %||% FALSE,
    ema_decay = spec$ema_decay %||% 0,
    ensemble = spec$ensemble %||% 1L,
    ensemble_bootstrap = spec$ensemble_bootstrap %||% TRUE,
    epochs = spec$epochs %||% 100L,
    batch_size = spec$batch_size %||% 32L,
    lr = spec$lr %||% 1e-3,
    lr_schedule = spec$lr_schedule %||% "none",
    validation = spec$validation %||% 0.2,
    early_stopping = spec$early_stopping %||% TRUE,
    patience = spec$patience %||% 10L,
    min_delta = spec$min_delta %||% 0,
    seed = spec$seed %||% 1L,
    verbose = isTRUE(spec$verbose %||% FALSE),
    ncores = spec$ncores %||% 1L
  )

  list(state = fit, task = task, levels = levels)
}

.dmlp_predict <- function(state, Xnew, type, levels, ...) {
  fit <- state$state

  if (identical(state$task, "regression")) {
    return(as.numeric(predict(fit, newdata = Xnew, type = "response")))
  }

  if (identical(type, "class")) {
    pred <- predict(fit, newdata = Xnew, type = "class")
    return(factor(as.character(pred), levels = levels))
  }

  prob <- predict(fit, newdata = Xnew, type = "prob")
  out <- matrix(0, nrow = nrow(prob), ncol = length(levels), dimnames = list(NULL, levels))
  common <- intersect(colnames(prob), levels)
  out[, common] <- prob[, common, drop = FALSE]
  out
}
