#' Regression and classification metrics.
#'
#' Base R implementations used across evaluation and interpretation utilities.
#'
#' @param truth Observed outcomes.
#' @param pred Predicted numeric values or class labels.
#' @param prob_matrix Matrix or vector of predicted probabilities (classification).
#' @param pred_class Predicted class labels (classification).
#' @param prob Probability vector for binary classification metrics.
#' @param bins Number of bins for calibration summaries.
#' @param strategy Binning strategy: `"quantile"` or `"uniform"`.
#' @param positive Optional positive/event class for binary classification.
#' @return Numeric scalar metric.
#' @name metrics
#' @examples
#' truth_reg <- c(3, 5, 2.5, 7)
#' pred_reg <- c(2.8, 4.9, 2.7, 6.8)
#' rmse(truth_reg, pred_reg)
#' mae(truth_reg, pred_reg)
#' mse(truth_reg, pred_reg)
#' rsq(truth_reg, pred_reg)
#' medae(truth_reg, pred_reg)
#' mape(truth_reg, pred_reg)
#'
#' truth_cls <- factor(c("no", "yes", "yes", "no"), levels = c("no", "yes"))
#' pred_cls <- factor(c("no", "yes", "no", "no"), levels = levels(truth_cls))
#' prob_cls <- cbind(
#'   no = c(0.8, 0.2, 0.6, 0.7),
#'   yes = c(0.2, 0.8, 0.4, 0.3)
#' )
#' logloss(truth_cls, prob_cls)
#' brier(truth_cls, prob_cls)
#' accuracy(truth_cls, pred_cls)
#' precision(truth_cls, pred_cls)
#' recall(truth_cls, pred_cls)
#' specificity(truth_cls, pred_cls)
#' f1(truth_cls, pred_cls)
#' balanced_accuracy(truth_cls, pred_cls)
#' auc(truth_cls, prob_cls[, "yes"])
#' calibration_curve(truth_cls, prob_cls[, "yes"])
#' ece(truth_cls, prob_cls[, "yes"])
#' mce(truth_cls, prob_cls[, "yes"])
#' @export
rmse <- function(truth, pred) {
  sqrt(mean((truth - pred)^2))
}

#' @rdname metrics
#' @export
mae <- function(truth, pred) {
  mean(abs(truth - pred))
}

#' @rdname metrics
#' @export
mse <- function(truth, pred) {
  mean((truth - pred)^2)
}

#' @rdname metrics
#' @export
rsq <- function(truth, pred) {
  1 - sum((truth - pred)^2) / sum((truth - mean(truth))^2)
}

#' @rdname metrics
#' @export
medae <- function(truth, pred) {
  stats::median(abs(truth - pred))
}

#' @rdname metrics
#' @export
mape <- function(truth, pred) {
  denom <- abs(truth)
  keep <- denom > .Machine$double.eps
  if (!any(keep)) {
    return(NA_real_)
  }
  mean(abs((truth[keep] - pred[keep]) / truth[keep]))
}

#' @rdname metrics
#' @export
logloss <- function(truth, prob_matrix) {
  if (!is.matrix(prob_matrix)) prob_matrix <- cbind(1 - prob_matrix, prob_matrix)
  truth_idx <- match(truth, colnames(prob_matrix))
  p <- prob_matrix[cbind(seq_along(truth_idx), truth_idx)]
  -mean(log(p + 1e-15))
}

#' @rdname metrics
#' @export
brier <- function(truth, prob_matrix) {
  if (!is.matrix(prob_matrix)) prob_matrix <- cbind(1 - prob_matrix, prob_matrix)
  truth_onehot <- matrix(0, nrow = length(truth), ncol = ncol(prob_matrix))
  colnames(truth_onehot) <- colnames(prob_matrix)
  truth_onehot[cbind(seq_along(truth), match(truth, colnames(prob_matrix)))] <- 1
  mean(rowSums((prob_matrix - truth_onehot)^2))
}

#' @rdname metrics
#' @export
accuracy <- function(truth, pred_class) {
  mean(truth == pred_class)
}

#' @rdname metrics
#' @export
precision <- function(truth, pred_class) {
  .macro_class_metric(truth, pred_class, numerator = function(tp, fp, fn, tn) tp, denominator = function(tp, fp, fn, tn) tp + fp)
}

#' @rdname metrics
#' @export
recall <- function(truth, pred_class) {
  .macro_class_metric(truth, pred_class, numerator = function(tp, fp, fn, tn) tp, denominator = function(tp, fp, fn, tn) tp + fn)
}

#' @rdname metrics
#' @export
specificity <- function(truth, pred_class) {
  .macro_class_metric(truth, pred_class, numerator = function(tp, fp, fn, tn) tn, denominator = function(tp, fp, fn, tn) tn + fp)
}

#' @rdname metrics
#' @export
f1 <- function(truth, pred_class) {
  prec <- precision(truth, pred_class)
  rec <- recall(truth, pred_class)
  if (!is.finite(prec) || !is.finite(rec) || (prec + rec) == 0) {
    return(NA_real_)
  }
  2 * prec * rec / (prec + rec)
}

#' @rdname metrics
#' @export
balanced_accuracy <- function(truth, pred_class) {
  recall(truth, pred_class)
}

#' @rdname metrics
#' @export
auc <- function(truth, prob) {
  if (!is.factor(truth)) truth <- factor(truth)
  if (length(levels(truth)) != 2) stop("AUC defined for binary classification only.", call. = FALSE)
  pos <- levels(truth)[2]
  truth_binary <- as.integer(truth == pos)
  ord <- order(prob)
  ranks <- rank(prob)
  pos_ranks <- ranks[truth_binary == 1]
  m <- sum(truth_binary == 0)
  n <- sum(truth_binary == 1)
  if (m == 0 || n == 0) return(NA_real_)
  (sum(pos_ranks) - n * (n + 1) / 2) / (m * n)
}

.macro_class_metric <- function(truth, pred_class, numerator, denominator) {
  if (!is.factor(truth)) {
    truth <- factor(truth)
  }
  pred_class <- factor(pred_class, levels = levels(truth))
  vals <- vapply(levels(truth), function(level) {
    tp <- sum(truth == level & pred_class == level, na.rm = TRUE)
    fp <- sum(truth != level & pred_class == level, na.rm = TRUE)
    fn <- sum(truth == level & pred_class != level, na.rm = TRUE)
    tn <- sum(truth != level & pred_class != level, na.rm = TRUE)
    denom <- denominator(tp, fp, fn, tn)
    if (denom == 0) {
      return(NA_real_)
    }
    numerator(tp, fp, fn, tn) / denom
  }, numeric(1))
  mean(vals, na.rm = TRUE)
}

.binary_truth_prob <- function(truth, prob, positive = NULL) {
  if (!is.factor(truth)) {
    truth <- factor(truth)
  }
  if (length(levels(truth)) != 2L) {
    stop("Calibration metrics are defined for binary classification only.", call. = FALSE)
  }
  positive <- positive %||% levels(truth)[2L]
  if (!(positive %in% levels(truth))) {
    stop("`positive` must be one of the outcome levels.", call. = FALSE)
  }
  prob_vec <- if (is.matrix(prob) || is.data.frame(prob)) {
    prob <- as.matrix(prob)
    if (is.null(colnames(prob)) || !(positive %in% colnames(prob))) {
      stop("Probability matrix must include a column for the positive class.", call. = FALSE)
    }
    prob[, positive]
  } else {
    as.numeric(prob)
  }
  if (length(prob_vec) != length(truth)) {
    stop("`truth` and `prob` must have the same length.", call. = FALSE)
  }
  list(
    truth = as.integer(truth == positive),
    prob = prob_vec,
    positive = positive,
    levels = levels(truth)
  )
}

.calibration_breaks <- function(prob, bins = 10, strategy = c("quantile", "uniform")) {
  strategy <- match.arg(strategy)
  if (!is.numeric(bins) || length(bins) != 1L || bins < 1L) {
    stop("`bins` must be a positive integer.", call. = FALSE)
  }
  bins <- as.integer(bins)
  if (strategy == "quantile") {
    breaks <- unique(stats::quantile(prob, probs = seq(0, 1, length.out = bins + 1L), na.rm = TRUE, names = FALSE))
  } else {
    breaks <- seq(0, 1, length.out = bins + 1L)
  }
  if (length(breaks) < 2L) {
    breaks <- c(0, 1)
  }
  breaks[1] <- min(breaks[1], 0)
  breaks[length(breaks)] <- max(breaks[length(breaks)], 1)
  breaks
}

#' @rdname metrics
#' @export
calibration_curve <- function(truth, prob, bins = 10, strategy = c("quantile", "uniform"), positive = NULL) {
  parsed <- .binary_truth_prob(truth, prob, positive = positive)
  strategy <- match.arg(strategy)
  breaks <- .calibration_breaks(parsed$prob, bins = bins, strategy = strategy)
  bin_id <- cut(parsed$prob, breaks = breaks, include.lowest = TRUE, right = TRUE, labels = FALSE)
  observed <- split(parsed$truth, bin_id)
  predicted <- split(parsed$prob, bin_id)
  all_bins <- seq_len(length(breaks) - 1L)

  out <- lapply(all_bins, function(i) {
    prob_i <- predicted[[as.character(i)]]
    truth_i <- observed[[as.character(i)]]
    if (is.null(prob_i)) {
      prob_i <- numeric()
      truth_i <- numeric()
    }
    n_i <- length(prob_i)
    mean_pred <- if (n_i) mean(prob_i) else NA_real_
    obs_rate <- if (n_i) mean(truth_i) else NA_real_
    data.frame(
      bin = i,
      lower = breaks[i],
      upper = breaks[i + 1L],
      midpoint = (breaks[i] + breaks[i + 1L]) / 2,
      n = n_i,
      mean_pred = mean_pred,
      observed = obs_rate,
      abs_gap = if (n_i) abs(obs_rate - mean_pred) else NA_real_,
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, out)
}

#' @rdname metrics
#' @export
ece <- function(truth, prob, bins = 10, strategy = c("quantile", "uniform"), positive = NULL) {
  curve <- calibration_curve(truth, prob, bins = bins, strategy = strategy, positive = positive)
  nonempty <- curve$n > 0
  if (!any(nonempty)) {
    return(NA_real_)
  }
  sum((curve$n[nonempty] / sum(curve$n[nonempty])) * curve$abs_gap[nonempty])
}

#' @rdname metrics
#' @export
mce <- function(truth, prob, bins = 10, strategy = c("quantile", "uniform"), positive = NULL) {
  curve <- calibration_curve(truth, prob, bins = bins, strategy = strategy, positive = positive)
  nonempty <- curve$n > 0
  if (!any(nonempty)) {
    return(NA_real_)
  }
  max(curve$abs_gap[nonempty])
}

.loss <- function(truth, pred, task, metric, prob_matrix = NULL) {
  metric <- match.arg(metric, c(
    "rmse", "mae", "mse", "medae", "mape", "rsq",
    "logloss", "brier", "accuracy", "precision", "recall",
    "specificity", "f1", "balanced_accuracy", "auc", "ece", "mce"
  ))
  if (task == "regression" && metric %in% c("logloss", "brier", "accuracy", "precision", "recall", "specificity", "f1", "balanced_accuracy", "auc", "ece", "mce")) {
    stop(sprintf("Metric '%s' is classification-only.", metric), call. = FALSE)
  }
  if (task == "classification" && metric %in% c("rmse", "mae", "mse", "medae", "mape", "rsq")) {
    stop(sprintf("Metric '%s' is regression-only.", metric), call. = FALSE)
  }

  if (task == "regression") {
    return(switch(metric,
                  rmse = rmse(truth, pred),
                  mae = mae(truth, pred),
                  mse = mse(truth, pred),
                  medae = medae(truth, pred),
                  mape = mape(truth, pred),
                  rsq = rsq(truth, pred)))
  }

  truth <- factor(truth)
  pred_class <- if (is.null(pred)) NULL else factor(pred, levels = levels(truth))
  if (metric %in% c("logloss", "brier", "auc", "ece", "mce")) {
    if (is.null(prob_matrix)) stop(sprintf("Metric '%s' requires probabilities.", metric), call. = FALSE)
    prob_matrix <- .normalize_prob_matrix(prob_matrix, levels(truth))
  }

  switch(
    metric,
    accuracy = accuracy(truth, pred_class),
    precision = precision(truth, pred_class),
    recall = recall(truth, pred_class),
    specificity = specificity(truth, pred_class),
    f1 = f1(truth, pred_class),
    balanced_accuracy = balanced_accuracy(truth, pred_class),
    logloss = logloss(truth, prob_matrix),
    brier = brier(truth, prob_matrix),
    ece = ece(truth, prob_matrix),
    mce = mce(truth, prob_matrix),
    auc = {
      if (length(levels(truth)) != 2) stop("AUC defined for binary classification only.", call. = FALSE)
      auc(truth, prob_matrix[, levels(truth)[2]])
    }
  )
}
