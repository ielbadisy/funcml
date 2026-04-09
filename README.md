
<!-- README.md is generated from README.Rmd. Please edit that file. -->

# funcml

`funcml` is a machine learning framework for R with one compact
interface for fitting models, validating them, tuning them, comparing
learners, interpreting predictions, and estimating causal effects.

The package is intentionally opinionated: preprocessing happens before
`fit()`, the modeling input stays explicit, and the framework stays
compact instead of expanding into a large orchestration framework.

## Why `funcml`?

- One consistent surface: `fit()`, `predict()`, `evaluate()`, `tune()`,
  `compare_learners()`, `interpret()`, and `estimate()`.
- Plot-ready outputs: evaluation, tuning, comparison, explanation,
  calibration, and treatment-effect objects all have native plot
  methods.
- Broad learner coverage: tree models, penalized GLMs, kernel methods,
  gradient boosting, Bayesian trees, and native ensemble learners.
- Audited learner layer: unsupported modes are blocked explicitly.

## Installation

``` r
install.packages("remotes")
remotes::install_github("ielbadisy/funcml")
```

Installing `funcml` makes the core learner registry available without
extra registration steps. The `lightgbm` learner may need to be
installed separately before that learner id is available.

Examples:

``` r
install.packages("xgboost")
```

``` r
# see the official LightGBM R installation guide
```

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
interpretability, and causal estimation tasks.

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

![](README_files/figure-gfm/eval-plot-1.png)<!-- -->

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

tune_obj$best[, c(names(tune_grid), "mean", "conf_low", "conf_high")]
#>   max_depth eta nrounds     mean    conf_low conf_high
#> 7         2 0.1      30 2.938398 -0.05709457  5.933891
```

``` r
tune_table <- tune_obj$results[order(tune_obj$results$mean), c(names(tune_grid), "mean", "conf_low", "conf_high")]
tune_table
#>   max_depth  eta nrounds     mean    conf_low conf_high
#> 7         2 0.10      30 2.938398 -0.05709457  5.933891
#> 3         2 0.10      20 3.105323 -0.55410645  6.764753
#> 8         3 0.10      30 3.134498  0.13583466  6.133162
#> 4         3 0.10      20 3.234155 -0.34665172  6.814961
#> 5         2 0.05      30 3.348797 -0.32544499  7.023039
#> 6         3 0.05      30 3.433179 -0.31782192  7.184180
#> 2         3 0.05      20 3.838658  0.09467180  7.582643
#> 1         2 0.05      20 3.909885  0.56273243  7.257037
```

``` r
plot(tune_obj)
```

![](README_files/figure-gfm/tune-plot-1.png)<!-- -->

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

![](README_files/figure-gfm/compare-plot-1.png)<!-- -->

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

![](README_files/figure-gfm/ale-plot-1.png)<!-- -->

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

![](README_files/figure-gfm/shap-plot-1.png)<!-- -->

The interpretation layer also supports permutation importance, PDP, ICE,
local surrogate explanations, global surrogates, interaction strength,
ceteris paribus profiles, and calibration diagnostics.

### 4. Inspect class-probability columns directly

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
  cls_fit,
  demo_cls_test,
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

### 5. Estimate causal effects with the same learner interface

This synthetic causal example has measured confounding and a known
treatment effect centered near `1.2`, so the ATE output has a meaningful
target.

``` r
est_obj <- estimate(
  demo_causal,
  outcome ~ trt + x1 + x2 + x3 + trt:x3,
  model = "glm",
  estimand = "ATE",
  treatment_level = 1,
  control_level = 0,
  interval = "normal",
  seed = 42
)

summary(est_obj)
#>       estimand treatment treatment_level control_level estimate std_error
#> lower      ATE       trt               1             0 1.214864 0.0123336
#>       interval_method conf_level conf_low conf_high
#> lower          normal       0.95 1.190691  1.239038
```

``` r
plot(est_obj)
```

![](README_files/figure-gfm/estimate-plot-1.png)<!-- -->

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

The current registry covers 25 learner ids. Broadly:

| Support                            | Learners                                                                                                                                                                  |
|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Regression + classification        | `glm`, `rpart`, `glmnet`, `ranger`, `nnet`, `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`, `lightgbm`, `xgboost`, `stacking`, `superlearner` |
| Regression + binary classification | `earth`, `gam`, `bart`                                                                                                                                                    |
| Classification only                | `C50`, `naivebayes`, `fda`, `lda`, `qda`                                                                                                                                  |
| Binary classification only         | `adaboost`                                                                                                                                                                |
| Regression only                    | `pls`                                                                                                                                                                     |

Use `list_learners()` to inspect the full learner catalog and
capabilities in your current session:

``` r
catalog <- list_learners()

catalog[, c(
  "learner",
  "supports_regression",
  "supports_classification",
  "supports_prob",
  "supports_multiclass",
  "engine_package",
  "available"
)]
#>         learner supports_regression supports_classification supports_prob
#> 15     adaboost               FALSE                    TRUE          TRUE
#> 23         bart                TRUE                    TRUE          TRUE
#> 9           C50               FALSE                    TRUE          TRUE
#> 18      cforest                TRUE                    TRUE          TRUE
#> 17        ctree                TRUE                    TRUE          TRUE
#> 6     e1071_svm                TRUE                    TRUE          TRUE
#> 11        earth                TRUE                    TRUE          TRUE
#> 14          fda               FALSE                    TRUE         FALSE
#> 12          gam                TRUE                    TRUE          TRUE
#> 8           gbm                TRUE                    TRUE          TRUE
#> 1           glm                TRUE                    TRUE          TRUE
#> 3        glmnet                TRUE                    TRUE          TRUE
#> 10         kknn                TRUE                    TRUE          TRUE
#> 19          lda               FALSE                    TRUE          TRUE
#> 21     lightgbm                TRUE                    TRUE          TRUE
#> 13   naivebayes               FALSE                    TRUE          TRUE
#> 5          nnet                TRUE                    TRUE          TRUE
#> 16          pls                TRUE                   FALSE         FALSE
#> 20          qda               FALSE                    TRUE          TRUE
#> 7  randomForest                TRUE                    TRUE          TRUE
#> 4        ranger                TRUE                    TRUE          TRUE
#> 2         rpart                TRUE                    TRUE          TRUE
#> 24     stacking                TRUE                    TRUE          TRUE
#> 25 superlearner                TRUE                    TRUE          TRUE
#> 23      xgboost                TRUE                    TRUE          TRUE
#>    supports_multiclass engine_package available
#> 15               FALSE            ada      TRUE
#> 23               FALSE         dbarts      TRUE
#> 9                 TRUE            C50      TRUE
#> 18                TRUE       partykit      TRUE
#> 17                TRUE       partykit      TRUE
#> 6                 TRUE          e1071      TRUE
#> 11               FALSE          earth      TRUE
#> 14                TRUE            mda      TRUE
#> 12               FALSE           mgcv      TRUE
#> 8                FALSE            gbm      TRUE
#> 1                FALSE          stats      TRUE
#> 3                 TRUE         glmnet      TRUE
#> 10                TRUE           kknn      TRUE
#> 19                TRUE           MASS      TRUE
#> 21                TRUE       lightgbm      TRUE
#> 13                TRUE     naivebayes      TRUE
#> 5                 TRUE           nnet      TRUE
#> 16               FALSE            pls      TRUE
#> 20                TRUE           MASS      TRUE
#> 7                 TRUE   randomForest      TRUE
#> 4                 TRUE         ranger      TRUE
#> 2                 TRUE          rpart      TRUE
#> 25                TRUE         funcml      TRUE
#> 26                TRUE         funcml      TRUE
#> 24                TRUE        xgboost      TRUE
```
