# Learner registry definitions.

.ensemble_allowed_learners <- function(task) {
  reg <- funcml_registry()
  ids <- setdiff(names(reg), c("stacking", "superlearner"))
  keep <- vapply(ids, function(id) task %in% reg[[id]]$tasks, logical(1))
  ids[keep]
}

.ensemble_default_learners <- function(task) {
  candidates <- if (task == "regression") {
    c("glm", "rpart", "kknn")
  } else {
    c("glm", "rpart", "kknn", "nnet")
  }
  allowed <- .ensemble_allowed_learners(task)
  out <- candidates[candidates %in% allowed]
  if (!length(out)) {
    out <- allowed[seq_len(min(1L, length(allowed)))]
  }
  out
}

.ensemble_prepare_specs <- function(learners, learner_specs) {
  specs <- vector("list", length(learners))
  names(specs) <- learners
  for (id in learners) {
    specs[[id]] <- learner_specs[[id]] %||% list()
  }
  specs
}

.ensemble_validate_learners <- function(learners, task) {
  if (length(learners) < 1L) {
    stop("Ensemble learners require at least one base learner.", call. = FALSE)
  }
  if (any(learners %in% c("stacking", "superlearner"))) {
    stop("Ensemble learners cannot include 'stacking' or 'superlearner' as base learners.", call. = FALSE)
  }
  allowed <- .ensemble_allowed_learners(task)
  bad <- setdiff(learners, allowed)
  if (length(bad)) {
    stop("Unsupported base learners for this task: ", paste(bad, collapse = ", "), call. = FALSE)
  }
}

.ensemble_prob_matrix <- function(pred, levels) {
  prob <- .normalize_prob_matrix(pred, levels)
  prob[, levels, drop = FALSE]
}

.ensemble_feature_names <- function(learners, levels = NULL) {
  if (is.null(levels)) {
    learners
  } else if (length(levels) == 2L) {
    learners
  } else {
    unlist(lapply(learners, function(id) paste(id, levels, sep = "__")), use.names = FALSE)
  }
}

.ensemble_meta_matrix <- function(pred_list, learners, levels = NULL) {
  cols <- lapply(learners, function(id) {
    pred <- pred_list[[id]]
    if (is.null(levels)) {
      out <- matrix(as.numeric(pred), ncol = 1L)
      colnames(out) <- id
      return(out)
    }
    prob <- .ensemble_prob_matrix(pred, levels)
    if (length(levels) == 2L) {
      out <- matrix(prob[, levels[2L]], ncol = 1L)
      colnames(out) <- id
      return(out)
    }
    colnames(prob) <- paste(id, levels, sep = "__")
    prob
  })
  out <- do.call(cbind, cols)
  if (!is.matrix(out)) {
    out <- matrix(out, ncol = length(cols))
  }
  out
}

.ensemble_fit_base_models <- function(X, y, learners, learner_specs, task, levels) {
  lapply(learners, function(id) {
    adapter <- funcml_registry(id)
    spec <- merge_spec(adapter$defaults, learner_specs[[id]], list())
    list(
      id = id,
      adapter = adapter,
      spec = spec,
      state = adapter$fit_xy(X, y, spec, task = task, levels = levels)
    )
  })
}

.ensemble_predict_base_models <- function(base_models, Xnew, task, levels) {
  out <- vector("list", length(base_models))
  names(out) <- vapply(base_models, `[[`, character(1), "id")
  for (i in seq_along(base_models)) {
    model <- base_models[[i]]
    type <- if (is.null(levels)) "response" else "prob"
    out[[model$id]] <- model$adapter$predict_xy(
      model$state,
      Xnew,
      type = type,
      levels = levels,
      spec = model$spec,
      task = task
    )
  }
  out
}

.ensemble_fit_meta <- function(meta_x, y, task, levels = NULL, meta_model = "native") {
  meta_x <- as.matrix(meta_x)
  if (task == "classification") {
    meta_x <- pmin(pmax(meta_x, 1e-6), 1 - 1e-6)
  }
  if (identical(task, "classification") && length(levels) > 2L && identical(meta_model, "native")) {
    meta_model <- "glmnet"
  }

  if (identical(meta_model, "glmnet")) {
    assert_package("glmnet", "stacking")
    lambda <- 1e-3
    if (identical(task, "regression")) {
      fit <- glmnet::glmnet(
        x = meta_x,
        y = as.numeric(y),
        family = "gaussian",
        alpha = 0,
        lambda = lambda,
        standardize = FALSE
      )
      return(list(task = task, engine = "glmnet_gaussian", fit = fit, lambda = lambda))
    }
    if (length(levels) == 2L) {
      y_bin <- as.numeric(y == levels[2L])
      fit <- glmnet::glmnet(
        x = meta_x,
        y = y_bin,
        family = "binomial",
        alpha = 0,
        lambda = lambda,
        standardize = FALSE
      )
      return(list(task = task, levels = levels, engine = "glmnet_binomial", fit = fit, lambda = lambda))
    }
    fit <- glmnet::glmnet(
      x = meta_x,
      y = factor(y, levels = levels),
      family = "multinomial",
      alpha = 0,
      lambda = lambda,
      standardize = FALSE
    )
    return(list(task = task, levels = levels, engine = "glmnet_multinomial", fit = fit, lambda = lambda))
  }

  x <- cbind(`(Intercept)` = 1, meta_x)
  if (task == "regression") {
    fit <- stats::lm.fit(x = x, y = as.numeric(y))
    return(list(task = task, engine = "native_lm", coef = fit$coefficients))
  }

  if (length(levels) == 2L) {
    y_bin <- as.numeric(y == levels[2L])
    fit <- stats::glm.fit(x = x, y = y_bin, family = stats::binomial())
    coef <- fit$coefficients
    coef[!is.finite(coef)] <- 0
    return(list(task = task, levels = levels, engine = "native_binomial", coef = coef))
  }

  coef_mat <- matrix(0, nrow = ncol(x), ncol = length(levels), dimnames = list(colnames(x), levels))
  for (lvl in levels) {
    y_bin <- as.numeric(y == lvl)
    fit <- stats::glm.fit(x = x, y = y_bin, family = stats::binomial())
    coef <- fit$coefficients
    coef[!is.finite(coef)] <- 0
    coef_mat[, lvl] <- coef
  }
  list(task = task, levels = levels, engine = "native_multinomial_ovr", coef = coef_mat)
}

.ensemble_predict_meta <- function(meta_fit, meta_x) {
  meta_x <- as.matrix(meta_x)
  if (meta_fit$task == "classification") {
    meta_x <- pmin(pmax(meta_x, 1e-6), 1 - 1e-6)
  }
  if (identical(meta_fit$engine, "glmnet_gaussian")) {
    pred <- stats::predict(meta_fit$fit, newx = meta_x, s = meta_fit$lambda, type = "response")
    return(as.numeric(pred))
  }
  if (identical(meta_fit$engine, "glmnet_binomial")) {
    prob <- as.numeric(stats::predict(meta_fit$fit, newx = meta_x, s = meta_fit$lambda, type = "response"))
    prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
    out <- cbind(1 - prob, prob)
    colnames(out) <- meta_fit$levels
    return(out)
  }
  if (identical(meta_fit$engine, "glmnet_multinomial")) {
    prob <- stats::predict(meta_fit$fit, newx = meta_x, s = meta_fit$lambda, type = "response")[, , 1, drop = TRUE]
    prob <- as.matrix(prob)
    prob <- prob[, meta_fit$levels, drop = FALSE]
    colnames(prob) <- meta_fit$levels
    return(prob)
  }
  x <- cbind(`(Intercept)` = 1, meta_x)
  if (meta_fit$task == "regression") {
    return(drop(x %*% meta_fit$coef))
  }
  if (length(meta_fit$levels) == 2L) {
    eta <- drop(x %*% meta_fit$coef)
    eta[!is.finite(eta)] <- 0
    prob <- stats::plogis(eta)
    out <- cbind(1 - prob, prob)
    colnames(out) <- meta_fit$levels
    return(out)
  }
  eta <- x %*% meta_fit$coef
  eta[!is.finite(eta)] <- 0
  eta <- sweep(eta, 1, apply(eta, 1, max), FUN = "-")
  prob <- exp(eta)
  prob <- prob / rowSums(prob)
  colnames(prob) <- meta_fit$levels
  prob
}

.ensemble_oof_meta_matrix <- function(X, y, learners, learner_specs, task, levels, resampling) {
  n <- nrow(X)
  feat_names <- .ensemble_feature_names(learners, levels)
  oof <- matrix(NA_real_, nrow = n, ncol = length(feat_names), dimnames = list(NULL, feat_names))
  folds <- generate_folds(
    n,
    if (task == "classification") factor(y, levels = levels) else NULL,
    resampling,
    data = as.data.frame(X)
  )$folds
  for (fold in folds) {
    train_x <- X[fold$train, , drop = FALSE]
    test_x <- X[fold$test, , drop = FALSE]
    train_y <- y[fold$train]
    models <- .ensemble_fit_base_models(train_x, train_y, learners, learner_specs, task, levels)
    preds <- .ensemble_predict_base_models(models, test_x, task, levels)
    meta_fold <- .ensemble_meta_matrix(preds, learners, levels)
    oof[fold$test, ] <- meta_fold
  }
  oof
}

.smooth_formula <- function(X) {
  vars <- setdiff(colnames(X), "(Intercept)")
  if (!length(vars)) {
    return(stats::as.formula("y ~ 1"))
  }
  rhs <- paste(sprintf("s(`%s`)", vars), collapse = " + ")
  stats::as.formula(paste("y ~", rhs))
}

.dbarts_predict_mean <- function(object, Xnew) {
  pred <- stats::predict(object, Xnew, type = "response")
  if (is.null(dim(pred))) {
    return(as.numeric(pred))
  }
  if (ncol(pred) == nrow(Xnew)) {
    return(colMeans(pred))
  }
  if (nrow(pred) == nrow(Xnew)) {
    return(rowMeans(pred))
  }
  as.numeric(pred)
}

build_registry <- function() {
  list(
    glm = list(
      package = "stats",
      tasks = c("regression", "classification"),
      defaults = list(family = NULL),
      supports = list(prob = TRUE, multiclass = FALSE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        family <- spec$family
        if (is.null(family)) {
          family <- if (task == "regression") stats::gaussian() else stats::binomial()
        }
        if (task == "classification" && length(unique(y)) > 2) {
          stop("glm supports only binary classification.", call. = FALSE)
        }
        if (task == "classification") {
          y <- ifelse(y == levels(y)[2], 1, 0)
        }
        df <- data.frame(y = y, X)
        fit <- stats::glm(y ~ ., data = df, family = family)
        list(state = fit, family = family)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        p <- stats::predict(state$state, newdata = data.frame(Xnew), type = "response")
        if (is.null(levels)) return(as.numeric(p))
        if (type == "prob") {
          prob <- cbind(1 - p, p)
          colnames(prob) <- levels
          return(prob)
        }
        cls <- ifelse(p >= 0.5, levels[2], levels[1])
        factor(cls, levels = levels)
      }
    ),
    rpart = list(
      package = "rpart",
      tasks = c("regression", "classification"),
      defaults = list(cp = 0.01, minsplit = 20),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("rpart", "rpart")
        df <- data.frame(y = y, X)
        ctrl <- do.call(rpart::rpart.control, spec[names(spec) %in% names(formals(rpart::rpart.control))])
        fit <- rpart::rpart(y ~ ., data = df, control = ctrl, method = if (task == "regression") "anova" else "class")
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        ptype <- if (!is.null(levels) && type == "prob") "prob" else if (!is.null(levels)) "class" else "vector"
        p <- stats::predict(state$state, newdata = data.frame(Xnew), type = ptype)
        if (is.null(levels)) return(as.numeric(p))
        if (ptype == "prob") {
          prob <- as.matrix(p)
          if (ncol(prob) == 1 && length(levels) == 2) {
            prob <- cbind(1 - prob[, 1], prob[, 1])
            colnames(prob) <- levels
          } else if (!is.null(levels)) {
            colnames(prob) <- levels
          }
          return(prob)
        }
        factor(p, levels = levels)
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        imp <- state$state$variable.importance
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        data.frame(feature = names(imp), importance = as.numeric(imp), row.names = NULL)
      }
    ),
    glmnet = list(
      package = "glmnet",
      tasks = c("regression", "classification"),
      defaults = list(alpha = 1, lambda = NULL),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("glmnet", "glmnet")
        family <- if (task == "regression") "gaussian" else if (length(unique(y)) > 2) "multinomial" else "binomial"
        fit <- glmnet::glmnet(x = X, y = y, family = family, alpha = spec$alpha, lambda = spec$lambda)
        list(state = fit, family = family)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        lambda_use <- spec$lambda %||% state$state$lambda[1]
        if (is.null(levels)) {
          p <- stats::predict(state$state, newx = Xnew, type = "response", s = lambda_use)
          return(as.numeric(p))
        }
        if (state$family == "multinomial") {
          prob <- stats::predict(state$state, newx = Xnew, type = "response", s = lambda_use)[,,1]
          if (!is.matrix(prob)) prob <- as.matrix(prob)
          prob <- prob[, levels, drop = FALSE]
          if (type == "class") {
            cls <- levels[max.col(prob, ties.method = "first")]
            return(factor(cls, levels = levels))
          }
          return(prob)
        }
        prob <- as.numeric(stats::predict(state$state, newx = Xnew, type = "response", s = lambda_use))
        prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      }
    ),
    ranger = list(
      package = "ranger",
      tasks = c("regression", "classification"),
      defaults = list(num.trees = 500, mtry = NULL, min.node.size = 5, importance = "impurity"),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("ranger", "ranger")
        df <- data.frame(y = y, X)
        fit <- ranger::ranger(
          y ~ ., data = df,
          num.trees = spec$num.trees,
          mtry = spec$mtry,
          min.node.size = spec$min.node.size,
          classification = task == "classification",
          probability = task == "classification",
          importance = spec$importance %||% "impurity",
          respect.unordered.factors = "order"
        )
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, data = data.frame(Xnew))
        if (is.null(levels)) return(as.numeric(pred$predictions))
        prob <- pred$predictions
        if (is.vector(prob)) {
          prob <- cbind(1 - prob, prob)
          colnames(prob) <- levels
        }
        if (type == "class") {
          cls <- levels[max.col(prob)]
          return(factor(cls, levels = levels))
        }
        prob[, levels, drop = FALSE]
      }
    ),
    nnet = list(
      package = "nnet",
      tasks = c("regression", "classification"),
      defaults = list(size = 5, decay = 0.01, maxit = 200),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("nnet", "nnet")
        if (task == "regression") {
          fit <- nnet::nnet(x = X, y = y, size = spec$size, decay = spec$decay,
                            maxit = spec$maxit, linout = TRUE, trace = FALSE)
        } else {
          y_vec <- if (length(levels(y)) > 2) stats::model.matrix(~ y - 1) else as.numeric(y == levels(y)[2])
          fit <- nnet::nnet(x = X, y = y_vec, size = spec$size, decay = spec$decay,
                            maxit = spec$maxit, softmax = length(levels(y)) > 2,
                            linout = FALSE, trace = FALSE)
        }
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        p <- stats::predict(state$state, newdata = Xnew, type = "raw")
        if (is.null(levels)) return(as.numeric(p))
        if (is.null(dim(p))) {
          prob <- cbind(1 - p, p)
          colnames(prob) <- levels
        } else {
          prob <- as.matrix(p)
          if (ncol(prob) == 1 && length(levels) == 2) {
            prob <- cbind(1 - prob[, 1], prob[, 1])
          }
          colnames(prob) <- levels
        }
        if (type == "class") {
          cls <- levels[max.col(prob)]
          return(factor(cls, levels = levels))
        }
        prob
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        imp <- tryCatch(ranger::importance(state$state), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        data.frame(feature = names(imp), importance = as.numeric(imp), row.names = NULL)
      }
    ),
    e1071_svm = list(
      package = "e1071",
      tasks = c("regression", "classification"),
      defaults = list(cost = 1, gamma = NULL, kernel = "radial"),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("e1071", "e1071_svm")
        gamma <- spec$gamma %||% (1 / max(1, ncol(X)))
        df <- data.frame(y = y, X)
        fit <- e1071::svm(
          y ~ ., data = df,
          cost = spec$cost, gamma = gamma, kernel = spec$kernel,
          type = if (task == "regression") "eps-regression" else "C-classification",
          probability = task == "classification"
        )
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = data.frame(Xnew), probability = !is.null(levels))
        if (is.null(levels)) return(as.numeric(pred))
        prob <- attr(pred, "probabilities")
        if (is.null(prob)) {
          cls <- factor(pred, levels = levels)
          if (type == "prob") stop("SVM probabilities unavailable; rebuild with probability=TRUE.", call. = FALSE)
          return(cls)
        }
        prob <- prob[, levels, drop = FALSE]
        if (type == "class") {
          cls <- factor(pred, levels = levels)
          return(cls)
        }
        prob
      }
    ),
    randomForest = list(
      package = "randomForest",
      tasks = c("regression", "classification"),
      defaults = list(ntree = 500, mtry = NULL, nodesize = NULL),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("randomForest", "randomForest")
        args <- list(
          x = X,
          y = y,
          ntree = spec$ntree,
          importance = TRUE
        )
        if (!is.null(spec$mtry)) args$mtry <- spec$mtry
        if (!is.null(spec$nodesize)) args$nodesize <- spec$nodesize
        fit <- do.call(randomForest::randomForest, args)
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        if (is.null(levels)) {
          return(as.numeric(stats::predict(state$state, newdata = data.frame(Xnew))))
        }
        if (type == "prob") {
          prob <- stats::predict(state$state, newdata = data.frame(Xnew), type = "prob")
          prob <- as.matrix(prob)[, levels, drop = FALSE]
          return(prob)
        }
        cls <- stats::predict(state$state, newdata = data.frame(Xnew), type = "response")
        factor(cls, levels = levels)
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        imp <- tryCatch(randomForest::importance(state$state), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        if (is.matrix(imp)) {
          vals <- imp[, ncol(imp)]
          nm <- rownames(imp)
        } else {
          vals <- as.numeric(imp)
          nm <- names(imp)
        }
        data.frame(feature = nm, importance = as.numeric(vals), row.names = NULL)
      }
    ),
    gbm = list(
      package = "gbm",
      tasks = c("regression", "classification"),
      defaults = list(n.trees = 200, interaction.depth = 3, shrinkage = 0.05, n.minobsinnode = 10),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("gbm", "gbm")
        distribution <- if (task == "regression") "gaussian" else if (length(unique(y)) > 2) "multinomial" else "bernoulli"
        df <- data.frame(y = y, X)
        fit <- gbm::gbm(
          y ~ ., data = df,
          distribution = distribution,
          n.trees = spec$n.trees,
          interaction.depth = spec$interaction.depth,
          shrinkage = spec$shrinkage,
          n.minobsinnode = spec$n.minobsinnode,
          verbose = FALSE
        )
        list(state = fit, distribution = distribution, n.trees = spec$n.trees)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        if (is.null(levels)) {
          pred <- stats::predict(state$state, newdata = data.frame(Xnew), n.trees = spec$n.trees, type = "response")
          return(as.numeric(pred))
        }
        if (state$distribution == "multinomial") {
          prob <- stats::predict(state$state, newdata = data.frame(Xnew), n.trees = spec$n.trees, type = "response")
          if (is.list(prob)) {
            prob <- do.call(cbind, lapply(prob, as.numeric))
          } else if (length(dim(prob)) == 3) {
            prob <- prob[, , 1, drop = TRUE]
          }
          colnames(prob) <- levels
          if (type == "class") {
            cls <- levels[max.col(prob, ties.method = "first")]
            return(factor(cls, levels = levels))
          }
          return(prob)
        }
        prob <- as.numeric(stats::predict(state$state, newdata = data.frame(Xnew), n.trees = spec$n.trees, type = "response"))
        prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        imp <- tryCatch(gbm::summary.gbm(state$state, n.trees = state$n.trees, plotit = FALSE), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        data.frame(feature = imp$var, importance = imp$rel.inf, row.names = NULL)
      }
    ),
    C50 = list(
      package = "C50",
      tasks = c("classification"),
      defaults = list(trials = 1, model = "tree"),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("C50", "C50")
        df <- data.frame(y = y, X)
        fit <- C50::C5.0(x = X, y = y, trials = spec$trials, rules = spec$model == "rules")
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        if (type == "prob") {
          prob <- stats::predict(state$state, newdata = Xnew, type = "prob")
          prob <- prob[, levels, drop = FALSE]
          return(prob)
        }
        cls <- stats::predict(state$state, newdata = Xnew, type = "class")
        factor(cls, levels = levels)
      }
    ),
    kknn = list(
      package = "kknn",
      tasks = c("regression", "classification"),
      defaults = list(k = 7, distance = 2),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("kknn", "kknn")
        df <- data.frame(y = y, X)
        fit <- kknn::train.kknn(
          y ~ ., data = df,
          kmax = spec$k,
          distance = spec$distance,
          kernel = "optimal"
        )
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        if (is.null(levels)) {
          return(as.numeric(stats::predict(state$state, newdata = data.frame(Xnew))))
        }
        if (type == "prob") {
          prob <- stats::predict(state$state, newdata = data.frame(Xnew), type = "prob")
          prob <- as.matrix(prob)[, levels, drop = FALSE]
          return(prob)
        }
        cls <- stats::predict(state$state, newdata = data.frame(Xnew), type = "raw")
        factor(cls, levels = levels)
      }
    ),
    earth = list(
      package = "earth",
      tasks = c("regression", "classification"),
      defaults = list(degree = 1, nprune = NULL),
      supports = list(prob = TRUE, multiclass = FALSE, importance = TRUE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("earth", "earth")
        df <- data.frame(y = y, X)
        glm_list <- if (task == "classification") list(family = stats::binomial()) else NULL
        fit <- earth::earth(
          y ~ ., data = df,
          degree = spec$degree,
          nprune = spec$nprune,
          glm = glm_list
        )
        list(state = fit, task = task)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        if (state$task == "regression" || is.null(levels)) {
          pred <- stats::predict(state$state, newdata = data.frame(Xnew), type = "response")
          return(as.numeric(pred))
        }
        prob <- stats::predict(state$state, newdata = data.frame(Xnew), type = "response")
        prob <- as.numeric(prob)
        prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        imp <- tryCatch(earth::evimp(state$state), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        vals <- imp$gcv %||% imp$rss %||% imp$nsubsets
        data.frame(feature = rownames(imp), importance = as.numeric(vals), row.names = NULL)
      }
    ),
    gam = list(
      package = "mgcv",
      tasks = c("regression", "classification"),
      defaults = list(family = NULL, method = "REML"),
      supports = list(prob = TRUE, multiclass = FALSE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("mgcv", "gam")
        if (task == "classification" && length(unique(y)) > 2) {
          stop("gam supports only binary classification.", call. = FALSE)
        }
        family <- spec$family
        if (is.null(family)) {
          family <- if (task == "regression") stats::gaussian() else stats::binomial()
        }
        df <- data.frame(y = y, X, check.names = FALSE)
        fit <- mgcv::gam(.smooth_formula(X), data = df, family = family, method = spec$method)
        list(state = fit, task = task)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = data.frame(Xnew, check.names = FALSE), type = "response")
        if (is.null(levels)) return(as.numeric(pred))
        prob <- pmin(pmax(as.numeric(pred), 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      }
    ),
    naivebayes = list(
      package = "naivebayes",
      tasks = c("classification"),
      defaults = list(laplace = 0, usekernel = FALSE, usepoisson = FALSE),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("naivebayes", "naivebayes")
        df <- data.frame(y = y, X, check.names = FALSE)
        fit <- naivebayes::naive_bayes(
          y ~ .,
          data = df,
          laplace = spec$laplace,
          usekernel = spec$usekernel,
          usepoisson = spec$usepoisson
        )
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        ptype <- if (type == "prob") "prob" else "class"
        pred <- stats::predict(state$state, newdata = data.frame(Xnew, check.names = FALSE), type = ptype)
        if (ptype == "prob") {
          prob <- as.matrix(pred)[, levels, drop = FALSE]
          return(prob)
        }
        factor(pred, levels = levels)
      }
    ),
    fda = list(
      package = "mda",
      tasks = c("classification"),
      defaults = list(),
      supports = list(prob = FALSE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("mda", "fda")
        df <- data.frame(y = y, X, check.names = FALSE)
        fit <- mda::fda(y ~ ., data = df)
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = data.frame(Xnew, check.names = FALSE))
        if (type == "prob") {
          prob <- if (is.list(pred) && !is.null(pred$posterior)) pred$posterior else pred
          prob <- as.matrix(prob)[, levels, drop = FALSE]
          return(prob)
        }
        cls <- if (is.list(pred) && !is.null(pred$class)) pred$class else pred
        factor(cls, levels = levels)
      }
    ),
    adaboost = list(
      package = "ada",
      tasks = c("classification"),
      defaults = list(iter = 50, nu = 0.1, loss = "exponential", type = "discrete"),
      supports = list(prob = TRUE, multiclass = FALSE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("ada", "adaboost")
        if (length(unique(y)) > 2) {
          stop("adaboost supports only binary classification.", call. = FALSE)
        }
        df <- data.frame(y = y, X, check.names = FALSE)
        fit <- ada::ada(
          y ~ ., data = df,
          iter = spec$iter,
          nu = spec$nu,
          loss = spec$loss,
          type = spec$type
        )
        backend_levels <- colnames(fit$confusion) %||% levels(y)
        list(state = fit, backend_levels = backend_levels)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        new_df <- data.frame(Xnew, check.names = FALSE)
        if (type == "prob") {
          prob <- stats::predict(state$state, newdata = new_df, type = "probs")
          prob <- as.matrix(prob)
          if (ncol(prob) == 1L) {
            prob <- cbind(1 - prob[, 1], prob[, 1])
            colnames(prob) <- state$backend_levels %||% levels
          } else if (!is.null(colnames(prob))) {
            prob <- prob[, levels, drop = FALSE]
          } else {
            colnames(prob) <- state$backend_levels %||% levels
          }
          return(prob[, levels, drop = FALSE])
        }
        pred <- stats::predict(state$state, newdata = new_df, type = "vector")
        factor(pred, levels = levels)
      }
    ),
    pls = list(
      package = "pls",
      tasks = c("regression"),
      defaults = list(ncomp = NULL, method = "simpls"),
      supports = list(prob = FALSE, multiclass = FALSE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("pls", "pls")
        ncomp <- spec$ncomp %||% min(2L, ncol(X))
        ncomp <- max(1L, min(as.integer(ncomp), ncol(X), nrow(X) - 1L))
        df <- data.frame(y = y, X, check.names = FALSE)
        fit <- pls::plsr(y ~ ., data = df, ncomp = ncomp, method = spec$method, validation = "none")
        list(state = fit, ncomp = ncomp)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = data.frame(Xnew, check.names = FALSE), ncomp = state$ncomp, type = "response")
        as.numeric(pred[, 1, 1])
      }
    ),
    ctree = list(
      package = "partykit",
      tasks = c("regression", "classification"),
      defaults = list(mincriterion = 0.95),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("partykit", "ctree")
        df <- data.frame(y = y, X, check.names = FALSE)
        ctrl <- partykit::ctree_control(mincriterion = spec$mincriterion)
        fit <- partykit::ctree(y ~ ., data = df, control = ctrl)
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        new_df <- data.frame(Xnew, check.names = FALSE)
        if (is.null(levels)) {
          pred <- stats::predict(state$state, newdata = new_df, type = "response")
          return(as.numeric(pred))
        }
        ptype <- if (type == "prob") "prob" else "response"
        pred <- stats::predict(state$state, newdata = new_df, type = ptype)
        if (ptype == "prob") {
          prob <- as.matrix(pred)[, levels, drop = FALSE]
          return(prob)
        }
        factor(pred, levels = levels)
      }
    ),
    cforest = list(
      package = "partykit",
      tasks = c("regression", "classification"),
      defaults = list(ntree = 500, mtry = NULL, mincriterion = 0),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("partykit", "cforest")
        mtry <- spec$mtry %||% max(1L, floor(sqrt(ncol(X))))
        df <- data.frame(y = y, X, check.names = FALSE)
        ctrl <- partykit::ctree_control(mincriterion = spec$mincriterion, saveinfo = FALSE)
        fit <- partykit::cforest(y ~ ., data = df, control = ctrl, ntree = spec$ntree, mtry = mtry)
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        new_df <- data.frame(Xnew, check.names = FALSE)
        if (is.null(levels)) {
          pred <- stats::predict(state$state, newdata = new_df, type = "response")
          return(as.numeric(pred))
        }
        ptype <- if (type == "prob") "prob" else "response"
        pred <- stats::predict(state$state, newdata = new_df, type = ptype)
        if (ptype == "prob") {
          prob <- as.matrix(pred)[, levels, drop = FALSE]
          return(prob)
        }
        factor(pred, levels = levels)
      }
    ),
    lda = list(
      package = "MASS",
      tasks = c("classification"),
      defaults = list(),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        df <- data.frame(y = y, X)
        fit <- MASS::lda(y ~ ., data = df)
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = data.frame(Xnew))
        if (type == "prob") {
          prob <- pred$posterior[, levels, drop = FALSE]
          return(prob)
        }
        factor(pred$class, levels = levels)
      }
    ),
    qda = list(
      package = "MASS",
      tasks = c("classification"),
      defaults = list(),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        df <- data.frame(y = y, X)
        fit <- MASS::qda(y ~ ., data = df)
        list(state = fit)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = data.frame(Xnew))
        if (type == "prob") {
          prob <- pred$posterior[, levels, drop = FALSE]
          return(prob)
        }
        factor(pred$class, levels = levels)
      }
    ),
    lightgbm = list(
      package = "lightgbm",
      tasks = c("regression", "classification"),
      defaults = list(
        num_leaves = 31,
        learning_rate = 0.05,
        nrounds = 200,
        feature_fraction = 1,
        bagging_fraction = 1,
        bagging_freq = 0,
        max_depth = -1
      ),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, levels, ...) {
        assert_package("lightgbm", "lightgbm")
        if (task == "classification") {
          if (is.null(levels)) stop("Classification requires factor levels.", call. = FALSE)
          label <- if (length(levels) > 2) as.numeric(y) - 1 else as.numeric(y == levels[2])
          objective <- if (length(levels) > 2) "multiclass" else "binary"
          num_class <- if (length(levels) > 2) length(levels) else NULL
        } else {
          label <- as.numeric(y)
          objective <- "regression"
          num_class <- NULL
        }
        dtrain <- lightgbm::lgb.Dataset(data = X, label = label)
        params <- list(
          objective = objective,
          num_leaves = spec$num_leaves,
          learning_rate = spec$learning_rate,
          feature_fraction = spec$feature_fraction,
          bagging_fraction = spec$bagging_fraction,
          bagging_freq = spec$bagging_freq,
          max_depth = spec$max_depth,
          num_class = num_class
        )
        params <- params[!vapply(params, is.null, logical(1))]
        fit <- lightgbm::lgb.train(params = params, data = dtrain, nrounds = spec$nrounds, verbose = -1)
        list(state = fit, objective = objective, levels = levels, num_class = num_class, feature_names = colnames(X))
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- stats::predict(state$state, newdata = Xnew)
        if (state$objective == "regression" || is.null(levels)) return(as.numeric(pred))
        if (state$objective == "multiclass") {
          prob <- matrix(pred, ncol = state$num_class, byrow = TRUE)
          colnames(prob) <- levels
          if (type == "class") {
            cls <- levels[max.col(prob, ties.method = "first")]
            return(factor(cls, levels = levels))
          }
          return(prob[, levels, drop = FALSE])
        }
        prob <- as.numeric(pred)
        prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        imp <- tryCatch(lightgbm::lgb.importance(model = state$state), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        data.frame(feature = imp$Feature, importance = imp$Gain, row.names = NULL)
      }
    ),
    catboost = list(
      package = "catboost",
      tasks = c("regression", "classification"),
      defaults = list(iterations = 200, depth = 6, learning_rate = 0.1, l2_leaf_reg = 3),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, levels, ...) {
        assert_package("catboost", "catboost")
        if (task == "classification") {
          if (is.null(levels)) stop("Classification requires factor levels.", call. = FALSE)
          label <- if (length(levels) > 2) as.integer(y) - 1 else as.integer(y == levels[2])
          loss <- if (length(levels) > 2) "MultiClass" else "Logloss"
        } else {
          label <- as.numeric(y)
          loss <- "RMSE"
        }
        pool <- catboost::catboost.load_pool(data = X, label = label)
        params <- list(
          loss_function = loss,
          iterations = spec$iterations,
          depth = spec$depth,
          learning_rate = spec$learning_rate,
          l2_leaf_reg = spec$l2_leaf_reg,
          verbose = FALSE
        )
        fit <- catboost::catboost.train(pool, params = params)
        list(state = fit, levels = levels, loss_function = loss)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pool_new <- catboost::catboost.load_pool(data = Xnew)
        if (state$loss_function == "RMSE" || is.null(levels)) {
          pred <- catboost::catboost.predict(state$state, pool_new, prediction_type = "RawFormulaVal")
          return(as.numeric(pred))
        }
        if (state$loss_function == "MultiClass") {
          prob <- catboost::catboost.predict(state$state, pool_new, prediction_type = "Probability")
          prob <- matrix(prob, ncol = length(levels), byrow = TRUE)
          colnames(prob) <- levels
          if (type == "class") {
            cls <- levels[max.col(prob, ties.method = "first")]
            return(factor(cls, levels = levels))
          }
          return(prob[, levels, drop = FALSE])
        }
        prob <- as.matrix(catboost::catboost.predict(state$state, pool_new, prediction_type = "Probability"))
        if (ncol(prob) == 1L) {
          prob <- as.numeric(prob[, 1])
          prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
          prob <- cbind(1 - prob, prob)
        } else if (!is.null(colnames(prob))) {
          prob <- prob[, levels, drop = FALSE]
        } else {
          colnames(prob) <- levels
        }
        if (type == "class") {
          cls <- levels[max.col(prob, ties.method = "first")]
          return(factor(cls, levels = levels))
        }
        colnames(prob) <- levels
        prob[, levels, drop = FALSE]
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        pool <- catboost::catboost.load_pool(data = X, label = NULL)
        imp <- tryCatch(catboost::catboost.get_feature_importance(state$state, pool = pool, type = "FeatureImportance"), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = feature_names, importance = NA_real_))
        data.frame(feature = feature_names, importance = as.numeric(imp), row.names = NULL)
      }
    ),
    bart = list(
      package = "dbarts",
      tasks = c("regression", "classification"),
      defaults = list(ntree = 200, ndpost = 1000, nskip = 100, keeptrees = TRUE, verbose = FALSE),
      supports = list(prob = TRUE, multiclass = FALSE, importance = FALSE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("dbarts", "bart")
        if (task == "classification" && length(unique(y)) > 2) {
          stop("bart supports only binary classification.", call. = FALSE)
        }
        fit <- dbarts::bart(
          x.train = X,
          y.train = y,
          ntree = spec$ntree,
          ndpost = spec$ndpost,
          nskip = spec$nskip,
          keeptrees = spec$keeptrees,
          verbose = spec$verbose
        )
        list(state = fit, task = task)
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        pred <- .dbarts_predict_mean(state$state, Xnew)
        if (is.null(levels)) return(as.numeric(pred))
        prob <- pmin(pmax(as.numeric(pred), 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      }
    ),
    xgboost = list(
      package = "xgboost",
      tasks = c("regression", "classification"),
      defaults = list(
        nrounds = 200,
        max_depth = 6,
        eta = 0.3,
        subsample = 1,
        colsample_bytree = 1
      ),
      supports = list(prob = TRUE, multiclass = TRUE, importance = TRUE),
      fit_xy = function(X, y, spec, task, ...) {
        assert_package("xgboost", "xgboost")
        dtrain <- xgboost::xgb.DMatrix(data = X, label = if (is.factor(y)) as.numeric(y) - 1 else y)
        params <- list(
          max_depth = spec$max_depth,
          eta = spec$eta,
          subsample = spec$subsample,
          colsample_bytree = spec$colsample_bytree,
          objective = if (task == "regression") "reg:squarederror" else if (length(levels(y)) > 2) "multi:softprob" else "binary:logistic"
        )
        if (task == "classification" && length(levels(y)) > 2) {
          params$num_class <- length(levels(y))
        }
        fit <- xgboost::xgb.train(
          params = params,
          data = dtrain,
          nrounds = spec$nrounds,
          verbose = 0
        )
        list(state = fit, task = task, levels = if (is.factor(y)) levels(y) else NULL, feature_names = colnames(X))
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        dnew <- xgboost::xgb.DMatrix(data = Xnew)
        pred <- stats::predict(state$state, dnew)
        if (is.null(levels)) return(as.numeric(pred))
        if (state$task == "classification" && length(levels) > 2) {
          prob <- matrix(pred, ncol = length(levels), byrow = TRUE)
          colnames(prob) <- levels
          if (type == "class") {
            cls <- levels[max.col(prob, ties.method = "first")]
            return(factor(cls, levels = levels))
          }
          return(prob)
        }
        prob <- as.numeric(pred)
        prob <- pmin(pmax(prob, 1e-6), 1 - 1e-6)
        if (type == "class") {
          cls <- ifelse(prob >= 0.5, levels[2], levels[1])
          return(factor(cls, levels = levels))
        }
        out <- cbind(1 - prob, prob)
        colnames(out) <- levels
        out
      },
      importance = function(state, X, y, feature_names, task, levels, ...) {
        fn <- feature_names %||% state$feature_names
        imp <- tryCatch(xgboost::xgb.importance(model = state$state, feature_names = fn), error = function(e) NULL)
        if (is.null(imp)) return(data.frame(feature = fn, importance = NA_real_))
        data.frame(feature = imp$Feature, importance = imp$Gain, row.names = NULL)
      }
    ),
    stacking = list(
      package = "stats",
      tasks = c("regression", "classification"),
      defaults = list(learners = NULL, learner_specs = list(), meta_model = "glmnet"),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, levels, ...) {
        learners <- spec$learners %||% .ensemble_default_learners(task)
        .ensemble_validate_learners(learners, task)
        learner_specs <- .ensemble_prepare_specs(learners, spec$learner_specs %||% list())
        base_models <- .ensemble_fit_base_models(X, y, learners, learner_specs, task, levels)
        base_preds <- .ensemble_predict_base_models(base_models, X, task, levels)
        meta_x <- .ensemble_meta_matrix(base_preds, learners, levels)
        meta_fit <- .ensemble_fit_meta(meta_x, y, task, levels, meta_model = spec$meta_model %||% "glmnet")
        list(
          ensemble = "stacking",
          learners = learners,
          learner_specs = learner_specs,
          base_models = base_models,
          meta_fit = meta_fit,
          levels = levels,
          task = task,
          meta_features = colnames(meta_x)
        )
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        preds <- .ensemble_predict_base_models(state$base_models, Xnew, state$task, state$levels)
        meta_x <- .ensemble_meta_matrix(preds, state$learners, state$levels)
        pred <- .ensemble_predict_meta(state$meta_fit, meta_x)
        if (is.null(state$levels)) {
          return(as.numeric(pred))
        }
        prob <- .ensemble_prob_matrix(pred, state$levels)
        if (type == "class") {
          cls <- state$levels[max.col(prob, ties.method = "first")]
          return(factor(cls, levels = state$levels))
        }
        prob
      }
    ),
    superlearner = list(
      package = "stats",
      tasks = c("regression", "classification"),
      defaults = list(learners = NULL, learner_specs = list(), meta_model = "glmnet", resampling = cv(5, seed = 1)),
      supports = list(prob = TRUE, multiclass = TRUE, importance = FALSE),
      fit_xy = function(X, y, spec, task, levels, ...) {
        learners <- spec$learners %||% .ensemble_default_learners(task)
        .ensemble_validate_learners(learners, task)
        learner_specs <- .ensemble_prepare_specs(learners, spec$learner_specs %||% list())
        resampling <- spec$resampling %||% cv(5, seed = 1)
        meta_x <- .ensemble_oof_meta_matrix(X, y, learners, learner_specs, task, levels, resampling)
        meta_fit <- .ensemble_fit_meta(meta_x, y, task, levels, meta_model = spec$meta_model %||% "glmnet")
        base_models <- .ensemble_fit_base_models(X, y, learners, learner_specs, task, levels)
        list(
          ensemble = "superlearner",
          learners = learners,
          learner_specs = learner_specs,
          base_models = base_models,
          meta_fit = meta_fit,
          levels = levels,
          task = task,
          meta_features = colnames(meta_x),
          resampling = resampling
        )
      },
      predict_xy = function(state, Xnew, type, levels, spec, ...) {
        preds <- .ensemble_predict_base_models(state$base_models, Xnew, state$task, state$levels)
        meta_x <- .ensemble_meta_matrix(preds, state$learners, state$levels)
        pred <- .ensemble_predict_meta(state$meta_fit, meta_x)
        if (is.null(state$levels)) {
          return(as.numeric(pred))
        }
        prob <- .ensemble_prob_matrix(pred, state$levels)
        if (type == "class") {
          cls <- state$levels[max.col(prob)]
          return(factor(cls, levels = state$levels))
        }
        prob
      }
    )
  )
}

funcml_registry <- local({
  reg <- NULL
  function(model = NULL) {
    if (is.null(reg)) reg <<- build_registry()
    if (is.null(model)) return(reg)
    if (!model %in% names(reg)) {
      stop(sprintf("Unknown model '%s'. Available: %s", model, paste(names(reg), collapse = ", ")), call. = FALSE)
    }
    reg[[model]]
  }
})
