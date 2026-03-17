#' Regression and classification metrics.
#'
#' Base R implementations used across evaluation and interpretation utilities.
#'
#' @param truth Observed outcomes.
#' @param pred Predicted numeric values or class labels.
#' @param prob_matrix Matrix or vector of predicted probabilities (classification).
#' @param pred_class Predicted class labels (classification).
#' @param prob Probability vector for binary classification metrics.
#' @return Numeric scalar metric.
#' @name metrics
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
rsq <- function(truth, pred) {
  1 - sum((truth - pred)^2) / sum((truth - mean(truth))^2)
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

.loss <- function(truth, pred, task, metric, prob_matrix = NULL) {
  metric <- match.arg(metric, c("rmse", "mae", "rsq", "logloss", "brier", "accuracy", "auc"))
  if (task == "regression" && metric %in% c("logloss", "brier", "accuracy", "auc")) {
    stop(sprintf("Metric '%s' is classification-only.", metric), call. = FALSE)
  }
  if (task == "classification" && metric %in% c("rmse", "mae", "rsq")) {
    stop(sprintf("Metric '%s' is regression-only.", metric), call. = FALSE)
  }

  if (task == "regression") {
    return(switch(metric,
                  rmse = rmse(truth, pred),
                  mae = mae(truth, pred),
                  rsq = rsq(truth, pred)))
  }

  truth <- factor(truth)
  pred_class <- if (is.null(pred)) NULL else factor(pred, levels = levels(truth))
  if (metric %in% c("logloss", "brier", "auc")) {
    if (is.null(prob_matrix)) stop(sprintf("Metric '%s' requires probabilities.", metric), call. = FALSE)
    prob_matrix <- .normalize_prob_matrix(prob_matrix, levels(truth))
  }

  switch(
    metric,
    accuracy = accuracy(truth, pred_class),
    logloss = logloss(truth, prob_matrix),
    brier = brier(truth, prob_matrix),
    auc = {
      if (length(levels(truth)) != 2) stop("AUC defined for binary classification only.", call. = FALSE)
      auc(truth, prob_matrix[, levels(truth)[2]])
    }
  )
}
