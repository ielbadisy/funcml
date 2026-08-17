# Registry wrapper around the published `densemlp` package.
#
# funcml also ships a lightweight, dependency-free MLP (`mlp`, see
# mlp_internal.R). `densemlp` is a separate CRAN package with richer
# architecture options (residual connections, gated blocks, input
# projection, focal loss, LR schedules) and is wired in here as an
# additional learner rather than a replacement.

.densemlp_fit <- function(X, y, spec, task, levels, ...) {
  assert_package("densemlp", "densemlp")

  densemlp_task <- if (identical(task, "regression")) "regression" else "classification"

  fit <- densemlp::densemlp(
    x = X,
    y = y,
    task = densemlp_task,
    hidden_units = spec$hidden_units %||% c(64L, 32L),
    activation = spec$activation %||% "relu",
    dropout = spec$dropout %||% 0,
    batch_norm = spec$batch_norm %||% TRUE,
    residual = spec$residual %||% FALSE,
    gated = spec$gated %||% FALSE,
    input_projection = spec$input_projection %||% NULL,
    epochs = spec$epochs %||% 100L,
    batch_size = spec$batch_size %||% 32L,
    lr = spec$lr %||% 1e-3,
    optimizer = spec$optimizer %||% "adam",
    lr_schedule = spec$lr_schedule %||% "none",
    weight_decay = spec$weight_decay %||% 0,
    validation = spec$validation %||% 0.2,
    early_stopping = spec$early_stopping %||% TRUE,
    patience = spec$patience %||% 10L,
    min_delta = spec$min_delta %||% 0,
    loss = spec$loss %||% NULL,
    label_smoothing = spec$label_smoothing %||% 0,
    focal_gamma = spec$focal_gamma %||% 2,
    seed = spec$seed %||% 1L,
    verbose = isTRUE(spec$verbose %||% FALSE),
    device = spec$device %||% "auto"
  )

  list(state = fit, task = task, levels = levels)
}

.densemlp_predict <- function(state, Xnew, type, levels, ...) {
  fit <- state$state

  if (identical(state$task, "regression")) {
    return(as.numeric(predict(fit, new_data = Xnew, type = "response")))
  }

  if (identical(type, "class")) {
    pred <- predict(fit, new_data = Xnew, type = "class")
    return(factor(as.character(pred), levels = levels))
  }

  prob <- predict(fit, new_data = Xnew, type = "prob")
  out <- matrix(0, nrow = nrow(prob), ncol = length(levels), dimnames = list(NULL, levels))
  common <- intersect(colnames(prob), levels)
  out[, common] <- prob[, common, drop = FALSE]
  out
}
