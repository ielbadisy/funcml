#' Resampling specification generator.
#'
#' @param v Number of folds for cross-validation.
#' @param repeats Number of repeats for standard or grouped cross-validation.
#' @param strata Logical; stratify classification outcomes when supported.
#' @param seed Optional seed for reproducibility.
#' @param method Resampling strategy: `"vfold"`, `"holdout"`, `"group_vfold"`,
#'   or `"time"`.
#' @param prop Training-set proportion for holdout splits.
#' @param group Optional grouping variable name or vector for grouped CV.
#' @param time Optional ordering variable name or vector for time-aware splits.
#' @param initial Initial training window size for time-aware CV.
#' @param assess Assessment window size for time-aware CV.
#' @param skip Number of observations to skip between successive time splits.
#' @param cumulative Logical; use an expanding training window for time-aware CV.
#' @return A `funcml_cv` object containing fold indices and parameters.
#' @examples
#' cv(v = 3, repeats = 2, seed = 1)
#' @export
cv <- function(v = 5, repeats = 1, strata = TRUE, seed = NULL,
               method = c("vfold", "holdout", "group_vfold", "time"),
               prop = 0.8, group = NULL, time = NULL,
               initial = NULL, assess = NULL, skip = 0, cumulative = TRUE) {
  method <- match.arg(method)
  res <- list(
    method = method,
    v = v,
    repeats = repeats,
    strata = strata,
    seed = seed,
    prop = prop,
    group = group,
    time = time,
    initial = initial,
    assess = assess,
    skip = skip,
    cumulative = cumulative,
    folds = NULL
  )
  class(res) <- "funcml_cv"
  res
}

#' Plain holdout resampling.
#'
#' @param prop Training-set proportion.
#' @param strata Logical; stratify classification outcomes.
#' @param seed Optional seed.
#' @return A `funcml_cv` object.
#' @examples
#' holdout(prop = 0.75, seed = 1)
#' @export
holdout <- function(prop = 0.8, strata = TRUE, seed = NULL) {
  cv(method = "holdout", prop = prop, strata = strata, seed = seed, v = 1, repeats = 1)
}

#' Grouped cross-validation.
#'
#' @param v Number of folds.
#' @param group Grouping variable name or vector.
#' @param repeats Number of repeats.
#' @param seed Optional seed.
#' @return A `funcml_cv` object.
#' @examples
#' group_cv(v = 3, group = rep(letters[1:3], each = 4), seed = 1)
#' @export
group_cv <- function(v = 5, group, repeats = 1, seed = NULL) {
  cv(method = "group_vfold", v = v, repeats = repeats, seed = seed, strata = FALSE, group = group)
}

#' Time-aware rolling resampling.
#'
#' @param initial Initial training window size.
#' @param assess Assessment window size.
#' @param time Ordering variable name or vector.
#' @param skip Number of observations to skip between splits.
#' @param cumulative Logical; use an expanding training window.
#' @param seed Optional seed.
#' @return A `funcml_cv` object.
#' @examples
#' time_cv(initial = 8, assess = 2, skip = 1)
#' @export
time_cv <- function(initial, assess = 1, time = NULL, skip = 0, cumulative = TRUE, seed = NULL) {
  cv(
    method = "time",
    v = NULL,
    repeats = 1,
    strata = FALSE,
    seed = seed,
    time = time,
    initial = initial,
    assess = assess,
    skip = skip,
    cumulative = cumulative
  )
}

.resolve_resampling_var <- function(spec, data, n, arg) {
  if (is.null(spec)) {
    return(NULL)
  }
  if (is.character(spec) && length(spec) == 1L) {
    if (is.null(data) || !spec %in% names(data)) {
      stop(sprintf("Resampling `%s` column '%s' not found in `data`.", arg, spec), call. = FALSE)
    }
    return(data[[spec]])
  }
  if (length(spec) != n) {
    stop(sprintf("Resampling `%s` must have length %d.", arg, n), call. = FALSE)
  }
  spec
}

.assign_stratified_folds <- function(ids, y, v) {
  fold_assign <- integer(length(ids))
  splits <- split(ids, y)
  for (lvl in names(splits)) {
    members <- sample(splits[[lvl]])
    assign <- rep(seq_len(v), length.out = length(members))
    fold_assign[match(members, ids)] <- assign
  }
  fold_assign
}

.generate_vfolds <- function(idx, y, resampling) {
  folds <- list()
  for (r in seq_len(resampling$repeats)) {
    if (!is.null(y) && isTRUE(resampling$strata) && is.factor(y)) {
      fold_assign <- .assign_stratified_folds(idx, y, resampling$v)
    } else {
      fold_assign <- sample(rep(seq_len(resampling$v), length.out = length(idx)))
    }
    for (fold in seq_len(resampling$v)) {
      test_idx <- idx[fold_assign == fold]
      train_idx <- setdiff(idx, test_idx)
      folds[[length(folds) + 1L]] <- list(train = train_idx, test = test_idx, repeat_id = r, fold = fold)
    }
  }
  folds
}

.generate_holdout <- function(idx, y, resampling) {
  n <- length(idx)
  prop <- resampling$prop %||% 0.8
  if (!is.numeric(prop) || length(prop) != 1L || !is.finite(prop) || prop <= 0 || prop >= 1) {
    stop("`prop` must be a single number strictly between 0 and 1.", call. = FALSE)
  }
  train_n <- max(1L, min(n - 1L, floor(prop * n)))
  if (!is.null(y) && isTRUE(resampling$strata) && is.factor(y)) {
    train_mask <- logical(n)
    for (lvl in levels(y)) {
      members <- which(y == lvl)
      n_lvl <- length(members)
      take <- max(1L, min(n_lvl - 1L, floor(prop * n_lvl)))
      train_mask[sample(members, size = take)] <- TRUE
    }
    train_idx <- idx[train_mask]
    test_idx <- idx[!train_mask]
  } else {
    train_idx <- sort(sample(idx, size = train_n))
    test_idx <- setdiff(idx, train_idx)
  }
  list(list(train = train_idx, test = test_idx, repeat_id = 1L, fold = 1L))
}

.generate_group_vfolds <- function(idx, groups, resampling) {
  groups <- as.vector(groups)
  if (anyNA(groups)) {
    stop("Grouped resampling does not allow missing `group` values.", call. = FALSE)
  }
  uniq_groups <- unique(groups)
  if (length(uniq_groups) < 2L) {
    stop("Grouped resampling requires at least two groups.", call. = FALSE)
  }
  if (!is.numeric(resampling$v) || resampling$v < 2L || resampling$v > length(uniq_groups)) {
    stop("For grouped CV, `v` must be between 2 and the number of unique groups.", call. = FALSE)
  }

  folds <- list()
  for (r in seq_len(resampling$repeats)) {
    group_ids <- sample(uniq_groups)
    group_fold <- rep(seq_len(resampling$v), length.out = length(group_ids))
    names(group_fold) <- as.character(group_ids)
    fold_assign <- unname(group_fold[as.character(groups)])
    for (fold in seq_len(resampling$v)) {
      test_idx <- idx[fold_assign == fold]
      train_idx <- idx[fold_assign != fold]
      folds[[length(folds) + 1L]] <- list(train = train_idx, test = test_idx, repeat_id = r, fold = fold)
    }
  }
  folds
}

.generate_time_folds <- function(idx, order_index, resampling) {
  if (anyNA(order_index)) {
    stop("Time-aware resampling does not allow missing `time` values.", call. = FALSE)
  }
  ord <- order(order_index, idx)
  idx_ord <- idx[ord]
  n <- length(idx_ord)
  initial <- resampling$initial %||% max(1L, floor(n / 2))
  assess <- resampling$assess %||% max(1L, floor(n / 5))
  skip <- resampling$skip %||% 0L
  if (initial < 1L || assess < 1L) {
    stop("`initial` and `assess` must be positive integers.", call. = FALSE)
  }
  if ((initial + assess) > n) {
    stop("Time-aware resampling requires `initial + assess` to be at most the data size.", call. = FALSE)
  }

  folds <- list()
  split_id <- 1L
  train_end <- initial
  while ((train_end + assess) <= n) {
    test_start <- train_end + 1L
    test_end <- train_end + assess
    train_start <- if (isTRUE(resampling$cumulative)) 1L else max(1L, train_end - initial + 1L)
    folds[[length(folds) + 1L]] <- list(
      train = idx_ord[seq.int(train_start, train_end)],
      test = idx_ord[seq.int(test_start, test_end)],
      repeat_id = 1L,
      fold = split_id
    )
    split_id <- split_id + 1L
    train_end <- train_end + assess + skip
  }
  if (!length(folds)) {
    stop("Time-aware resampling could not create any splits from the supplied settings.", call. = FALSE)
  }
  folds
}

generate_folds <- function(n, y = NULL, resampling = cv(), data = NULL) {
  if (!is.null(resampling$seed)) set.seed(resampling$seed)
  idx <- seq_len(n)
  method <- resampling$method %||% "vfold"

  if (!is.null(y) && length(y) != n) {
    stop("`y` must have length `n` when supplied.", call. = FALSE)
  }

  folds <- switch(
    method,
    vfold = .generate_vfolds(idx, y, resampling),
    holdout = .generate_holdout(idx, y, resampling),
    group_vfold = {
      groups <- .resolve_resampling_var(resampling$group, data = data, n = n, arg = "group")
      if (is.null(groups)) {
        stop("Grouped CV requires `group` to be supplied.", call. = FALSE)
      }
      .generate_group_vfolds(idx, groups, resampling)
    },
    time = {
      order_index <- .resolve_resampling_var(resampling$time, data = data, n = n, arg = "time")
      if (is.null(order_index)) {
        order_index <- idx
      }
      .generate_time_folds(idx, order_index, resampling)
    },
    stop(sprintf("Unknown resampling method '%s'.", method), call. = FALSE)
  )

  resampling$folds <- folds
  resampling
}
