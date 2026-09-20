#' Default tuning grid for a learner.
#'
#' Returns a small, sensible hyperparameter grid for a learner, so that
#' [tune()] and [compare()] with `tune = TRUE` work without the user writing
#' a grid. Grids that depend on the data (for example `mtry`, `ncomp`, `k`, and
#' the SVM `gamma`) are sized from the number of encoded predictors and the
#' number of rows of `data`. Parameter names are the ones of each learner's
#' `spec` (see [fit()]).
#'
#' @param model Learner id, as in [list_learners()].
#' @param data Optional data frame, used to size data-dependent parameters.
#' @param formula Optional model formula, used together with `data`.
#' @return A data frame with one row per configuration, or `NULL` for learners
#'   with no tunable hyperparameters (`glm`, `lda`, `qda`, `fda`, `stacking`,
#'   `superlearner`).
#' @examples
#' default_tune_grid("rpart")
#' default_tune_grid("ranger", data = mtcars, formula = mpg ~ .)
#' @export
default_tune_grid <- function(model, data = NULL, formula = NULL) {
  if (!is.character(model) || length(model) != 1L) {
    stop("`model` must be a single learner id.", call. = FALSE)
  }
  known <- names(funcml_registry())
  if (!model %in% known) {
    stop(sprintf("Unknown learner '%s'.", model), call. = FALSE)
  }
  p <- 10L
  n <- 200L
  if (!is.null(data) && !is.null(formula)) {
    mm <- tryCatch(
      stats::model.matrix(formula, stats::model.frame(formula, data, na.action = stats::na.pass)),
      error = function(e) NULL
    )
    if (!is.null(mm)) {
      p <- max(1L, ncol(mm) - 1L)
      n <- nrow(mm)
    }
  }
  mtry <- sort(unique(pmax(1L, pmin(p, as.integer(round(c(0.5, 1, 2) * sqrt(p)))))))
  g <- function(...) {
    out <- expand.grid(..., stringsAsFactors = FALSE, KEEP.OUT.ATTRS = FALSE)
    rownames(out) <- NULL
    out
  }
  switch(model,
    rpart = g(cp = c(0.001, 0.005, 0.01, 0.05), minsplit = c(5, 20)),
    glmnet = g(alpha = c(0, 0.5, 1), lambda = c(1e-4, 1e-3, 1e-2, 0.05, 0.1, 0.3)),
    ranger = g(num.trees = 500, mtry = mtry, min.node.size = c(1, 5, 10)),
    nnet = g(size = c(3, 5, 10), decay = c(0.001, 0.01, 0.1)),
    mlp = g(lr = c(0.001, 0.01), dropout = c(0, 0.2), weight_decay = c(0, 1e-3)),
    densemlp = g(lr = c(0.001, 0.01), dropout = c(0, 0.2), epochs = c(50, 100)),
    e1071_svm = g(cost = c(0.25, 1, 4, 16), gamma = c(0.25, 1, 4) / p),
    randomForest = g(ntree = 500, mtry = mtry, nodesize = c(1, 5, 10)),
    gbm = g(n.trees = c(100, 300), interaction.depth = c(1, 3, 5), shrinkage = c(0.01, 0.05, 0.1)),
    C50 = g(trials = c(1, 5, 10, 20), model = c("tree", "rules")),
    kknn = g(k = sort(unique(pmax(1L, pmin(c(3L, 5L, 7L, 11L, 15L, 25L), as.integer(floor(n / 2)))))), distance = c(1, 2)),
    earth = g(degree = c(1, 2), nprune = c(5, 10, 15)),
    gam = g(method = c("REML", "GCV.Cp")),
    naivebayes = g(laplace = c(0, 0.5, 1), usekernel = c(FALSE, TRUE)),
    adaboost = g(iter = c(25, 50, 100), nu = c(0.05, 0.1, 0.5)),
    pls = g(ncomp = sort(unique(pmax(1L, pmin(c(1L, 2L, 3L, 5L, 8L), p, n - 1L))))),
    ctree = g(mincriterion = c(0.9, 0.95, 0.99)),
    cforest = g(ntree = 200, mtry = mtry, mincriterion = c(0, 0.5, 0.9)),
    lightgbm = g(num_leaves = c(7, 15, 31), learning_rate = c(0.02, 0.05, 0.1), nrounds = c(100, 300)),
    bart = g(ntree = c(50, 100, 200)),
    xgboost = g(max_depth = c(2, 4, 6), eta = c(0.05, 0.1, 0.3), nrounds = c(100, 300)),
    fastgbm = g(max_depth = c(3, 5, 7), learning_rate = c(0.05, 0.1), ntrees = c(100, 300)),
    NULL
  )
}
