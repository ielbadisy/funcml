
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# funcml

`funcml` is a machine learning framework for R with one explicit
interface for fitting models, validating them, tuning them, comparing
learners, interpreting predictions, and estimating causal effects.

The package is intentionally opinionated: preprocessing happens before
modeling, inputs stay explicit, and the API stays compact instead of
expanding into a large orchestration framework.

## Why `funcml`?

- One surface for the full modeling loop: `fit()`, `predict()`,
  `evaluate()`, `tune()`, `compare_learners()`, `interpret()`, and
  `estimate()`.
- Session-aware learner catalog via `list_learners()`, including
  capability and availability metadata.
- Plot-ready outputs across validation, tuning, comparison, explanation,
  calibration, and treatment-effect workflows.
- Native support for stacked and super learner ensembles through the
  same interface as base learners.

## Installation

``` r
install.packages("remotes")
remotes::install_github("ielbadisy/funcml")
```

After installation, inspect the learner catalog with `list_learners()`.
This shows which engines are registered, what each learner supports, and
which backends are available in the current R session.

## API Overview

| Task                 | Main functions                                               | Returned object                        | Typical use                                                         |
|----------------------|--------------------------------------------------------------|----------------------------------------|---------------------------------------------------------------------|
| Learner discovery    | `list_learners()`                                            | `data.frame`                           | Inspect learner ids, capabilities, and engine availability          |
| Model fitting        | `fit()`, `predict()`                                         | `funcml_fit`                           | Train one learner and generate predictions                          |
| Resampled validation | `cv()`, `holdout()`, `group_cv()`, `time_cv()`, `evaluate()` | `funcml_eval`                          | Estimate out-of-sample performance with uncertainty                 |
| Model selection      | `tune()`, `compare_learners()`                               | `funcml_tune`, `funcml_compare`        | Search hyperparameters and compare learners under common resampling |
| Interpretation       | `interpret()`                                                | method-specific interpretation classes | Explain fitted models with global and local diagnostics             |
| Causal estimation    | `estimate()`                                                 | `funcml_estimand`                      | Estimate plug-in g-computation estimands                            |

## Demo data used below

The README uses one regression problem, one binary classification
problem, and one synthetic causal example so the same API can be shown
across the package surface.

``` r
demo_reg <- transform(
  mtcars,
  car = rownames(mtcars)
)

demo_cls <- local({
  x1 <- rnorm(500)
  x2 <- rnorm(500)
  x3 <- runif(500, -1, 1)
  eta <- -0.4 + 1.0 * x1 - 0.8 * x2 + 0.7 * x3
  data.frame(
    outcome = factor(
      ifelse(runif(500) < stats::plogis(eta), "yes", "no"),
      levels = c("no", "yes")
    ),
    x1 = x1,
    x2 = x2,
    x3 = x3
  )
})

demo_cls_test <- local({
  x1 <- rnorm(250)
  x2 <- rnorm(250)
  x3 <- runif(250, -1, 1)
  eta <- -0.4 + 1.0 * x1 - 0.8 * x2 + 0.7 * x3
  data.frame(
    outcome = factor(
      ifelse(runif(250) < stats::plogis(eta), "yes", "no"),
      levels = c("no", "yes")
    ),
    x1 = x1,
    x2 = x2,
    x3 = x3
  )
})

demo_causal <- local({
  x1 <- rnorm(600)
  x2 <- rnorm(600)
  x3 <- runif(600, -1, 1)
  p_trt <- stats::plogis(-0.2 + 0.7 * x1 - 0.5 * x2 + 0.4 * x3)
  trt <- rbinom(600, 1, p_trt)
  true_effect <- 1.2 + 0.6 * x3
  outcome <- 3 + true_effect * trt + 0.8 * x1 - 0.7 * x2 + 0.5 * x3 +
    rnorm(600, sd = 0.4)
  data.frame(
    outcome = outcome,
    trt = trt,
    x1 = x1,
    x2 = x2,
    x3 = x3,
    true_effect = true_effect
  )
})

xgb_spec <- list(
  nrounds = 30,
  max_depth = 3,
  eta = 0.1,
  subsample = 1,
  colsample_bytree = 1
)
```

## 1. Inspect the learner catalog

`list_learners()` is the current catalog API. It returns one row per
learner id with support flags, interpretation capabilities, engine
package names, and current-session availability.

``` r
catalog <- list_learners(
  columns = c(
    "learner",
    "supports_regression",
    "supports_classification",
    "supports_prob",
    "supports_multiclass",
    "supports_importance",
    "engine_package",
    "available"
  )
)

data.frame(
  learners = nrow(catalog),
  regression = sum(catalog$supports_regression),
  classification = sum(catalog$supports_classification),
  prob = sum(catalog$supports_prob),
  multiclass = sum(catalog$supports_multiclass),
  importance = sum(catalog$supports_importance),
  available = sum(catalog$available)
)
#>   learners regression classification prob multiclass importance available
#> 1       25         19             24   23         18          7        25
```

``` r
head(list_learners(
  classification = TRUE,
  prob = TRUE,
  available = TRUE,
  columns = c(
    "learner",
    "supports_prob",
    "supports_multiclass",
    "supports_importance",
    "engine_package"
  )
), 6)
#>      learner supports_prob supports_multiclass supports_importance
#> 15  adaboost          TRUE               FALSE               FALSE
#> 22      bart          TRUE               FALSE               FALSE
#> 9        C50          TRUE                TRUE               FALSE
#> 18   cforest          TRUE                TRUE               FALSE
#> 17     ctree          TRUE                TRUE               FALSE
#> 6  e1071_svm          TRUE                TRUE               FALSE
#>    engine_package
#> 15            ada
#> 22         dbarts
#> 9             C50
#> 18       partykit
#> 17       partykit
#> 6           e1071
```

``` r
head(catalog$learner, 10)
#>  [1] "adaboost"  "bart"      "C50"       "cforest"   "ctree"     "e1071_svm"
#>  [7] "earth"     "fda"       "gam"       "gbm"
```

## 2. Fit one model and inspect the fitted object

`fit()` is the entry point for training a single learner. It returns a
compact `funcml_fit` object that stores the learner id, formula, encoded
feature layout, and prediction machinery.

``` r
fit_obj <- fit(
  mpg ~ wt + hp + qsec + drat,
  data = demo_reg,
  model = "xgboost",
  spec = xgb_spec,
  seed = 42
)

fit_obj
#> <funcml_fit> regression model: xgboost
#> Formula: mpg ~ wt + hp + qsec + drat
#> Features: 4 | Obs: 32
```

``` r
head(data.frame(
  car = demo_reg$car[1:6],
  observed = demo_reg$mpg[1:6],
  pred = round(predict(fit_obj, demo_reg[1:6, , drop = FALSE]), 2)
), 6)
#>                 car observed  pred
#> 1         Mazda RX4     21.0 21.21
#> 2     Mazda RX4 Wag     21.0 21.21
#> 3        Datsun 710     22.8 22.52
#> 4    Hornet 4 Drive     21.4 21.27
#> 5 Hornet Sportabout     18.7 17.83
#> 6           Valiant     18.1 18.35
```

## 3. Validate performance with resampling

`evaluate()` applies the same learner interface under a resampling plan
and returns fold-level results plus uncertainty summaries.

``` r
eval_obj <- evaluate(
  data = demo_reg,
  formula = mpg ~ wt + hp + qsec + drat,
  model = "xgboost",
  spec = xgb_spec,
  resampling = cv(v = 4, seed = 42)
)

eval_tbl <- eval_obj$summary[, c("metric", "mean", "conf_low", "conf_high")]
eval_tbl[, c("mean", "conf_low", "conf_high")] <- round(
  eval_tbl[, c("mean", "conf_low", "conf_high")],
  3
)
eval_tbl
#>   metric   mean conf_low conf_high
#> 1   rmse  3.310    0.885     5.734
#> 2    mae  2.667    0.682     4.651
#> 3    mse 12.696   -3.049    28.442
#> 4  medae  2.368    0.187     4.550
#> 5   mape  0.138    0.046     0.229
#> 6    rsq  0.412   -0.871     1.695
```

``` r
plot(eval_obj)
```

![](README_files/figure-gfm/eval-plot-1.png)<!-- -->

The same resampling interface also handles grouped CV, rolling time
splits, and plain holdout validation through `group_cv()`, `time_cv()`,
and `holdout()`.

## 4. Tune hyperparameters and compare learners

`tune()` searches a grid or random sample of hyperparameters using the
same evaluation machinery. `compare_learners()` then puts multiple
learners under the same resampling design for an apples-to-apples
comparison.

``` r
tune_grid <- expand.grid(
  max_depth = c(2, 3),
  eta = c(0.05, 0.1),
  nrounds = c(20, 30)
)

tune_obj <- tune(
  data = demo_reg,
  formula = mpg ~ wt + hp + qsec + drat,
  model = "xgboost",
  grid = tune_grid,
  resampling = cv(v = 3, seed = 42),
  metric = "rmse",
  subsample = 1,
  colsample_bytree = 1,
  seed = 42
)

round(tune_obj$best[, c(names(tune_grid), "mean", "conf_low", "conf_high")], 3)
#>   max_depth eta nrounds  mean conf_low conf_high
#> 7         2 0.1      30 2.938   -0.057     5.934
```

``` r
tune_tbl <- head(
  tune_obj$results[
    order(tune_obj$results$mean),
    c(names(tune_grid), "mean", "conf_low", "conf_high")
  ],
  4
)
tune_tbl[, c("mean", "conf_low", "conf_high")] <- round(
  tune_tbl[, c("mean", "conf_low", "conf_high")],
  3
)
tune_tbl
#>   max_depth eta nrounds  mean conf_low conf_high
#> 7         2 0.1      30 2.938   -0.057     5.934
#> 3         2 0.1      20 3.105   -0.554     6.765
#> 8         3 0.1      30 3.134    0.136     6.133
#> 4         3 0.1      20 3.234   -0.347     6.815
```

``` r
plot(tune_obj)
```

![](README_files/figure-gfm/tune-plot-1.png)<!-- -->

``` r
compare_obj <- compare_learners(
  data = demo_reg,
  formula = mpg ~ wt + hp + qsec,
  models = c("glm", "rpart", "xgboost"),
  metrics = c("rmse", "mae"),
  resampling = cv(v = 4, seed = 42),
  specs = list(xgboost = xgb_spec)
)

compare_tbl <- compare_obj$results[, c("model", "metric", "mean", "conf_low", "conf_high", "rank")]
compare_tbl[, c("mean", "conf_low", "conf_high")] <- round(
  compare_tbl[, c("mean", "conf_low", "conf_high")],
  3
)
compare_tbl
#>     model metric  mean conf_low conf_high rank
#> 1     glm   rmse 2.823    1.488     4.159    1
#> 2     glm    mae 2.325    1.215     3.435    1
#> 3   rpart   rmse 4.590    3.776     5.404    3
#> 4   rpart    mae 3.781    3.297     4.265    3
#> 5 xgboost   rmse 3.375    1.058     5.692    2
#> 6 xgboost    mae 2.735    0.849     4.620    2
```

``` r
plot(compare_obj)
```

![](README_files/figure-gfm/compare-plot-1.png)<!-- -->

## 5. Interpret a fitted model

The interpretation layer operates directly on fitted `funcml_fit`
objects, so you do not need a second modeling interface for explanation
tasks.

``` r
permute_obj <- interpret(
  fit = fit_obj,
  data = demo_reg,
  method = "permute",
  nsim = 20,
  seed = 42
)

summary(permute_obj)
#>   feature importance    std_dev
#> 1      wt  5.0435220 0.66524640
#> 2      hp  2.4062084 0.21645730
#> 3    qsec  0.7493847 0.26214864
#> 4    drat  0.3088876 0.09418153
```

``` r
plot(permute_obj)
```

![](README_files/figure-gfm/permute-plot-1.png)<!-- -->

``` r
ale_obj <- interpret(
  fit = fit_obj,
  data = demo_reg,
  method = "ale",
  features = c("wt", "hp")
)
```

``` r
plot(ale_obj)
```

![](README_files/figure-gfm/ale-plot-1.png)<!-- -->

``` r
shap_obj <- interpret(
  fit = fit_obj,
  data = demo_reg,
  method = "shap",
  newdata = demo_reg[1, , drop = FALSE],
  nsim = 30,
  nsamples = 20,
  seed = 42
)
```

``` r
plot(shap_obj, kind = "waterfall")
```

![](README_files/figure-gfm/shap-plot-1.png)<!-- -->

Other supported methods include PDP, ICE, local surrogate explanations,
global surrogates, interaction strength, ceteris paribus profiles, and
calibration diagnostics.

## 6. Inspect class probabilities and calibration

For classification, the same `fit()` object can produce class
predictions or class-probability matrices with aligned columns.

``` r
cls_fit <- fit(
  outcome ~ x1 + x2 + x3,
  data = demo_cls,
  model = "glm",
  seed = 42
)

cls_prob <- round(
  predict(cls_fit, demo_cls_test[1:6, , drop = FALSE], type = "prob"),
  3
)

data.frame(
  prob_no = cls_prob[, "no"],
  prob_yes = cls_prob[, "yes"],
  row.names = NULL
)
#>   prob_no prob_yes
#> 1   0.578    0.422
#> 2   0.323    0.677
#> 3   0.840    0.160
#> 4   0.492    0.508
#> 5   0.762    0.238
#> 6   0.567    0.433
```

``` r
calibration_obj <- interpret(
  fit = cls_fit,
  data = demo_cls_test,
  method = "calibration",
  type = "prob",
  bins = 8,
  strategy = "quantile"
)
```

``` r
plot(calibration_obj)
```

![](README_files/figure-gfm/calibration-plot-1.png)<!-- -->

## 7. Estimate causal effects through the same interface

`estimate()` extends the same framework into plug-in g-computation for
common binary-treatment estimands.

This synthetic causal example has measured confounding and a known
treatment effect centered near `1.2`, so the ATE output has a meaningful
target.

``` r
est_obj <- estimate(
  data = demo_causal,
  formula = outcome ~ trt + x1 + x2 + x3 + trt:x3,
  model = "glm",
  estimand = "ATE",
  treatment_level = 1,
  control_level = 0,
  interval = "normal",
  seed = 42
)

data.frame(
  estimand = est_obj$estimand,
  treatment_level = est_obj$treatment_level,
  control_level = est_obj$control_level,
  estimate = round(est_obj$estimate, 3),
  conf_low = round(est_obj$conf_int[1], 3),
  conf_high = round(est_obj$conf_int[2], 3)
)
#>       estimand treatment_level control_level estimate conf_low conf_high
#> lower      ATE               1             0    1.215    1.191     1.239
```

``` r
plot(est_obj)
```

![](README_files/figure-gfm/estimate-plot-1.png)<!-- -->

The same API also supports `ATT`, `CATE`, and `IATE`.

## 8. Use ensembles as first-class learners

`stacking` and `superlearner` live in the same catalog as the base
learners, so ensembles are fit through the same API rather than a
separate pipeline.

``` r
stack_fit <- fit(
  mpg ~ wt + hp + qsec + drat,
  data = demo_reg,
  model = "stacking",
  spec = list(
    learners = c("glm", "rpart", "xgboost"),
    learner_specs = list(xgboost = xgb_spec),
    meta_model = "glmnet"
  ),
  seed = 42
)

round(predict(stack_fit, demo_reg[1:5, , drop = FALSE]), 2)
#> [1] 21.33 21.40 22.18 21.60 17.51
```

## 9. Capability summary from the live catalog

Rather than hardcoding learner names, you can summarize the current
registry directly from `list_learners()`.

``` r
catalog_summary <- data.frame(
  capability = c(
    "Supports regression",
    "Supports classification",
    "Supports probabilities",
    "Supports multiclass",
    "Supports feature importance",
    "Currently available"
  ),
  learners = c(
    paste(catalog$learner[catalog$supports_regression], collapse = ", "),
    paste(catalog$learner[catalog$supports_classification], collapse = ", "),
    paste(catalog$learner[catalog$supports_prob], collapse = ", "),
    paste(catalog$learner[catalog$supports_multiclass], collapse = ", "),
    paste(catalog$learner[catalog$supports_importance], collapse = ", "),
    paste(catalog$learner[catalog$available], collapse = ", ")
  ),
  row.names = NULL
)

catalog_summary
#>                    capability
#> 1         Supports regression
#> 2     Supports classification
#> 3      Supports probabilities
#> 4         Supports multiclass
#> 5 Supports feature importance
#> 6         Currently available
#>                                                                                                                                                                                           learners
#> 1                                           bart, cforest, ctree, e1071_svm, earth, gam, gbm, glm, glmnet, kknn, lightgbm, nnet, pls, randomForest, ranger, rpart, stacking, superlearner, xgboost
#> 2      adaboost, bart, C50, cforest, ctree, e1071_svm, earth, fda, gam, gbm, glm, glmnet, kknn, lda, lightgbm, naivebayes, nnet, qda, randomForest, ranger, rpart, stacking, superlearner, xgboost
#> 3           adaboost, bart, C50, cforest, ctree, e1071_svm, earth, gam, gbm, glm, glmnet, kknn, lda, lightgbm, naivebayes, nnet, qda, randomForest, ranger, rpart, stacking, superlearner, xgboost
#> 4                                            C50, cforest, ctree, e1071_svm, fda, glmnet, kknn, lda, lightgbm, naivebayes, nnet, qda, randomForest, ranger, rpart, stacking, superlearner, xgboost
#> 5                                                                                                                                       earth, gbm, lightgbm, randomForest, ranger, rpart, xgboost
#> 6 adaboost, bart, C50, cforest, ctree, e1071_svm, earth, fda, gam, gbm, glm, glmnet, kknn, lda, lightgbm, naivebayes, nnet, pls, qda, randomForest, ranger, rpart, stacking, superlearner, xgboost
```

## 10. Summary

`funcml` is designed so the same fitted object model and the same
learner catalog can support:

- learner discovery with `list_learners()`
- one-model training with `fit()`
- prediction with `predict()`
- resampled validation with `evaluate()`
- hyperparameter search with `tune()`
- learner benchmarking with `compare_learners()`
- model explanation with `interpret()`
- plug-in g-computation with `estimate()`

That is the central idea of the package: one explicit API surface for
tabular machine learning in R, rather than a stack of disconnected
modeling wrappers.
