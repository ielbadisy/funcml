# Native model-agnostic interpretability for funcml

.target_pred <- function(fit, Xnew, task, type = NULL, class_level = NULL, pos_level = NULL) {
  type <- type %||% if (task == "regression") "response" else "prob"
  if (task == "regression") {
    return(as.numeric(.predict_prob_or_response(fit, fit$adapter, fit$state, Xnew, type = "response")))
  }
  class_level <- class_level %||% pos_level %||% fit$levels[length(fit$levels)]
  pred <- .predict_prob_or_response(fit, fit$adapter, fit$state, Xnew, type = "prob", class_level = class_level)
  prob <- as.matrix(pred)
  idx <- match(class_level, colnames(prob))
  if (is.na(idx)) {
    stop("class_level not found in probability outputs.", call. = FALSE)
  }
  prob[, idx]
}

.interpret_result <- function(payload, diagnostics = list()) {
  list(payload = payload, diagnostics = diagnostics)
}

.as_interpret_result <- function(x) {
  if (is.list(x) && identical(sort(names(x)), c("diagnostics", "payload"))) {
    return(x)
  }
  .interpret_result(x, diagnostics = list())
}

.metric_smaller_is_better <- function(metric) {
  switch(
    metric,
    rmse = TRUE,
    mae = TRUE,
    mse = TRUE,
    medae = TRUE,
    mape = TRUE,
    rsq = FALSE,
    accuracy = FALSE,
    precision = FALSE,
    recall = FALSE,
    specificity = FALSE,
    f1 = FALSE,
    balanced_accuracy = FALSE,
    logloss = TRUE,
    brier = TRUE,
    ece = TRUE,
    mce = TRUE,
    auc = FALSE,
    stop("Unsupported metric: ", metric, call. = FALSE)
  )
}

.metric_value <- function(truth, pred, task, metric, levels = NULL, event_level = NULL) {
  if (task == "regression") {
    return(.loss(truth, pred, task, metric))
  }

  truth <- factor(truth, levels = levels)
  if (metric == "accuracy") {
    pred_class <- if (is.matrix(pred) || is.data.frame(pred)) {
      prob <- .normalize_prob_matrix(pred, levels)
      factor(levels[max.col(prob, ties.method = "first")], levels = levels)
    } else {
      factor(pred, levels = levels)
    }
    return(accuracy(truth, pred_class))
  }
  if (metric %in% c("precision", "recall", "specificity", "f1", "balanced_accuracy")) {
    pred_class <- if (is.matrix(pred) || is.data.frame(pred)) {
      prob <- .normalize_prob_matrix(pred, levels)
      factor(levels[max.col(prob, ties.method = "first")], levels = levels)
    } else {
      factor(pred, levels = levels)
    }
    return(switch(
      metric,
      precision = precision(truth, pred_class),
      recall = recall(truth, pred_class),
      specificity = specificity(truth, pred_class),
      f1 = f1(truth, pred_class),
      balanced_accuracy = balanced_accuracy(truth, pred_class)
    ))
  }

  prob <- .normalize_prob_matrix(pred, levels)
  if (metric == "logloss") {
    return(logloss(truth, prob))
  }
  if (metric == "brier") {
    return(brier(truth, prob))
  }
  if (metric == "ece") {
    return(ece(truth, prob, positive = event_level))
  }
  if (metric == "mce") {
    return(mce(truth, prob, positive = event_level))
  }
  if (metric == "auc") {
    if (length(levels) != 2) {
      stop("AUC is defined for binary classification only.", call. = FALSE)
    }
    event_level <- event_level %||% levels[2]
    truth_auc <- factor(truth, levels = c(setdiff(levels, event_level), event_level))
    return(auc(truth_auc, prob[, event_level]))
  }
  stop("Unsupported metric: ", metric, call. = FALSE)
}

.prediction_type <- function(task, type, metric, type_missing) {
  if (task == "regression") {
    return("response")
  }
  if (!type_missing && !is.null(type)) {
    if (metric %in% c("logloss", "brier", "auc", "ece", "mce") && type != "prob") {
      stop("Metrics logloss, brier, auc, ece, and mce require `type = \"prob\"`.", call. = FALSE)
    }
    return(type)
  }
  if (metric %in% c("logloss", "brier", "auc", "ece", "mce")) "prob" else "class"
}

.grid_values <- function(vec, grid = NULL, grid.resolution = NULL,
                         quantiles = FALSE, probs = 1:9 / 10,
                         trim.outliers = FALSE) {
  if (!is.null(grid)) {
    return(grid)
  }
  if (is.factor(vec)) {
    return(levels(vec))
  }
  if (is.character(vec)) {
    return(sort(unique(vec)))
  }
  if (quantiles) {
    return(stats::quantile(vec, probs = probs, na.rm = TRUE, names = FALSE))
  }
  x <- vec
  if (trim.outliers) {
    out <- grDevices::boxplot.stats(x, do.out = TRUE)$out
    x <- x[!(x %in% out)]
  }
  grid.resolution <- grid.resolution %||% min(length(unique(x)), 51L)
  seq(min(x, na.rm = TRUE), max(x, na.rm = TRUE), length.out = grid.resolution)
}

.coerce_feature_value <- function(template, value, n) {
  if (is.factor(template)) {
    vals <- rep_len(as.character(value), n)
    return(factor(vals, levels = levels(template), ordered = is.ordered(template)))
  }
  if (is.character(template)) {
    return(rep_len(as.character(value), n))
  }
  if (is.logical(template)) {
    return(rep_len(as.logical(value), n))
  }
  rep_len(as.numeric(value), n)
}

.predict_numeric_target <- function(fit, newdata, type, class_level, pos_level) {
  if (fit$task == "regression") {
    return(as.numeric(predict(fit, newdata, type = "response")))
  }
  selected_class <- class_level %||% pos_level %||% fit$levels[length(fit$levels)]
  prob <- .normalize_prob_matrix(
    predict(fit, newdata, type = "prob", class_level = selected_class, pos_level = pos_level),
    fit$levels
  )
  prob[, selected_class]
}

.format_feature_value <- function(value) {
  if (length(value) == 0L || is.null(value) || is.na(value)) {
    return("NA")
  }
  if (is.numeric(value)) {
    return(format(signif(as.numeric(value), 4), trim = TRUE, scientific = FALSE))
  }
  as.character(value)
}

.feature_display_label <- function(feature, value) {
  sprintf("%s = %s", feature, .format_feature_value(value))
}

.publication_theme <- function() {
  ggplot2::theme_bw() +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_line(colour = "grey88", linewidth = 0.3),
      panel.grid.major.y = ggplot2::element_blank(),
      strip.background = ggplot2::element_rect(fill = "grey95", colour = "grey80"),
      plot.title = ggplot2::element_text(face = "bold"),
      legend.title = ggplot2::element_text(face = "bold")
    )
}

.prediction_axis_label <- function(task, type, context = c("prediction", "pdp", "ice", "ale")) {
  context <- match.arg(context)
  base <- if (task == "regression") {
    "Predicted response"
  } else if (identical(type, "prob")) {
    "Predicted probability"
  } else {
    "Predicted log-probability"
  }
  switch(
    context,
    prediction = base,
    pdp = if (task == "regression") "Partial dependence" else sprintf("Partial dependence (%s)", tolower(base)),
    ice = base,
    ale = sprintf("ALE on %s scale", tolower(sub("^Predicted ", "", base)))
  )
}

.permute_axis_label <- function(x) {
  metric <- x$result$metric %||% x$metric %||% "metric"
  comparison <- x$result$comparison %||% "difference"
  direction <- if (comparison == "difference") {
    sprintf("Change in %s after permutation", toupper(metric))
  } else {
    sprintf("Relative change in %s after permutation", toupper(metric))
  }
  direction
}

.support_frame <- function(data_use, features) {
  rows <- lapply(features, function(feat) {
    x <- data_use[[feat]]
    if (is.numeric(x)) {
      data.frame(feature = feat, value = x, stringsAsFactors = FALSE)
    } else {
      NULL
    }
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) {
    return(NULL)
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.as_shapviz_object <- function(df, S_inter = NULL) {
  if (!requireNamespace("shapviz", quietly = TRUE)) {
    return(NULL)
  }
  obs_ids <- sort(unique(df$observation))
  features <- unique(df$feature)
  shap_mat <- sapply(features, function(feat) {
    vals <- df[df$feature == feat, c("observation", "shap"), drop = FALSE]
    vals <- vals[match(obs_ids, vals$observation), "shap"]
    as.numeric(vals)
  })
  if (!is.matrix(shap_mat)) {
    shap_mat <- matrix(shap_mat, ncol = length(features))
  }
  colnames(shap_mat) <- features
  rownames(shap_mat) <- obs_ids

  X <- data.frame(row.names = obs_ids, stringsAsFactors = FALSE)
  for (feat in features) {
    vals <- df[df$feature == feat, c("observation", "raw_value", "feature_value"), drop = FALSE]
    vals <- vals[match(obs_ids, vals$observation), , drop = FALSE]
    if (all(!is.na(vals$raw_value))) {
      X[[feat]] <- as.numeric(vals$raw_value)
    } else {
      X[[feat]] <- vals$feature_value
    }
  }
  baseline <- df[df$feature == features[1], c("observation", "baseline"), drop = FALSE]
  baseline <- baseline[match(obs_ids, baseline$observation), "baseline"]
  shapviz::shapviz(
    shap_mat,
    X = X,
    baseline = mean(as.numeric(baseline)),
    S_inter = S_inter
  )
}

.funcml_shapviz_style <- function(plot_obj) {
  if (inherits(plot_obj, "ggplot")) {
    return(plot_obj + .publication_theme())
  }
  if ("patchwork" %in% class(plot_obj)) {
    patchwork_and <- getFromNamespace("&", "patchwork")
    return(patchwork_and(plot_obj, .publication_theme()))
  }
  plot_obj
}

.format_tune_config <- function(df, exclude = c("mean", "sd")) {
  cols <- setdiff(names(df), exclude)
  apply(df[, cols, drop = FALSE], 1, function(row) {
    paste(sprintf("%s=%s", cols, unname(row)), collapse = ", ")
  })
}

.recode_local_features <- function(dat, x_interest) {
  out <- vector("list", length(dat))
  names(out) <- names(dat)
  for (j in seq_along(dat)) {
    col <- dat[[j]]
    target <- x_interest[[j]]
    if (is.factor(col) || is.character(col) || is.logical(col) || is.ordered(col)) {
      out[[j]] <- as.numeric(as.character(col) == as.character(target))
      names(out)[j] <- sprintf("%s=%s", names(dat)[j], .format_feature_value(target))
    } else {
      out[[j]] <- as.numeric(col)
    }
  }
  as.data.frame(out, check.names = FALSE)
}

.local_similarity_weights <- function(data_use, x_interest, features, power = 1) {
  sims <- lapply(features, function(feat) {
    x <- data_use[[feat]]
    x0 <- x_interest[[feat]]
    if (is.factor(x) || is.character(x) || is.logical(x) || is.ordered(x)) {
      as.numeric(as.character(x) == as.character(x0))
    } else {
      rng <- diff(range(x, na.rm = TRUE))
      if (!is.finite(rng) || rng == 0) {
        rep(1, length(x))
      } else {
        pmax(0, 1 - abs(as.numeric(x) - as.numeric(x0)) / rng)
      }
    }
  })
  weights <- Reduce(`+`, sims) / length(sims)
  pmax(weights^power, .Machine$double.eps)
}

.weighted_rsq <- function(truth, pred, weights) {
  w <- weights / sum(weights)
  mu <- sum(w * truth)
  ss_tot <- sum(w * (truth - mu)^2)
  ss_res <- sum(w * (truth - pred)^2)
  if (!is.finite(ss_tot) || ss_tot == 0) {
    return(NA_real_)
  }
  1 - ss_res / ss_tot
}

.local_formula <- function(cols) {
  stats::as.formula(paste(".target ~", paste(sprintf("`%s`", cols), collapse = " + ")))
}

.coerce_plot_value <- function(x) {
  out <- utils::type.convert(as.character(x), as.is = TRUE)
  if (is.character(out)) {
    factor(out, levels = unique(as.character(x)))
  } else {
    out
  }
}

#' Model-agnostic interpretation (global + local).
#'
#' Implements native permutation VI, PDP/ICE/ALE, SHAP approximations, local
#' surrogate explanations, interaction strength, and global surrogate models
#' without vendoring external package source code.
#'
#' @param fit A `funcml_fit` object.
#' @param data Reference data (typically training set).
#' @param formula Optional formula (defaults to `fit$formula`).
#' @param method One of "vip","permute","pdp","ice","ale","local","lime",
#'   "shap","local_model","interaction","surrogate","profile",
#'   "ceteris_paribus", or "calibration".
#' @param features Optional subset of features; defaults to all predictors.
#' @param type Prediction scale: regression -> "response"; classification -> "prob" or "class".
#' @param metric Loss/score for importance (reg: rmse/mae/mse/medae/mape/rsq; cls: accuracy/precision/recall/specificity/f1/balanced_accuracy/logloss/brier/ece/mce/auc).
#' @param importance_type Importance engine for `method = "vip"`: `"permute"`,
#'   `"model"`, or `"auto"`.
#' @param compare How to compare baseline and perturbed performance for
#'   importance: `"difference"` or `"ratio"`.
#' @param keep Keep per-repetition raw importance scores when `nsim > 1`.
#' @param k Sparsity target for local surrogate fits (`method = "local"`,
#'   `"local_model"`, or `"lime"`).
#' @param gower_power Exponent applied to native similarity weights when constructing the
#'   local neighborhood.
#' @param class_level Target class for multiclass/local prob explanations.
#' @param pos_level Alias for binary positive class (second level default).
#' @param newdata Single-row data frame for local/SHAP explanations; defaults to first row of `data`.
#' @param nsim Number of Monte Carlo simulations (importance/SHAP) or repetitions.
#' @param nsamples Row subsample for speed (reference/background set).
#' @param grid Optional list of grids per feature for PDP/ICE/ALE.
#' @param seed Optional seed for determinism.
#' @param bins Number of bins for calibration diagnostics.
#' @param strategy Binning strategy for calibration diagnostics.
#' @param ... Additional method-specific args.
#' @examples
#' fit_obj <- fit(
#'   mpg ~ wt + hp + disp,
#'   data = mtcars,
#'   model = "rpart",
#'   spec = list(cp = 0.01, minsplit = 5)
#' )
#' vi <- interpret(
#'   fit = fit_obj,
#'   data = mtcars,
#'   method = "permute",
#'   features = c("wt", "hp"),
#'   nsim = 2,
#'   metric = "rmse"
#' )
#' vi$result$scores
#' @export
interpret <- function(fit, data, formula = fit$formula,
                      method = c("vip", "permute", "pdp", "ice", "ale", "local", "lime", "shap",
                                 "local_model", "interaction", "surrogate",
                                 "profile", "ceteris_paribus", "calibration"),
                      features = NULL, type = NULL, metric = NULL,
                      importance_type = c("permute", "model", "auto"),
                      compare = c("difference", "ratio"),
                      keep = TRUE,
                      k = NULL,
                      gower_power = NULL,
                      class_level = NULL, pos_level = NULL, newdata = NULL,
                      nsim = NULL, nsamples = NULL, grid = NULL, seed = NULL,
                      bins = 10, strategy = c("quantile", "uniform"), ...) {
  if (!inherits(fit, "funcml_fit")) {
    stop("fit must be a funcml_fit.", call. = FALSE)
  }
  type_missing <- missing(type)
  nsamples_missing <- missing(nsamples)
  method <- match.arg(method)
  importance_type <- match.arg(importance_type)
  compare <- match.arg(compare)
  if (!is.null(seed)) {
    set.seed(seed)
  }

  task <- fit$task
  metric <- metric %||% if (task == "regression") "rmse" else "accuracy"
  if (method == "permute") {
    importance_type <- "permute"
  }
  if (is.null(type)) {
    type <- if (task == "regression") {
      "response"
    } else if (method %in% c("vip", "permute") && metric == "accuracy") {
      "class"
    } else {
      "prob"
    }
  }
  if (task == "classification" && type == "prob" && length(fit$levels) > 2 && is.null(class_level)) {
    class_level <- fit$levels[length(fit$levels)]
  }

  features_was_null <- is.null(features)
  if (features_was_null) {
    mf <- stats::model.frame(stats::delete.response(fit$terms), data)
    features <- setdiff(colnames(mf), "(Intercept)")
  }

  nsim <- nsim %||% switch(
    method,
    vip = 1,
    permute = 30,
    shap = 80,
    50
  )
  if (is.null(nsim) || nsim < 1) {
    stop("`nsim` must be >= 1.", call. = FALSE)
  }
  if (nsamples_missing && method %in% c("vip", "permute")) {
    nsamples <- NULL
  } else {
    nsamples <- nsamples %||% min(200, nrow(data))
  }
  grid <- grid %||% list()

  dispatcher <- switch(
    method,
    vip = interpret_vip,
    permute = interpret_vip,
    pdp = interpret_pdp,
    ice = interpret_ice,
    ceteris_paribus = interpret_ice,
    ale = interpret_ale,
    local = interpret_local_model,
    lime = interpret_local_model,
    local_model = interpret_local_model,
    shap = interpret_shap,
    interaction = interpret_interaction,
    surrogate = interpret_surrogate,
    profile = interpret_profile,
    calibration = interpret_calibration
  )

  result <- dispatcher(
    fit = fit, data = data, features = features, type = type,
    metric = metric, class_level = class_level, pos_level = pos_level,
    newdata = newdata, nsim = nsim, nsamples = nsamples, grid = grid,
    seed = seed, features_was_null = features_was_null, type_missing = type_missing,
    importance_type = importance_type, compare = compare, keep = keep,
    k = k, gower_power = gower_power, bins = bins, strategy = strategy,
    ...
  )
  parsed <- .as_interpret_result(result)

  out <- list(
    call = match.call(),
    method = method,
    task = task,
    type = type,
    metric = metric,
    features = features,
    class_level = class_level %||% pos_level %||% if (!is.null(fit$levels)) tail(fit$levels, 1) else NULL,
    result = parsed$payload,
    diagnostics = parsed$diagnostics,
    seed = seed
  )
  if (method == "shap") {
    out$fit_ref <- fit
    out$data_ref <- data
    out$newdata_ref <- newdata %||% data[1, , drop = FALSE]
    out$nsim_ref <- nsim
    out$nsamples_ref <- nsamples
  }
  class(out) <- if (method == "vip") {
    c("funcml_vip", "funcml_permute")
  } else if (method == "permute") {
    c("funcml_permute", "funcml_vip")
  } else if (method == "profile") {
    c("funcml_profile", "funcml_pdp")
  } else if (method == "ceteris_paribus") {
    c("funcml_ceteris_paribus", "funcml_ice")
  } else if (method == "local_model") {
    c("funcml_iml_local_model", "funcml_local")
  } else if (method == "lime") {
    c("funcml_lime", "funcml_iml_local_model", "funcml_local")
  } else if (method == "shap") {
    c("funcml_shapley", "funcml_shap")
  } else if (method == "calibration") {
    "funcml_calibration"
  } else {
    paste0("funcml_", method)
  }
  out
}

interpret_vip <- function(fit, data, features, type, metric, class_level, pos_level,
                          nsim, nsamples, importance_type, compare, keep,
                          type_missing, sample_size = NULL, sample_frac = NULL, ...) {
  if (importance_type == "auto") {
    importance_type <- if (isTRUE(fit$adapter$supports$importance) && !is.null(fit$adapter$importance)) {
      "model"
    } else {
      "permute"
    }
  }
  if (importance_type == "model") {
    encoded <- .encode_train(data = data, formula = fit$formula, na_action = fit$na_action)
    feature_names <- setdiff(encoded$features, "(Intercept)")
    scores <- fit$adapter$importance(
      state = fit$state,
      X = encoded$X,
      y = encoded$y,
      feature_names = feature_names,
      task = fit$task,
      levels = fit$levels
    )
    scores <- scores[, intersect(c("feature", "importance"), names(scores)), drop = FALSE]
    scores <- scores[scores$feature %in% features, , drop = FALSE]
    scores <- scores[order(scores$importance, decreasing = TRUE), , drop = FALSE]
    rownames(scores) <- NULL
    return(.interpret_result(
      payload = list(scores = scores, baseline = NA_real_, metric = NULL, comparison = NULL, raw_scores = NULL),
      diagnostics = list(reference = "native model importance", engine = "model")
    ))
  }

  if (!is.null(sample_size) && !is.null(sample_frac)) {
    stop("Arguments `sample_size` and `sample_frac` cannot both be specified.", call. = FALSE)
  }
  if (is.null(sample_size) && !is.null(sample_frac)) {
    if (sample_frac <= 0 || sample_frac > 1) {
      stop("Argument `sample_frac` must be in (0, 1].", call. = FALSE)
    }
    sample_size <- round(nrow(data) * sample_frac, digits = 0)
  }
  if (is.null(sample_size) && !is.null(nsamples)) {
    sample_size <- nsamples
  }
  if (!is.null(sample_size) && (sample_size <= 0 || sample_size > nrow(data))) {
    stop("Argument `sample_size` must be in (0, nrow(data)].", call. = FALSE)
  }

  truth <- stats::model.response(stats::model.frame(fit$formula, data))
  pred_type <- .prediction_type(fit$task, type, metric, type_missing = type_missing)
  event_level <- class_level %||% pos_level %||% if (!is.null(fit$levels)) fit$levels[length(fit$levels)] else NULL
  data_use <- if (!is.null(sample_size) && sample_size < nrow(data)) {
    data[sample(seq_len(nrow(data)), sample_size), , drop = FALSE]
  } else {
    data
  }
  truth_use <- stats::model.response(stats::model.frame(fit$formula, data_use))

  predict_for_metric <- function(newdata) {
    if (pred_type == "class") {
      pred <- predict(fit, newdata, type = "class", class_level = class_level, pos_level = pos_level)
      factor(pred, levels = fit$levels)
    } else if (pred_type == "prob") {
      predict(fit, newdata, type = "prob", class_level = class_level, pos_level = pos_level)
    } else {
      as.numeric(predict(fit, newdata, type = "response"))
    }
  }

  baseline_pred <- predict_for_metric(data_use)
  baseline <- .metric_value(
    truth = truth_use,
    pred = baseline_pred,
    task = fit$task,
    metric = metric,
    levels = fit$levels,
    event_level = event_level
  )

  raw_scores <- matrix(NA_real_, nrow = nsim, ncol = length(features), dimnames = list(NULL, features))
  smaller_is_better <- .metric_smaller_is_better(metric)
  for (sim in seq_len(nsim)) {
    for (j in seq_along(features)) {
      feat <- features[j]
      permuted <- data_use
      permuted[[feat]] <- sample(permuted[[feat]])
      score <- .metric_value(
        truth = truth_use,
        pred = predict_for_metric(permuted),
        task = fit$task,
        metric = metric,
        levels = fit$levels,
        event_level = event_level
      )
      raw_scores[sim, j] <- if (compare == "difference") {
        if (smaller_is_better) score - baseline else baseline - score
      } else {
        if (smaller_is_better) score / baseline else baseline / score
      }
    }
  }

  scores <- data.frame(
    feature = features,
    importance = colMeans(raw_scores),
    std_dev = if (nsim > 1) apply(raw_scores, 2, stats::sd) else NA_real_,
    stringsAsFactors = FALSE
  )
  scores <- scores[order(scores$importance, decreasing = TRUE), , drop = FALSE]
  rownames(scores) <- NULL

  .interpret_result(
    payload = list(
      scores = scores,
      baseline = baseline,
      metric = metric,
      comparison = compare,
      raw_scores = if (isTRUE(keep) && nsim > 1) raw_scores else NULL
    ),
    diagnostics = list(
      reference = "native permutation importance",
      engine = "permute",
      prediction_type = pred_type,
      sample_size = sample_size,
      smaller_is_better = smaller_is_better
    )
  )
}

.pdp_class_level <- function(fit, class_level, pos_level) {
  class_level %||% pos_level %||% fit$levels[1L]
}

.pdp_multiclass_logit <- function(prob, class_level) {
  prob <- as.matrix(prob)
  eps <- .Machine$double.eps
  idx <- match(class_level, colnames(prob))
  log(ifelse(prob[, idx] > 0, prob[, idx], eps)) -
    rowMeans(log(ifelse(prob > 0, prob, eps)))
}

.pdp_predict_values <- function(fit, newdata, type, class_level, pos_level) {
  if (fit$task == "regression") {
    return(as.numeric(predict(fit, newdata, type = "response")))
  }
  selected_class <- .pdp_class_level(fit, class_level, pos_level)
  prob <- .normalize_prob_matrix(
    predict(fit, newdata, type = "prob", class_level = selected_class, pos_level = pos_level),
    fit$levels
  )
  if (identical(type, "prob")) {
    prob[, selected_class]
  } else {
    .pdp_multiclass_logit(prob, selected_class)
  }
}

interpret_pdp <- function(fit, data, features, type, class_level, pos_level, grid, nsamples,
                          grid.resolution = NULL, quantiles = FALSE, probs = 1:9 / 10,
                          trim.outliers = FALSE, ...) {
  data_use <- if (!is.null(nsamples) && nrow(data) > nsamples) data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE] else data
  curves <- lapply(features, function(feat) {
    values <- .grid_values(
      data_use[[feat]],
      grid = grid[[feat]],
      grid.resolution = grid.resolution,
      quantiles = quantiles,
      probs = probs,
      trim.outliers = trim.outliers
    )
    yhat <- vapply(values, function(value) {
      tmp <- data_use
      tmp[[feat]] <- .coerce_feature_value(data_use[[feat]], value, nrow(tmp))
      mean(.pdp_predict_values(fit, tmp, type = type, class_level = class_level, pos_level = pos_level))
    }, numeric(1))
    data.frame(feature = feat, value = values, yhat = yhat, stringsAsFactors = FALSE)
  })
  curves <- do.call(rbind, curves)
  rownames(curves) <- NULL
  .interpret_result(
    payload = list(curves = curves, grid = grid, support = .support_frame(data_use, features)),
    diagnostics = list(reference = "native partial dependence")
  )
}

interpret_profile <- function(..., type, method = NULL) {
  interpret_pdp(..., type = type)
}

interpret_ice <- function(fit, data, features, type, class_level, pos_level, grid, nsamples,
                          center = FALSE, grid.resolution = NULL, quantiles = FALSE,
                          probs = 1:9 / 10, trim.outliers = FALSE, ...) {
  data_use <- if (!is.null(nsamples) && nrow(data) > nsamples) data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE] else data
  curves <- lapply(features, function(feat) {
    values <- .grid_values(
      data_use[[feat]],
      grid = grid[[feat]],
      grid.resolution = grid.resolution,
      quantiles = quantiles,
      probs = probs,
      trim.outliers = trim.outliers
    )
    out <- lapply(seq_len(nrow(data_use)), function(i) {
      base_row <- data_use[rep(i, length(values)), , drop = FALSE]
      base_row[[feat]] <- .coerce_feature_value(data_use[[feat]], values, length(values))
      preds <- .pdp_predict_values(fit, base_row, type = type, class_level = class_level, pos_level = pos_level)
      if (center && length(preds)) {
        preds <- preds - preds[1]
      }
      data.frame(id = i, feature = feat, value = values, yhat = preds, stringsAsFactors = FALSE)
    })
    do.call(rbind, out)
  })
  curves <- do.call(rbind, curves)
  rownames(curves) <- NULL
  .interpret_result(
    payload = list(curves = curves, grid = grid, support = .support_frame(data_use, features)),
    diagnostics = list(reference = "native ICE", centered = isTRUE(center))
  )
}

interpret_ale <- function(fit, data, features, type, class_level, pos_level, grid, nsamples,
                          grid.resolution = 20, ...) {
  data_use <- if (!is.null(nsamples) && nrow(data) > nsamples) data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE] else data
  out <- lapply(features, function(feat) {
    x <- data_use[[feat]]
    if (!is.numeric(x)) {
      return(NULL)
    }
    cuts <- sort(unique(as.numeric(.grid_values(x, grid = grid[[feat]], grid.resolution = grid.resolution, quantiles = TRUE))))
    if (length(cuts) < 2) {
      return(NULL)
    }
    mids <- (cuts[-1] + cuts[-length(cuts)]) / 2
    effects <- numeric(length(mids))
    counts <- numeric(length(mids))
    for (i in seq_along(mids)) {
      lower <- cuts[i]
      upper <- cuts[i + 1]
      idx <- which(x >= lower & x <= upper)
      if (!length(idx)) {
        effects[i] <- NA_real_
        next
      }
      low_dat <- data_use[idx, , drop = FALSE]
      high_dat <- data_use[idx, , drop = FALSE]
      low_dat[[feat]] <- lower
      high_dat[[feat]] <- upper
      effects[i] <- mean(
        .pdp_predict_values(fit, high_dat, type = type, class_level = class_level, pos_level = pos_level) -
          .pdp_predict_values(fit, low_dat, type = type, class_level = class_level, pos_level = pos_level)
      )
      counts[i] <- length(idx)
    }
    effects[is.na(effects)] <- 0
    cum <- cumsum(effects)
    centered <- cum - stats::weighted.mean(cum, w = pmax(counts, 1))
    data.frame(feature = feat, value = mids, effect = centered, stringsAsFactors = FALSE)
  })
  out <- Filter(Negate(is.null), out)
  curves <- if (length(out)) do.call(rbind, out) else data.frame(feature = character(), value = numeric(), effect = numeric())
  .interpret_result(
    payload = list(curves = curves, grid = grid, support = .support_frame(data_use, features)),
    diagnostics = list(reference = "native ALE")
  )
}

interpret_local_model <- function(fit, data, features, type, class_level, pos_level, newdata, nsamples,
                                  k = 3, gower_power = 1, ...) {
  k <- k %||% 3
  gower_power <- gower_power %||% 1
  if (is.null(newdata)) {
    newdata <- data[1, , drop = FALSE]
  }
  x_interest <- newdata[1, features, drop = FALSE]
  data_use <- if (!is.null(nsamples) && nrow(data) > nsamples) data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE] else data
  X <- data_use[, features, drop = FALSE]
  yhat <- .predict_numeric_target(fit, data_use, type = type, class_level = class_level, pos_level = pos_level)
  X_recode <- .recode_local_features(X, x_interest)
  x_interest_recode <- .recode_local_features(x_interest[, features, drop = FALSE], x_interest)
  sample_weights <- .local_similarity_weights(X, x_interest, features, power = gower_power)
  df <- data.frame(.target = yhat, .weights = sample_weights, X_recode, check.names = FALSE)
  model <- stats::lm(.local_formula(colnames(X_recode)), data = df, weights = .weights)
  beta <- stats::coef(model)
  beta[is.na(beta)] <- 0

  feature_names <- names(beta)[names(beta) != "(Intercept)"]
  if (length(feature_names) > k) {
    keep_idx <- order(abs(beta[feature_names]), decreasing = TRUE)[seq_len(k)]
    feature_names <- feature_names[keep_idx]
  }
  encoded_values <- unname(as.numeric(x_interest_recode[1, feature_names, drop = TRUE]))
  raw_feature_names <- sub("=.*$", "", feature_names)
  observed_values <- vapply(raw_feature_names, function(feat) x_interest[[feat]][1], FUN.VALUE = x_interest[[1]][1])
  display_values <- vapply(raw_feature_names, function(feat) .format_feature_value(x_interest[[feat]][1]), character(1))
  effects <- data.frame(
    feature = raw_feature_names,
    feature.value = vapply(seq_along(feature_names), function(i) {
      if (grepl("=", feature_names[i], fixed = TRUE)) {
        feature_names[i]
      } else {
        .feature_display_label(raw_feature_names[i], observed_values[[i]])
      }
    }, character(1)),
    observed_value = display_values,
    encoded_value = encoded_values,
    beta = unname(beta[feature_names]),
    effect = unname(beta[feature_names]) * encoded_values,
    stringsAsFactors = FALSE
  )
  effects <- effects[effects$effect != 0, , drop = FALSE]
  effects <- effects[order(abs(effects$effect), decreasing = TRUE), , drop = FALSE]
  rownames(effects) <- NULL

  local_pred <- as.numeric(stats::predict(model, newdata = data.frame(x_interest_recode, check.names = FALSE))[1])
  fitted_local <- as.numeric(stats::predict(model, newdata = X_recode))
  .interpret_result(
    payload = list(
      results = effects,
      fidelity = .weighted_rsq(yhat, fitted_local, sample_weights),
      weights = effects,
      sample_weights = sample_weights,
      model = model,
      local_prediction = local_pred
    ),
    diagnostics = list(
      reference = "native local surrogate",
      neighborhood = "similarity",
      k = k,
      prediction = .predict_numeric_target(fit, newdata[1, , drop = FALSE], type = type, class_level = class_level, pos_level = pos_level)
    )
  )
}

interpret_shap <- function(fit, data, features, type, class_level, pos_level, newdata, nsim, nsamples,
                           seed = NULL, baseline = NULL, ...) {
  if (is.null(newdata)) {
    newdata <- data[1, , drop = FALSE]
  }
  if (!is.null(seed)) {
    set.seed(seed)
  }
  background <- if (!is.null(nsamples) && nrow(data) > nsamples) data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE] else data

  pred_one <- function(df) {
    .predict_numeric_target(fit, df, type = type, class_level = class_level, pos_level = pos_level)
  }

  rows <- lapply(seq_len(nrow(newdata)), function(obs_id) {
    x_interest <- newdata[obs_id, , drop = FALSE]
    pred_interest <- pred_one(x_interest)[1]
    contrib <- matrix(0, nrow = nsim, ncol = length(features), dimnames = list(NULL, features))
    start_preds <- numeric(nsim)

    for (m in seq_len(nsim)) {
      ref_row <- background[sample(seq_len(nrow(background)), 1L), , drop = FALSE]
      order_idx <- sample(features)
      current <- ref_row
      prev_pred <- pred_one(current)[1]
      start_preds[m] <- prev_pred
      for (feat in order_idx) {
        current[[feat]] <- x_interest[[feat]]
        next_pred <- pred_one(current)[1]
        contrib[m, feat] <- next_pred - prev_pred
        prev_pred <- next_pred
      }
    }

    shap_vals <- colMeans(contrib)
    shap_var <- if (nsim > 1) apply(contrib, 2, stats::var) else rep(NA_real_, length(features))
    baseline_value <- baseline %||% mean(start_preds)
    numeric_values <- suppressWarnings(as.numeric(unlist(x_interest[1, features, drop = FALSE], use.names = FALSE)))
    data.frame(
      observation = obs_id,
      feature = features,
      shap = as.numeric(shap_vals[features]),
      phi_var = as.numeric(shap_var[features]),
      baseline = baseline_value,
      prediction = pred_interest,
      feature_value = unlist(lapply(x_interest[1, features, drop = FALSE], as.character), use.names = FALSE),
      raw_value = numeric_values,
      feature_label = vapply(features, function(feat) .feature_display_label(feat, x_interest[[feat]][1]), character(1)),
      stringsAsFactors = FALSE
    )
  })
  result <- do.call(rbind, rows)
  rownames(result) <- NULL
  .interpret_result(
    payload = result,
    diagnostics = list(
      reference = "approximate monte carlo shap",
      baseline = if (nrow(newdata) == 1L) result$baseline[1] else NA_real_,
      prediction = if (nrow(newdata) == 1L) result$prediction[1] else NA_real_,
      observations = nrow(newdata)
    )
  )
}

.funcml_shap_interaction_array <- function(x, nsim = NULL, seed = NULL) {
  if (is.null(x$fit_ref) || is.null(x$data_ref) || is.null(x$newdata_ref)) {
    stop("SHAP interaction plots require the original fit, data, and explained rows.", call. = FALSE)
  }
  features <- x$features
  if (length(features) < 2L) {
    stop("SHAP interaction plots require at least two interpreted features.", call. = FALSE)
  }
  .approximate_shap_interactions(
    fit = x$fit_ref,
    data = x$data_ref,
    newdata = x$newdata_ref,
    features = features,
    type = x$type,
    class_level = x$class_level,
    pos_level = x$class_level,
    nsim = nsim %||% x$nsim_ref %||% 30L,
    nsamples = x$nsamples_ref,
    seed = seed,
    shap_df = x$result
  )
}

.approximate_shap_interactions <- function(fit, data, newdata, features, type, class_level,
                                           pos_level, nsim, nsamples, seed = NULL, shap_df = NULL) {
  if (!is.null(seed)) {
    set.seed(seed)
  }
  if (!is.numeric(nsim) || length(nsim) != 1L || nsim < 1L) {
    stop("`nsim` must be a positive integer for SHAP interaction plots.", call. = FALSE)
  }
  background <- if (!is.null(nsamples) && nrow(data) > nsamples) {
    data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE]
  } else {
    data
  }
  pred_one <- function(df) {
    .predict_numeric_target(fit, df, type = type, class_level = class_level, pos_level = pos_level)[1]
  }

  p <- length(features)
  obs_n <- nrow(newdata)
  out <- array(0, dim = c(obs_n, p, p), dimnames = list(seq_len(obs_n), features, features))

  for (obs_id in seq_len(obs_n)) {
    x_interest <- newdata[obs_id, , drop = FALSE]
    pair_acc <- matrix(0, nrow = p, ncol = p, dimnames = list(features, features))
    for (m in seq_len(nsim)) {
      ref_row <- background[sample(seq_len(nrow(background)), 1L), , drop = FALSE]
      perm <- sample(features)
      pos <- stats::setNames(match(features, perm), features)
      for (i in seq_len(p - 1L)) {
        for (j in seq.int(i + 1L, p)) {
          feat_i <- features[i]
          feat_j <- features[j]
          before <- perm[seq_len(min(pos[[feat_i]], pos[[feat_j]]) - 1L)]
          state_s <- ref_row
          if (length(before)) {
            for (feat in before) {
              state_s[[feat]] <- x_interest[[feat]]
            }
          }
          state_si <- state_s
          state_si[[feat_i]] <- x_interest[[feat_i]]
          state_sj <- state_s
          state_sj[[feat_j]] <- x_interest[[feat_j]]
          state_sij <- state_si
          state_sij[[feat_j]] <- x_interest[[feat_j]]
          delta <- pred_one(state_sij) - pred_one(state_si) - pred_one(state_sj) + pred_one(state_s)
          pair_acc[i, j] <- pair_acc[i, j] + delta
          pair_acc[j, i] <- pair_acc[j, i] + delta
        }
      }
    }
    off_diag <- pair_acc / (2 * nsim)
    diag_vals <- if (is.null(shap_df)) {
      rep(0, p)
    } else {
      shap_vals <- shap_df[shap_df$observation == obs_id, c("feature", "shap"), drop = FALSE]
      shap_vals <- shap_vals[match(features, shap_vals$feature), "shap"]
      as.numeric(shap_vals) - rowSums(off_diag)
    }
    diag(off_diag) <- diag_vals
    out[obs_id, , ] <- off_diag
  }
  out
}

.interaction_pair <- function(fit, data_use, feat_a, feat_b, type, class_level, pos_level, grid_size) {
  grid_a <- .grid_values(data_use[[feat_a]], grid.resolution = grid_size)
  grid_b <- .grid_values(data_use[[feat_b]], grid.resolution = grid_size)
  f0 <- mean(.predict_numeric_target(fit, data_use, type = type, class_level = class_level, pos_level = pos_level))
  f_a <- setNames(numeric(length(grid_a)), as.character(grid_a))
  f_b <- setNames(numeric(length(grid_b)), as.character(grid_b))
  for (i in seq_along(grid_a)) {
    tmp <- data_use
    tmp[[feat_a]] <- .coerce_feature_value(data_use[[feat_a]], grid_a[i], nrow(tmp))
    f_a[i] <- mean(.predict_numeric_target(fit, tmp, type = type, class_level = class_level, pos_level = pos_level))
  }
  for (i in seq_along(grid_b)) {
    tmp <- data_use
    tmp[[feat_b]] <- .coerce_feature_value(data_use[[feat_b]], grid_b[i], nrow(tmp))
    f_b[i] <- mean(.predict_numeric_target(fit, tmp, type = type, class_level = class_level, pos_level = pos_level))
  }
  f_ab <- numeric(length(grid_a) * length(grid_b))
  idx <- 1L
  for (a in seq_along(grid_a)) {
    for (b in seq_along(grid_b)) {
      tmp <- data_use
      tmp[[feat_a]] <- .coerce_feature_value(data_use[[feat_a]], grid_a[a], nrow(tmp))
      tmp[[feat_b]] <- .coerce_feature_value(data_use[[feat_b]], grid_b[b], nrow(tmp))
      f_ab[idx] <- mean(.predict_numeric_target(fit, tmp, type = type, class_level = class_level, pos_level = pos_level))
      idx <- idx + 1L
    }
  }
  joint <- rep(f_a, each = length(grid_b)) + rep(f_b, times = length(grid_a)) - f0
  denom <- stats::var(f_ab)
  if (!is.finite(denom) || denom == 0) {
    return(0)
  }
  sqrt(max(0, stats::var(f_ab - joint) / denom))
}

interpret_interaction <- function(fit, data, features, type, class_level, pos_level, nsamples,
                                  feature = NULL, grid_size = 15, ...) {
  data_use <- if (!is.null(nsamples) && nrow(data) > nsamples) data[sample(seq_len(nrow(data)), nsamples), , drop = FALSE] else data
  if (!is.null(feature) && !(feature %in% features)) {
    stop("`feature` must be one of the interpreted features.", call. = FALSE)
  }
  if (!is.null(feature)) {
    others <- setdiff(features, feature)
    pairwise <- data.frame(
      feature_x = feature,
      feature_y = others,
      interaction = vapply(others, function(other) .interaction_pair(fit, data_use, feature, other, type, class_level, pos_level, grid_size), numeric(1)),
      stringsAsFactors = FALSE
    )
    results <- data.frame(
      feature = others,
      interaction = pairwise$interaction,
      stringsAsFactors = FALSE
    )
  } else {
    pair_grid <- utils::combn(features, 2, simplify = FALSE)
    pairwise <- do.call(rbind, lapply(pair_grid, function(pair) {
      val <- .interaction_pair(fit, data_use, pair[1], pair[2], type, class_level, pos_level, grid_size)
      data.frame(feature_x = pair[1], feature_y = pair[2], interaction = val, stringsAsFactors = FALSE)
    }))
    results <- data.frame(
      feature = features,
      interaction = vapply(features, function(feat) {
        others <- setdiff(features, feat)
        if (!length(others)) {
          return(0)
        }
        mean(vapply(others, function(other) .interaction_pair(fit, data_use, feat, other, type, class_level, pos_level, grid_size), numeric(1)))
      }, numeric(1)),
      stringsAsFactors = FALSE
    )
  }
  results <- results[order(results$interaction, decreasing = TRUE), , drop = FALSE]
  rownames(results) <- NULL
  if (nrow(pairwise)) {
    pairwise <- rbind(
      pairwise,
      data.frame(feature_x = pairwise$feature_y, feature_y = pairwise$feature_x, interaction = pairwise$interaction, stringsAsFactors = FALSE)
    )
  }
  diag_rows <- data.frame(feature_x = features, feature_y = features, interaction = 0, stringsAsFactors = FALSE)
  pairwise <- rbind(pairwise, diag_rows)
  .interpret_result(
    payload = list(results = results, anchor_feature = feature, pairwise = pairwise),
    diagnostics = list(reference = "native interaction", metric = "Friedman H", grid_size = grid_size)
  )
}

interpret_surrogate <- function(fit, data, features, type, class_level, pos_level, maxdepth = 2, ...) {
  target <- .predict_numeric_target(fit, data, type = type, class_level = class_level, pos_level = pos_level)
  df <- cbind(.target = target, data[, features, drop = FALSE])
  form <- stats::as.formula(paste(".target ~", paste(features, collapse = " + ")))
  model <- tryCatch(
    if (requireNamespace("rpart", quietly = TRUE)) {
      rpart::rpart(form, data = df, method = "anova", control = rpart::rpart.control(maxdepth = maxdepth))
    } else {
      stats::lm(form, data = df)
    },
    error = function(e) stats::lm(form, data = df)
  )
  surrogate_pred <- as.numeric(stats::predict(model, newdata = df))
  fidelity <- rsq(target, surrogate_pred)
  result <- list(model = model, call = form, fidelity = fidelity)
  if (inherits(model, "rpart")) {
    result$nodes <- stats::predict(model, newdata = df, type = "vector")
  }
  .interpret_result(payload = result, diagnostics = list(reference = "native surrogate"))
}

interpret_calibration <- function(fit, data, type, class_level, pos_level, bins = 10,
                                  strategy = c("quantile", "uniform"), ...) {
  if (fit$task != "classification") {
    stop("Calibration diagnostics are available only for classification models.", call. = FALSE)
  }
  if (length(fit$levels) != 2L) {
    stop("Calibration diagnostics are currently implemented for binary classification only.", call. = FALSE)
  }
  strategy <- match.arg(strategy)
  positive <- class_level %||% pos_level %||% fit$levels[2L]
  truth <- stats::model.response(stats::model.frame(fit$formula, data))
  prob_matrix <- .normalize_prob_matrix(
    predict(fit, data, type = "prob", class_level = positive, pos_level = pos_level),
    fit$levels
  )
  prob <- prob_matrix[, positive]
  curve <- calibration_curve(truth, prob, bins = bins, strategy = strategy, positive = positive)
  .interpret_result(
    payload = list(
      curve = curve,
      prob = prob,
      truth = factor(truth, levels = fit$levels),
      positive = positive,
      ece = ece(truth, prob, bins = bins, strategy = strategy, positive = positive),
      mce = mce(truth, prob, bins = bins, strategy = strategy, positive = positive)
    ),
    diagnostics = list(
      reference = "native calibration diagnostics",
      bins = bins,
      strategy = strategy,
      positive = positive
    )
  )
}

plot_vi <- function(df, ylab, title) {
  y_col <- if ("importance" %in% names(df)) {
    "importance"
  } else if ("weight" %in% names(df)) {
    "weight"
  } else if ("effect" %in% names(df)) {
    "effect"
  } else if ("interaction" %in% names(df)) {
    "interaction"
  } else if ("shap" %in% names(df)) {
    "shap"
  } else {
    stop("Expected an 'importance', 'weight', 'effect', 'interaction', or 'shap' column for plotting.", call. = FALSE)
  }
  df$yval <- df[[y_col]]
  ggplot2::ggplot(df, ggplot2::aes(x = yval, y = stats::reorder(feature, yval))) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = yval, yend = feature), linewidth = 0.5, colour = "grey60") +
    ggplot2::geom_point(size = 2.2, colour = "black") +
    ggplot2::labs(x = ylab, y = NULL, title = title) +
    .publication_theme()
}

#' @export
plot.funcml_permute <- function(x, ...) {
  df <- x$result$scores
  df <- df[order(df$importance, decreasing = TRUE), , drop = FALSE]
  df$feature <- factor(df$feature, levels = rev(df$feature))
  raw_scores <- x$result$raw_scores
  if (!is.null(raw_scores)) {
    raw_df <- data.frame(
      feature = rep(colnames(raw_scores), each = nrow(raw_scores)),
      raw_score = as.numeric(raw_scores),
      stringsAsFactors = FALSE
    )
    raw_df$feature <- factor(raw_df$feature, levels = levels(df$feature))
    return(
      ggplot2::ggplot(raw_df, ggplot2::aes(x = raw_score, y = feature)) +
        ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
        ggplot2::geom_boxplot(
          width = 0.65,
          outlier.alpha = 0.25,
          fill = "white",
          colour = "grey25"
        ) +
        ggplot2::geom_point(
          data = df,
          ggplot2::aes(x = importance, y = feature),
          inherit.aes = FALSE,
          size = 2.1,
          colour = "black"
        ) +
        ggplot2::labs(
          x = .permute_axis_label(x),
          y = NULL,
          title = "Permutation feature importance"
        ) +
        .publication_theme()
    )
  }
  ggplot2::ggplot(df, ggplot2::aes(x = importance, y = feature)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
    ggplot2::geom_point(size = 2.3, colour = "black") +
    ggplot2::labs(x = .permute_axis_label(x), y = NULL, title = "Permutation feature importance") +
    .publication_theme()
}

#' @export
print.funcml_permute <- function(x, ...) {
  cat("<funcml_vi>\n")
  print(utils::head(x$result$scores, 10))
  invisible(x)
}

#' @export
summary.funcml_permute <- function(object, ...) {
  print(object$result$scores)
  invisible(object$result$scores)
}

#' @export
plot.funcml_pdp <- function(x, ...) {
  curves <- x$result$curves
  curves$plot_value <- .coerce_plot_value(curves$value)
  support <- x$result$support
  if (!is.null(support)) {
    support$plot_value <- .coerce_plot_value(support$value)
  }
  p <- ggplot2::ggplot(curves, ggplot2::aes(x = plot_value, y = yhat, group = 1)) +
    ggplot2::geom_line(colour = "black", linewidth = 0.7) +
    ggplot2::facet_wrap(~feature, scales = "free_x") +
    ggplot2::labs(
      x = "Feature value",
      y = .prediction_axis_label(x$task, x$type, context = "pdp"),
      title = "Partial dependence plot"
    ) +
    .publication_theme()
  if (!is.null(support)) {
    p <- p + ggplot2::geom_rug(
      data = support,
      ggplot2::aes(x = plot_value),
      inherit.aes = FALSE,
      sides = "b",
      alpha = 0.12,
      linewidth = 0.2
    )
  }
  p
}

#' @export
print.funcml_pdp <- function(x, ...) {
  cat("<funcml_pdp>\n")
  print(utils::head(x$result$curves, 10))
  invisible(x)
}

#' @export
summary.funcml_pdp <- function(object, ...) {
  print(object$result$curves)
  invisible(object$result$curves)
}

#' @export
plot.funcml_ice <- function(x, ...) {
  curves <- x$result$curves
  curves$plot_value <- .coerce_plot_value(curves$value)
  mean_df <- stats::aggregate(yhat ~ feature + value, data = curves, FUN = mean)
  mean_df$plot_value <- .coerce_plot_value(mean_df$value)
  ggplot2::ggplot(curves, ggplot2::aes(x = plot_value, y = yhat, group = id)) +
    ggplot2::geom_line(alpha = 0.22, linewidth = 0.35, colour = "grey55") +
    ggplot2::geom_line(data = mean_df, ggplot2::aes(x = plot_value, y = yhat, group = 1),
      inherit.aes = FALSE, colour = "black", linewidth = 0.9
    ) +
    ggplot2::facet_wrap(~feature, scales = "free_x") +
    ggplot2::labs(
      x = "Feature value",
      y = .prediction_axis_label(x$task, x$type, context = "ice"),
      title = if (isTRUE(x$diagnostics$centered)) "Centered ICE plot" else "ICE plot"
    ) +
    .publication_theme()
}

#' @export
print.funcml_ice <- function(x, ...) {
  cat("<funcml_ice>\n")
  print(utils::head(x$result$curves, 10))
  invisible(x)
}

#' @export
summary.funcml_ice <- function(object, ...) {
  print(object$result$curves)
  invisible(object$result$curves)
}

#' @export
plot.funcml_ale <- function(x, ...) {
  curves <- x$result$curves
  curves$plot_value <- .coerce_plot_value(curves$value)
  support <- x$result$support
  if (!is.null(support)) {
    support$plot_value <- .coerce_plot_value(support$value)
  }
  p <- ggplot2::ggplot(curves, ggplot2::aes(x = plot_value, y = effect, group = 1)) +
    ggplot2::geom_hline(yintercept = 0, colour = "grey70", linewidth = 0.4) +
    ggplot2::geom_line(colour = "black", linewidth = 0.8) +
    ggplot2::facet_wrap(~feature, scales = "free_x") +
    ggplot2::labs(
      x = "Feature value",
      y = .prediction_axis_label(x$task, x$type, context = "ale"),
      title = "Accumulated local effects"
    ) +
    .publication_theme()
  if (!is.null(support)) {
    p <- p + ggplot2::geom_rug(
      data = support,
      ggplot2::aes(x = plot_value),
      inherit.aes = FALSE,
      sides = "b",
      alpha = 0.12,
      linewidth = 0.2
    )
  }
  p
}

#' @export
print.funcml_ale <- function(x, ...) {
  cat("<funcml_ale>\n")
  print(utils::head(x$result$curves, 10))
  invisible(x)
}

#' @export
summary.funcml_ale <- function(object, ...) {
  print(object$result$curves)
  invisible(object$result$curves)
}

#' @export
plot.funcml_local <- function(x, ...) {
  plot_vi(x$result$weights, "Weight", "Local surrogate weights")
}

#' @export
print.funcml_local <- function(x, ...) {
  cat("<funcml_local>\n")
  print(x$result$weights)
  invisible(x)
}

#' @export
summary.funcml_local <- function(object, ...) {
  print(object$result)
  invisible(object$result)
}

#' @export
plot.funcml_iml_local_model <- function(x, ...) {
  df <- x$result$results
  df$feature <- factor(df$feature.value, levels = rev(df$feature.value))
  ggplot2::ggplot(df, ggplot2::aes(x = effect, y = feature, fill = effect >= 0)) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
    ggplot2::geom_col(width = 0.7, colour = NA, show.legend = FALSE) +
    ggplot2::scale_fill_manual(values = c(`TRUE` = "#2ca25f", `FALSE` = "#de2d26")) +
    ggplot2::labs(
      x = "Approximate local contribution",
      y = NULL,
      title = "Local surrogate contributions",
      subtitle = sprintf(
        "Black-box prediction = %.3f | local surrogate = %.3f | fidelity = %.3f",
        x$diagnostics$prediction %||% NA_real_,
        x$result$local_prediction %||% NA_real_,
        x$result$fidelity %||% NA_real_
      )
    ) +
    .publication_theme()
}

#' @export
plot.funcml_lime <- function(x, ...) {
  plot.funcml_iml_local_model(x, ...)
}

#' @export
print.funcml_iml_local_model <- function(x, ...) {
  cat("<funcml_iml_local_model>\n")
  print(x$result$results)
  invisible(x)
}

#' @export
summary.funcml_iml_local_model <- function(object, ...) {
  print(object$result)
  invisible(object$result)
}

#' @export
plot.funcml_calibration <- function(x, style = c("curve", "histogram"), ...) {
  style <- match.arg(style)
  curve <- x$result$curve
  curve_nonempty <- curve[curve$n > 0, , drop = FALSE]

  if (style == "histogram") {
    hist_df <- data.frame(prob = x$result$prob, stringsAsFactors = FALSE)
    return(
      ggplot2::ggplot(hist_df, ggplot2::aes(x = prob)) +
        ggplot2::geom_histogram(bins = x$diagnostics$bins %||% 10L, fill = "grey80", colour = "white") +
        ggplot2::labs(
          x = sprintf("Predicted probability for '%s'", x$result$positive),
          y = "Count",
          title = "Predicted probability distribution"
        ) +
        .publication_theme()
    )
  }

  ggplot2::ggplot(curve_nonempty, ggplot2::aes(x = mean_pred, y = observed)) +
    ggplot2::geom_abline(intercept = 0, slope = 1, linetype = "dashed", colour = "grey55") +
    ggplot2::geom_line(colour = "black", linewidth = 0.7) +
    ggplot2::geom_point(ggplot2::aes(size = n), colour = "black") +
    ggplot2::geom_segment(
      ggplot2::aes(x = mean_pred, xend = mean_pred, y = 0, yend = observed),
      linewidth = 0.35,
      colour = "grey75"
    ) +
    ggplot2::scale_size_continuous(range = c(1.8, 5), guide = "none") +
    ggplot2::coord_equal(xlim = c(0, 1), ylim = c(0, 1)) +
    ggplot2::labs(
      x = sprintf("Mean predicted probability for '%s'", x$result$positive),
      y = "Observed event rate",
      title = "Calibration plot",
      subtitle = sprintf("ECE = %.4f | MCE = %.4f", x$result$ece, x$result$mce)
    ) +
    .publication_theme()
}

#' @export
print.funcml_calibration <- function(x, ...) {
  cat("<funcml_calibration>\n")
  print(x$result$curve)
  invisible(x)
}

#' @export
summary.funcml_calibration <- function(object, ...) {
  out <- list(
    curve = object$result$curve,
    ece = object$result$ece,
    mce = object$result$mce,
    positive = object$result$positive
  )
  print(out)
  invisible(out)
}

#' @export
plot.funcml_shap <- function(x, kind = c("auto", "waterfall", "force", "summary", "beeswarm", "importance", "bar", "dependence", "dependence2d", "interaction"), ...) {
  kind <- match.arg(kind)
  df <- x$result
  dots <- list(...)
  if (kind == "auto") {
    kind <- if (length(unique(df$observation)) > 1L) "summary" else "waterfall"
  }
  need_interactions <- identical(kind, "interaction") || isTRUE(dots$interactions)
  s_inter <- if (need_interactions) .funcml_shap_interaction_array(x, nsim = dots$nsim %||% NULL, seed = dots$seed %||% x$seed) else NULL
  sv <- .as_shapviz_object(df, S_inter = s_inter)
  if (!is.null(sv)) {
    if (kind == "waterfall") {
      plot_obj <- shapviz::sv_waterfall(
        sv,
        row_id = dots$row_id %||% min(df$observation),
        fill_colors = c("#2ca25f", "#de2d26")
      )
      return(.funcml_shapviz_style(plot_obj))
    }
    if (kind == "force") {
      plot_obj <- shapviz::sv_force(
        sv,
        row_id = dots$row_id %||% min(df$observation),
        fill_colors = c("#2ca25f", "#de2d26")
      )
      return(.funcml_shapviz_style(plot_obj))
    }
    if (kind %in% c("summary", "beeswarm")) {
      plot_obj <- shapviz::sv_importance(
        sv,
        kind = "beeswarm",
        show_numbers = FALSE
      )
      return(.funcml_shapviz_style(plot_obj))
    }
    if (kind %in% c("importance", "bar")) {
      plot_obj <- shapviz::sv_importance(
        sv,
        kind = "bar",
        show_numbers = FALSE,
        fill = "grey35"
      )
      return(.funcml_shapviz_style(plot_obj))
    }
    if (kind == "dependence") {
      v <- dots$v %||% x$features[1]
      color_var <- dots$color_var %||% "auto"
      plot_obj <- shapviz::sv_dependence(
        sv,
        v = v,
        color_var = color_var,
        interactions = isTRUE(dots$interactions)
      )
      return(.funcml_shapviz_style(plot_obj))
    }
    if (kind == "dependence2d") {
      x_var <- dots$feature_x %||% dots$x %||% x$features[1]
      y_var <- dots$feature_y %||% dots$y %||% x$features[min(2, length(x$features))]
      if (identical(x_var, y_var)) {
        stop("`x` and `y` must refer to two different features for `kind = \"dependence2d\"`.", call. = FALSE)
      }
      plot_obj <- shapviz::sv_dependence2D(
        sv,
        x = x_var,
        y = y_var,
        interactions = isTRUE(dots$interactions)
      )
      return(.funcml_shapviz_style(plot_obj))
    }
    if (kind == "interaction") {
      plot_obj <- shapviz::sv_interaction(
        sv,
        kind = dots$interaction_kind %||% "bar"
      )
      return(.funcml_shapviz_style(plot_obj))
    }
  }
  if (kind == "force") {
    df <- df[df$observation == (dots$row_id %||% min(df$observation)), , drop = FALSE]
    df <- df[order(abs(df$shap), decreasing = TRUE), , drop = FALSE]
    base <- df$baseline[1]
    pred <- df$prediction[1]
    df$feature <- factor(df$feature_label, levels = rev(df$feature_label))
    df$direction <- .funcml_direction(df$shap)
    return(
      ggplot2::ggplot(df, ggplot2::aes(x = shap, y = feature, fill = direction)) +
        ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
        ggplot2::geom_col(width = 0.7, colour = NA, show.legend = FALSE) +
        ggplot2::scale_fill_manual(values = c(increase = "#2ca25f", decrease = "#de2d26")) +
        ggplot2::labs(
          x = "SHAP contribution",
          y = NULL,
          title = "Approximate SHAP force plot",
          subtitle = sprintf("Baseline = %.3f | Final prediction = %.3f", base, pred)
        ) +
        .publication_theme()
    )
  }
  if (kind == "waterfall") {
    df <- df[df$observation == min(df$observation), , drop = FALSE]
    df <- df[order(abs(df$shap), decreasing = TRUE), , drop = FALSE]
    base <- df$baseline[1]
    x_range <- range(c(df$baseline[1], df$prediction[1], df$baseline[1] + cumsum(df$shap)))
    pad <- max(diff(x_range) * 0.08, 0.05)
    df$start <- c(base, base + cumsum(utils::head(df$shap, -1L)))
    df$end <- base + cumsum(df$shap)
    df$direction <- .funcml_direction(df$shap)
    df$feature <- factor(df$feature_label, levels = rev(df$feature_label))
    return(
      ggplot2::ggplot(df, ggplot2::aes(y = feature)) +
        ggplot2::geom_vline(xintercept = base, colour = "grey70", linewidth = 0.4, linetype = "dashed") +
        ggplot2::geom_vline(xintercept = df$prediction[1], colour = "grey40", linewidth = 0.4, linetype = "dotted") +
        ggplot2::geom_segment(ggplot2::aes(x = start, xend = end, yend = feature, colour = direction), linewidth = 5, lineend = "butt") +
        ggplot2::geom_point(ggplot2::aes(x = end, colour = direction), size = 2.1) +
        ggplot2::geom_text(
          ggplot2::aes(x = end, label = sprintf("%+.3f", shap), hjust = ifelse(shap >= 0, -0.15, 1.15)),
          size = 3,
          colour = "black"
        ) +
        ggplot2::labs(
          x = "SHAP contribution",
          y = NULL,
          title = "Approximate SHAP waterfall",
          subtitle = sprintf("Baseline = %.3f | Final prediction = %.3f", base, df$prediction[1])
        ) +
        ggplot2::expand_limits(x = c(x_range[1] - pad, x_range[2] + pad)) +
        .funcml_direction_scale_colour(guide = "none") +
        .publication_theme()
    )
  }
  if (kind %in% c("summary", "beeswarm")) {
    df$abs_shap <- abs(df$shap)
    ord <- stats::aggregate(abs_shap ~ feature, data = df, FUN = mean)
    ord <- ord[order(ord$abs_shap, decreasing = TRUE), "feature"]
    numeric_value <- suppressWarnings(as.numeric(df$feature_value))
    df$feature_value_scaled <- ave(
      numeric_value,
      df$feature,
      FUN = function(v) {
        if (all(is.na(v))) {
          rep(0.5, length(v))
        } else {
          rng <- range(v, na.rm = TRUE)
          if (!is.finite(rng[1]) || diff(rng) == 0) rep(0.5, length(v)) else (v - rng[1]) / diff(rng)
        }
      }
    )
    df$feature <- factor(df$feature, levels = rev(ord))
    return(
      ggplot2::ggplot(df, ggplot2::aes(x = shap, y = feature, colour = feature_value_scaled)) +
        ggplot2::geom_vline(xintercept = 0, colour = "grey75", linewidth = 0.4) +
        ggplot2::geom_point(
          position = ggplot2::position_jitter(height = 0.18, width = 0),
          alpha = 0.7,
          size = 1.6
        ) +
        ggplot2::scale_colour_gradient(low = "#2c7bb6", high = "#d7191c", name = "Feature value") +
        ggplot2::labs(
          x = "SHAP contribution",
          y = NULL,
          title = "Approximate SHAP summary"
        ) +
        .publication_theme()
    )
  }
  df$abs_shap <- abs(df$shap)
  imp <- stats::aggregate(abs_shap ~ feature, data = df, FUN = mean)
  imp <- imp[order(imp$abs_shap, decreasing = TRUE), , drop = FALSE]
  ggplot2::ggplot(imp, ggplot2::aes(x = abs_shap, y = stats::reorder(feature, abs_shap))) +
    ggplot2::geom_segment(ggplot2::aes(x = 0, xend = abs_shap, yend = feature), linewidth = 0.55, colour = "grey65") +
    ggplot2::geom_point(size = 2.3, colour = "black") +
    ggplot2::labs(x = "Mean |SHAP contribution|", y = NULL, title = "Approximate SHAP importance") +
    .publication_theme()
}

#' @export
print.funcml_shap <- function(x, ...) {
  cat("<funcml_shap>\n")
  print(utils::head(x$result, 10))
  invisible(x)
}

#' @export
summary.funcml_shap <- function(object, ...) {
  print(object$result)
  invisible(object$result)
}

#' @export
plot.funcml_surrogate <- function(x, ...) {
  surrogate_pred <- if (!is.null(x$result$nodes)) as.numeric(x$result$nodes) else as.numeric(stats::fitted(x$result$model))
  target <- tryCatch(as.numeric(x$result$model$y), error = function(e) NULL)
  if (is.null(target) || length(target) != length(surrogate_pred)) {
    surrogate_df <- data.frame(index = seq_along(surrogate_pred), surrogate = surrogate_pred)
    return(
      ggplot2::ggplot(surrogate_df, ggplot2::aes(x = index, y = surrogate)) +
        ggplot2::geom_line(colour = "black", linewidth = 0.55, alpha = 0.9) +
        ggplot2::labs(x = "Observation", y = "Surrogate prediction", title = "Global surrogate predictions") +
        .publication_theme()
    )
  }
  surrogate_df <- data.frame(target = target, surrogate = surrogate_pred)
  ggplot2::ggplot(surrogate_df, ggplot2::aes(x = target, y = surrogate)) +
    ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey65", linewidth = 0.5, linetype = "dashed") +
    ggplot2::geom_point(colour = "black", alpha = 0.65, size = 2) +
    ggplot2::geom_smooth(method = "lm", se = FALSE, formula = y ~ x, colour = "#3182bd", linewidth = 0.8) +
    ggplot2::labs(
      x = "Black-box prediction",
      y = "Surrogate prediction",
      title = "Global surrogate fidelity",
      subtitle = sprintf("R^2 = %.3f", x$result$fidelity)
    ) +
    .publication_theme()
}

#' @export
print.funcml_surrogate <- function(x, ...) {
  cat("<funcml_surrogate>\n")
  print(x$result$model)
  invisible(x)
}

#' @export
summary.funcml_surrogate <- function(object, ...) {
  print(summary(object$result$model))
  invisible(summary(object$result$model))
}

#' @export
plot.funcml_interaction <- function(x, ...) {
  pairwise <- x$result$pairwise
  pairwise$feature_x <- factor(pairwise$feature_x, levels = unique(pairwise$feature_x))
  pairwise$feature_y <- factor(pairwise$feature_y, levels = rev(unique(pairwise$feature_y)))
  ggplot2::ggplot(pairwise, ggplot2::aes(x = feature_x, y = feature_y, fill = interaction)) +
    ggplot2::geom_tile(colour = "white") +
    ggplot2::scale_fill_gradient(low = "white", high = "#08519c", name = "Interaction") +
    ggplot2::labs(
      x = "Feature",
      y = "Feature",
      title = if (is.null(x$result$anchor_feature)) "Feature interaction heatmap" else sprintf("Interaction heatmap for %s", x$result$anchor_feature)
    ) +
    .publication_theme() +
    ggplot2::theme(panel.grid = ggplot2::element_blank())
}

#' @export
print.funcml_interaction <- function(x, ...) {
  cat("<funcml_interaction>\n")
  print(x$result$results)
  invisible(x)
}

#' @export
summary.funcml_interaction <- function(object, ...) {
  print(object$result$results)
  invisible(object$result$results)
}
