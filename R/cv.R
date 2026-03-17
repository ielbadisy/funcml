#' Cross-validation fold generator.
#'
#' @param v Number of folds.
#' @param repeats Number of repeats.
#' @param strata Logical; stratify classification outcomes.
#' @param seed Optional seed for reproducibility.
#' @return A `funcml_cv` object containing fold indices and parameters.
#' @export
cv <- function(v = 5, repeats = 1, strata = TRUE, seed = NULL) {
  res <- list(v = v, repeats = repeats, strata = strata, seed = seed, folds = NULL)
  class(res) <- "funcml_cv"
  res
}

generate_folds <- function(n, y = NULL, resampling = cv()) {
  if (!is.null(resampling$seed)) set.seed(resampling$seed)
  folds <- list()
  idx <- seq_len(n)
  for (r in seq_len(resampling$repeats)) {
    if (!is.null(y) && resampling$strata && is.factor(y)) {
      # stratified sampling
      splits <- split(idx, y)
      fold_assign <- integer(n)
      for (lvl in names(splits)) {
        ids <- sample(splits[[lvl]])
        k <- length(ids)
        assign <- rep(seq_len(resampling$v), length.out = k)
        fold_assign[ids] <- assign
      }
    } else {
      fold_assign <- sample(rep(seq_len(resampling$v), length.out = n))
    }
    for (fold in seq_len(resampling$v)) {
      test_idx <- which(fold_assign == fold)
      train_idx <- setdiff(idx, test_idx)
      folds[[length(folds) + 1]] <- list(train = train_idx, test = test_idx, repeat_id = r, fold = fold)
    }
  }
  resampling$folds <- folds
  resampling
}
