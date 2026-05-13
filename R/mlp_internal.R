# Internal torch-backed multilayer perceptron learner.

.mlp_activation_module <- function(activation) {
  activation <- match.arg(activation, c("relu", "tanh", "gelu"))
  switch(
    activation,
    relu = torch::nn_relu(),
    tanh = torch::nn_tanh(),
    gelu = torch::nn_gelu()
  )
}

.mlp_module_factory <- function() {
  torch::nn_module(
    "funcml_mlp_module",
    initialize = function(input_dim, hidden_units, output_dim, activation, dropout, batch_norm) {
      layers <- list()
      last_dim <- input_dim
      for (units in hidden_units) {
        layers[[length(layers) + 1L]] <- torch::nn_linear(last_dim, units)
        if (isTRUE(batch_norm)) {
          layers[[length(layers) + 1L]] <- torch::nn_batch_norm1d(units)
        }
        layers[[length(layers) + 1L]] <- .mlp_activation_module(activation)
        if (dropout > 0) {
          layers[[length(layers) + 1L]] <- torch::nn_dropout(p = dropout)
        }
        last_dim <- units
      }
      layers[[length(layers) + 1L]] <- torch::nn_linear(last_dim, output_dim)
      self$model <- do.call(torch::nn_sequential, layers)
    },
    forward = function(x) {
      self$model(x)
    }
  )
}

.mlp_normalize_hidden_units <- function(hidden_units) {
  if (is.null(hidden_units) || !length(hidden_units)) {
    return(integer())
  }
  hidden_units <- as.integer(hidden_units)
  if (any(!is.finite(hidden_units)) || any(hidden_units < 1L)) {
    stop("`hidden_units` must contain positive integers.", call. = FALSE)
  }
  hidden_units
}

.mlp_scale_train <- function(X, standardize = TRUE) {
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  if (!isTRUE(standardize)) {
    return(list(X = X, center = rep(0, ncol(X)), scale = rep(1, ncol(X))))
  }
  center <- colMeans(X)
  scale <- apply(X, 2L, stats::sd)
  center[!is.finite(center)] <- 0
  scale[!is.finite(scale) | scale == 0] <- 1
  list(
    X = sweep(sweep(X, 2L, center, FUN = "-"), 2L, scale, FUN = "/"),
    center = center,
    scale = scale
  )
}

.mlp_scale_new <- function(X, center, scale) {
  X <- as.matrix(X)
  storage.mode(X) <- "double"
  sweep(sweep(X, 2L, center, FUN = "-"), 2L, scale, FUN = "/")
}

.mlp_prepare_outcome <- function(y, task, levels = NULL) {
  if (identical(task, "regression")) {
    y <- as.numeric(y)
    center <- mean(y)
    scale <- stats::sd(y)
    if (!is.finite(center)) center <- 0
    if (!is.finite(scale) || scale == 0) scale <- 1
    return(list(
      y_train = (y - center) / scale,
      outcome_type = "numeric",
      center = center,
      scale = scale
    ))
  }

  if (is.null(levels)) {
    stop("MLP classification requires factor levels.", call. = FALSE)
  }
  list(
    y_train = as.integer(factor(y, levels = levels)),
    outcome_type = if (length(levels) == 2L) "binary" else "multiclass",
    center = NULL,
    scale = NULL
  )
}

.mlp_resolve_device <- function(device) {
  device <- match.arg(device, c("auto", "cpu", "cuda"))
  if (identical(device, "auto")) {
    if (isTRUE(torch::cuda_is_available())) "cuda" else "cpu"
  } else {
    device
  }
}

.mlp_build_optimizer <- function(optimizer, parameters, lr, weight_decay) {
  optimizer <- match.arg(optimizer, c("adam", "sgd"))
  if (identical(optimizer, "adam")) {
    torch::optim_adam(parameters, lr = lr, weight_decay = weight_decay)
  } else {
    torch::optim_sgd(parameters, lr = lr, weight_decay = weight_decay)
  }
}

.mlp_clone_state_dict <- function(model) {
  lapply(model$state_dict(), function(x) x$clone())
}

.mlp_validation_metric <- function(task, outcome_type, truth, logits) {
  if (identical(task, "regression")) {
    pred <- as.numeric(logits)
    return(-sqrt(mean((truth - pred)^2)))
  }
  if (identical(outcome_type, "binary")) {
    pred <- ifelse(stats::plogis(as.numeric(logits)) >= 0.5, 2L, 1L)
    return(mean(pred == truth))
  }
  mean(max.col(logits, ties.method = "first") == truth)
}

.mlp_fit_torch <- function(X, y, task, levels, spec) {
  assert_package("torch", "mlp")

  if (ncol(X) < 1L) {
    stop("MLP requires at least one predictor.", call. = FALSE)
  }

  hidden_units <- .mlp_normalize_hidden_units(spec$hidden_units)
  activation <- match.arg(spec$activation %||% "relu", c("relu", "tanh", "gelu"))
  optimizer <- match.arg(spec$optimizer %||% "adam", c("adam", "sgd"))
  device <- .mlp_resolve_device(spec$device %||% "auto")
  epochs <- as.integer(spec$epochs %||% 100L)
  batch_size <- as.integer(spec$batch_size %||% 32L)
  validation <- spec$validation %||% 0.2
  if (epochs < 1L || batch_size < 1L) {
    stop("`epochs` and `batch_size` must be positive integers.", call. = FALSE)
  }
  if (!is.numeric(validation) || length(validation) != 1L || validation < 0 || validation >= 1) {
    stop("`validation` must be a number in [0, 1).", call. = FALSE)
  }

  scaled <- .mlp_scale_train(X, standardize = spec$standardize %||% TRUE)
  outcome <- .mlp_prepare_outcome(y, task = task, levels = levels)
  x <- scaled$X
  y_train_raw <- outcome$y_train
  n <- nrow(x)

  set.seed(spec$seed %||% sample.int(.Machine$integer.max, 1L))
  valid_n <- floor(n * validation)
  if (valid_n > 0L && valid_n >= n) {
    valid_n <- n - 1L
  }
  idx <- sample.int(n)
  valid_idx <- if (valid_n > 0L) idx[seq_len(valid_n)] else idx
  train_idx <- if (valid_n > 0L) idx[-seq_len(valid_n)] else idx

  torch::torch_manual_seed(spec$seed %||% 1L)
  x_train <- torch::torch_tensor(x[train_idx, , drop = FALSE], dtype = torch::torch_float(), device = device)
  x_valid <- torch::torch_tensor(x[valid_idx, , drop = FALSE], dtype = torch::torch_float(), device = device)

  if (identical(task, "regression")) {
    y_train <- torch::torch_tensor(matrix(y_train_raw[train_idx], ncol = 1L), dtype = torch::torch_float(), device = device)
    y_valid <- torch::torch_tensor(matrix(y_train_raw[valid_idx], ncol = 1L), dtype = torch::torch_float(), device = device)
    criterion <- torch::nn_mse_loss()
    output_dim <- 1L
  } else if (identical(outcome$outcome_type, "binary")) {
    y_train <- torch::torch_tensor(matrix(y_train_raw[train_idx] - 1L, ncol = 1L), dtype = torch::torch_float(), device = device)
    y_valid <- torch::torch_tensor(matrix(y_train_raw[valid_idx] - 1L, ncol = 1L), dtype = torch::torch_float(), device = device)
    criterion <- torch::nn_bce_with_logits_loss()
    output_dim <- 1L
  } else {
    y_train <- torch::torch_tensor(y_train_raw[train_idx], dtype = torch::torch_long(), device = device)
    y_valid <- torch::torch_tensor(y_train_raw[valid_idx], dtype = torch::torch_long(), device = device)
    criterion <- torch::nn_cross_entropy_loss()
    output_dim <- length(levels)
  }

  module <- .mlp_module_factory()
  model <- module(
    input_dim = ncol(x),
    hidden_units = hidden_units,
    output_dim = output_dim,
    activation = activation,
    dropout = spec$dropout %||% 0,
    batch_norm = spec$batch_norm %||% FALSE
  )
  model$to(device = device)
  opt <- .mlp_build_optimizer(optimizer, model$parameters, spec$lr %||% 1e-3, spec$weight_decay %||% 0)

  best_loss <- Inf
  best_metric <- -Inf
  best_epoch <- 1L
  best_state <- NULL
  wait <- 0L
  history <- vector("list", epochs)
  early_stopping <- spec$early_stopping %||% TRUE
  patience <- as.integer(spec$patience %||% 10L)
  min_delta <- spec$min_delta %||% 0

  for (epoch in seq_len(epochs)) {
    model$train()
    order <- sample.int(length(train_idx))
    batches <- split(order, ceiling(seq_along(order) / batch_size))
    train_losses <- numeric(length(batches))

    for (i in seq_along(batches)) {
      batch_ids <- batches[[i]]
      opt$zero_grad()
      logits <- model(x_train[batch_ids, ])
      batch_y <- if (identical(task, "regression") || identical(outcome$outcome_type, "binary")) {
        y_train[batch_ids, ]
      } else {
        y_train[batch_ids]
      }
      loss <- criterion(logits, batch_y)
      loss$backward()
      opt$step()
      train_losses[[i]] <- as.numeric(loss$item())
    }

    model$eval()
    torch::with_no_grad({
      valid_logits <- model(x_valid)
      valid_loss <- as.numeric(criterion(valid_logits, y_valid)$item())
      valid_logits_cpu <- as.array(valid_logits$to(device = "cpu"))
      valid_metric <- .mlp_validation_metric(task, outcome$outcome_type, y_train_raw[valid_idx], valid_logits_cpu)
      history[[epoch]] <- data.frame(
        epoch = epoch,
        train_loss = mean(train_losses),
        valid_loss = valid_loss,
        valid_metric = valid_metric
      )
      if (valid_loss < best_loss - min_delta) {
        best_loss <- valid_loss
        best_metric <- valid_metric
        best_epoch <- epoch
        best_state <- .mlp_clone_state_dict(model)
        wait <- 0L
      } else {
        wait <- wait + 1L
      }
    })

    if (isTRUE(spec$verbose %||% FALSE)) {
      message(sprintf("Epoch %d/%d - train_loss: %.4f - valid_loss: %.4f",
                      epoch, epochs, history[[epoch]]$train_loss, history[[epoch]]$valid_loss))
    }
    if (isTRUE(early_stopping) && wait >= patience) {
      break
    }
  }

  if (!is.null(best_state)) {
    model$load_state_dict(best_state)
  }

  list(
    state = model,
    task = task,
    levels = levels,
    outcome_type = outcome$outcome_type,
    x_center = scaled$center,
    x_scale = scaled$scale,
    y_center = outcome$center,
    y_scale = outcome$scale,
    device = device,
    history = do.call(rbind, Filter(Negate(is.null), history)),
    best_epoch = best_epoch,
    best_validation_loss = best_loss,
    best_validation_metric = best_metric
  )
}

.mlp_predict_torch <- function(state, Xnew, type, levels) {
  Xnew <- .mlp_scale_new(Xnew, state$x_center, state$x_scale)
  state$state$eval()
  x_tensor <- torch::torch_tensor(Xnew, dtype = torch::torch_float(), device = state$device)
  logits <- torch::with_no_grad({
    state$state(x_tensor)
  })
  logits <- as.array(logits$to(device = "cpu"))

  if (is.null(levels)) {
    pred <- as.numeric(logits)
    return(pred * (state$y_scale %||% 1) + (state$y_center %||% 0))
  }

  if (identical(state$outcome_type, "binary")) {
    prob_one <- pmin(pmax(stats::plogis(as.numeric(logits)), 1e-6), 1 - 1e-6)
    prob <- cbind(1 - prob_one, prob_one)
    colnames(prob) <- levels
  } else {
    logits <- logits - apply(logits, 1L, max)
    prob <- exp(logits)
    prob <- prob / rowSums(prob)
    colnames(prob) <- levels
  }

  if (identical(type, "class")) {
    return(factor(levels[max.col(prob, ties.method = "first")], levels = levels))
  }
  prob[, levels, drop = FALSE]
}
