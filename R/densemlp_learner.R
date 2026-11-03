# Registry wrappers around the published `densemlp` package.
#
# `densemlp` is a CRAN package that implements a dense feedforward network
# natively in C++ via RcppArmadillo. It
# backs two learners:
#
# * `densemlp` exposes the engine's full architecture options (residual
#   connections, gated blocks, feature interactions, moving-average weights,
#   learning-rate schedules, internal ensembles).
# * `mlp` is a plain multilayer perceptron preset on the same engine
#   (Linear -> ReLU blocks, Adam, standardized inputs, no batch
#   normalization by default). Arguments of the earlier `mlp`
#   implementation that have no densemlp equivalent are accepted and
#   ignored with a warning (see `.mlp_legacy_args()`).

# Arguments of the earlier `mlp` implementation, with the only value
# the densemlp engine reproduces. Any other value is ignored with a warning.
.mlp_legacy_args <- function() {
  list(
    activation = "relu",
    optimizer = "adam",
    weight_decay = 0,
    standardize = TRUE,
    device = c("auto", "cpu")
  )
}

.mlp_check_legacy_args <- function(spec) {
  legacy <- .mlp_legacy_args()
  ignored <- character()
  for (nm in intersect(names(spec), names(legacy))) {
    value <- spec[[nm]]
    if (is.null(value)) next
    ok <- length(value) == 1L && !is.na(value) && value %in% legacy[[nm]]
    if (!ok) {
      ignored <- c(ignored, sprintf("%s = %s", nm, paste(format(value), collapse = ", ")))
    }
  }
  if (length(ignored)) {
    warning(
      sprintf(
        paste0(
          "`mlp` now runs on the densemlp engine (ReLU activation, Adam, ",
          "standardized inputs, CPU) and ignores: %s."
        ),
        paste(ignored, collapse = "; ")
      ),
      call. = FALSE
    )
  }
  spec[names(legacy)] <- NULL
  spec
}

.mlp_fit <- function(X, y, spec, task, levels, ...) {
  spec <- .mlp_check_legacy_args(spec)
  spec$batch_norm <- spec$batch_norm %||% FALSE
  .densemlp_fit(X = X, y = y, spec = spec, task = task, levels = levels)
}

.densemlp_fit <- function(X, y, spec, task, levels, ...) {
  assert_package("densemlp", "densemlp")

  densemlp_task <- if (identical(task, "regression")) {
    "regression"
  } else if (length(levels) > 2L) {
    "multiclass"
  } else {
    "binary"
  }

  fit <- densemlp::densemlp(
    x = X,
    y = y,
    task = densemlp_task,
    hidden_units = spec$hidden_units %||% c(64L, 32L),
    dropout = spec$dropout %||% 0,
    residual = spec$residual %||% FALSE,
    gated = spec$gated %||% FALSE,
    batch_norm = spec$batch_norm %||% TRUE,
    input_projection = spec$input_projection %||% NULL,
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

.densemlp_predict <- function(state, Xnew, type, levels, ...) {
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
