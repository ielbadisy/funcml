
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# funcml

`funcml` is a formula-first machine learning toolkit for people who want
one compact interface for fitting models, validating them, tuning them,
comparing learners, interpreting predictions, and estimating causal
effects.

The package is intentionally opinionated: preprocessing happens before
`fit()`, the modeling input stays explicit, and the workflow remains
compact instead of expanding into a large orchestration framework.

## Why `funcml`?

- One consistent surface: `fit()`, `predict()`, `evaluate()`, `tune()`,
  `compare_learners()`, `interpret()`, and `estimate()`.
- Plot-ready outputs: evaluation, tuning, comparison, explanation,
  calibration, and treatment-effect objects all have native plot
  methods.
- Broad learner coverage: tree models, penalized GLMs, kernel methods,
  gradient boosting, Bayesian trees, and native ensemble learners.
- Audited learner layer: unsupported modes are blocked explicitly, and
  the repository includes the learner audit artifacts under
  [`work/audit/`](work/audit/).

## Installation

``` r
install.packages("remotes")
remotes::install_github("ielbadisy/funcml")
```

`funcml` imports the supported learner backends directly, so a standard
install brings the learner registry into the package without extra
registration steps.

## What the package covers

| Workflow             | Main functions                                               | Typical output                                                                   |
|----------------------|--------------------------------------------------------------|----------------------------------------------------------------------------------|
| Fit + predict        | `fit()`, `predict()`                                         | compact `funcml_fit` object with formula-aware prediction                        |
| Resampled validation | `cv()`, `holdout()`, `group_cv()`, `time_cv()`, `evaluate()` | fold-level metrics, uncertainty summaries, performance plots                     |
| Model selection      | `tune()`, `compare_learners()`                               | search traces, tuned summaries, side-by-side learner comparison                  |
| Interpretation       | `interpret()`                                                | permutation importance, PDP, ICE, ALE, SHAP, surrogate, interaction, calibration |
| Causal estimation    | `estimate()`                                                 | plug-in g-computation for `ATE`, `ATT`, `CATE`, and `IATE`                       |

## Quick start

``` r
demo_reg <- transform(
  mtcars,
  car = rownames(mtcars)
)

demo_cls <- transform(
  mtcars,
  heavy = factor(ifelse(wt > median(wt), "heavy", "light"),
    levels = c("light", "heavy")
  )
)

demo_causal <- transform(
  demo_reg,
  trt = as.integer(wt > median(wt))
)

xgb_spec <- list(
  nrounds = 30,
  max_depth = 3,
  eta = 0.1,
  subsample = 1,
  colsample_bytree = 1
)
```

``` r
fit_obj <- fit(
  mpg ~ wt + hp + qsec + drat,
  data = demo_reg,
  model = "xgboost",
  spec = xgb_spec,
  seed = 42
)

round(predict(fit_obj, demo_reg[1:5, , drop = FALSE]), 2)
#> [1] 21.21 21.21 22.52 21.27 17.83
```

The same fitted object can immediately feed evaluation, tuning,
interpretability, and causal workflows.

## Workflow gallery

### 1. Cross-validated model performance

``` r
eval_obj <- evaluate(
  demo_reg,
  mpg ~ wt + hp + qsec + drat,
  model = "xgboost",
  spec = xgb_spec,
  resampling = cv(v = 4, seed = 42)
)

summary(eval_obj)
#>   metric       mean         sd n  std_error conf_level    conf_low  conf_high
#> 1   rmse  3.3098266 1.52367053 4 0.76183527       0.95  0.88532681  5.7343265
#> 2    mae  2.6666687 1.24734293 4 0.62367146       0.95  0.68186772  4.6514696
#> 3    mse 12.6961313 9.89521740 4 4.94760870       0.95 -3.04936773 28.4416303
#> 4  medae  2.3683064 1.37102015 4 0.68551008       0.95  0.18670736  4.5499054
#> 5   mape  0.1375875 0.05773173 4 0.02886587       0.95  0.04572342  0.2294516
#> 6    rsq  0.4117001 0.80640932 4 0.40320466       0.95 -0.87147708  1.6948773
```

``` r
plot(eval_obj)
```

<img src="README_files/figure-gfm/eval-plot-1.png" alt="" style="display: block; margin: auto;" />

### 2. Tune a learner, then compare it against alternatives

``` r
tune_grid <- expand.grid(
  max_depth = c(2, 3),
  eta = c(0.05, 0.1),
  nrounds = c(20, 30)
)

tune_obj <- tune(
  demo_reg,
  mpg ~ wt + hp + qsec + drat,
  model = "xgboost",
  grid = tune_grid,
  resampling = cv(v = 3, seed = 42),
  metric = "rmse",
  subsample = 1,
  colsample_bytree = 1,
  seed = 42
)

tune_obj$best
#>   max_depth eta nrounds     mean       sd n std_error conf_level    conf_low
#> 7         2 0.1      30 2.938398 1.205848 3 0.6961968       0.95 -0.05709457
#>   conf_high
#> 7  5.933891
```

``` r
plot(tune_obj)
```

<img src="README_files/figure-gfm/tune-plot-1.png" alt="" style="display: block; margin: auto;" />

``` r
compare_obj <- compare_learners(
  demo_reg,
  mpg ~ wt + hp + qsec,
  models = c("glm", "rpart", "xgboost"),
  metrics = c("rmse", "mae"),
  resampling = cv(v = 4, seed = 42),
  specs = list(xgboost = xgb_spec)
)

summary(compare_obj)
#>     model metric     mean        sd n std_error conf_level  conf_low conf_high
#> 1     glm   rmse 2.823282 0.8391539 4 0.4195769       0.95 1.4880008  4.158563
#> 2     glm    mae 2.324837 0.6977166 4 0.3488583       0.95 1.2146141  3.435060
#> 3   rpart   rmse 4.589988 0.5112815 4 0.2556408       0.95 3.7764255  5.403552
#> 4   rpart    mae 3.781101 0.3039781 4 0.1519891       0.95 3.2974042  4.264798
#> 5 xgboost   rmse 3.374909 1.4559200 4 0.7279600       0.95 1.0582155  5.691603
#> 6 xgboost    mae 2.734509 1.1846891 4 0.5923445       0.95 0.8494044  4.619614
#>   tuned rank
#> 1 FALSE    1
#> 2 FALSE    1
#> 3 FALSE    3
#> 4 FALSE    3
#> 5 FALSE    2
#> 6 FALSE    2
```

``` r
plot(compare_obj)
```

<img src="README_files/figure-gfm/compare-plot-1.png" alt="" style="display: block; margin: auto;" />

### 3. Build explanations from the same fitted model

``` r
ale_obj <- interpret(
  fit_obj,
  demo_reg,
  method = "ale",
  features = c("wt", "hp")
)
```

``` r
plot(ale_obj)
```

<img src="README_files/figure-gfm/ale-plot-1.png" alt="" style="display: block; margin: auto;" />

``` r
shap_obj <- interpret(
  fit_obj,
  demo_reg,
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

<img src="README_files/figure-gfm/shap-plot-1.png" alt="" style="display: block; margin: auto;" />

The interpretation layer also supports permutation importance, PDP, ICE,
local surrogate explanations, global surrogates, interaction strength,
ceteris paribus profiles, and calibration diagnostics.

### 4. Inspect classification probabilities directly

``` r
cls_fit <- fit(
  heavy ~ mpg + hp + qsec + drat,
  data = demo_cls,
  model = "glm",
  seed = 42
)

round(
  predict(cls_fit, demo_cls[1:6, , drop = FALSE], type = "prob"),
  3
)
#>                   light heavy
#> Mazda RX4             1     0
#> Mazda RX4 Wag         1     0
#> Datsun 710            1     0
#> Hornet 4 Drive        1     0
#> Hornet Sportabout     0     1
#> Valiant               0     1
```

``` r
calibration_obj <- interpret(
  cls_fit,
  demo_cls,
  method = "calibration",
  type = "prob",
  bins = 6
)
```

``` r
plot(calibration_obj)
```

<img src="README_files/figure-gfm/calibration-plot-1.png" alt="" style="display: block; margin: auto;" />

### 5. Estimate causal effects with the same learner interface

``` r
est_obj <- estimate(
  demo_causal,
  mpg ~ trt + hp + qsec + drat,
  model = "rpart",
  estimand = "ATE",
  spec = list(cp = 0.01, minsplit = 5),
  interval = "bootstrap",
  n_boot = 20,
  seed = 42
)

summary(est_obj)
#>       estimand treatment treatment_level control_level estimate std_error
#> lower      ATE       trt               1             0        0         0
#>       interval_method conf_level  conf_low conf_high
#> lower       bootstrap       0.95 -9.346892         0
```

``` r
plot(est_obj)
```

<img src="README_files/figure-gfm/estimate-plot-1.png" alt="" style="display: block; margin: auto;" />

## Ensembles are first-class learners

`stacking` and `superlearner` live in the same registry as the base
learners, so you fit them through the same `fit()` interface.

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

## Learner coverage

The current registry covers 26 learner ids. Broadly:

| Support                            | Learners                                                                                                                                                                  |
|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Regression + classification        | `glm`, `rpart`, `glmnet`, `ranger`, `nnet`, `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`, `lightgbm`, `catboost`, `xgboost`, `stacking`, `superlearner` |
| Regression + binary classification | `earth`, `gam`, `bart`                                                                                                                                                    |
| Classification only                | `C50`, `naivebayes`, `fda`, `lda`, `qda`                                                                                                                                  |
| Binary classification only         | `adaboost`                                                                                                                                                                |
| Regression only                    | `pls`                                                                                                                                                                     |

The learner adapter layer was audited package-wide. Unsupported
combinations are now rejected early instead of failing later in
evaluation or interpretation code.
