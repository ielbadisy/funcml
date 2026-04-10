
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
- Broad learner coverage: classical statistical models, trees, kernel
  methods, boosting systems, Bayesian trees, and native ensemble
  learners.
- Audited learner layer: unsupported modes are blocked explicitly.

## Installation

``` r
install.packages("remotes")
remotes::install_github("ielbadisy/funcml")
```

Installing `funcml` makes the learner registry available without extra
registration steps.

## API overview

| Task                 | Main functions                                               | Returned object                        | Typical use                                                         |
|----------------------|--------------------------------------------------------------|----------------------------------------|---------------------------------------------------------------------|
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

## 1. Start by inspecting the learner catalog

`list_learners()` gives a session-aware inventory of the registry,
including task support, probability support, multiclass support, engine
packages, and whether each engine is currently available. You can also
filter the catalog by task or capability and request only the columns
you need for reporting or interactive exploration.

``` r
catalog <- list_learners(
  columns = c(
    "learner",
    "supports_regression",
    "supports_classification",
    "supports_prob",
    "supports_multiclass",
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
  available = sum(catalog$available)
)
#>   learners regression classification prob multiclass available
#> 1       25         19             24   23         18        25
```

``` r
head(list_learners(
  classification = TRUE,
  prob = TRUE,
  available = TRUE,
  columns = c("learner", "supports_prob", "supports_multiclass", "engine_package")
), 10)
#>      learner supports_prob supports_multiclass engine_package
#> 15  adaboost          TRUE               FALSE            ada
#> 22      bart          TRUE               FALSE         dbarts
#> 9        C50          TRUE                TRUE            C50
#> 18   cforest          TRUE                TRUE       partykit
#> 17     ctree          TRUE                TRUE       partykit
#> 6  e1071_svm          TRUE                TRUE          e1071
#> 11     earth          TRUE               FALSE          earth
#> 12       gam          TRUE               FALSE           mgcv
#> 8        gbm          TRUE               FALSE            gbm
#> 1        glm          TRUE               FALSE          stats
```

## 2. Fit one model and inspect the fitted object

The entry point is `fit()`. It returns a compact `funcml_fit` object
that stores the learner id, formula, encoded feature layout, and
prediction machinery.

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
summary(fit_obj)
#> <funcml_fit summary> regression model: xgboost
#> Spec:
#> $nrounds
#> [1] 30
#> 
#> $max_depth
#> [1] 3
#> 
#> $eta
#> [1] 0.1
#> 
#> $subsample
#> [1] 1
#> 
#> $colsample_bytree
#> [1] 1
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

The same resampling interface can also handle grouped CV, rolling time
splits, or plain holdout validation through `group_cv()`, `time_cv()`,
and `holdout()`.

## 4. Tune hyperparameters, then compare learners

`tune()` searches a grid or random sample of hyperparameters using the
same evaluation machinery. `compare_learners()` then places multiple
learners under the same resampling design for an apples-to-apples
comparison.

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

round(tune_obj$best[, c(names(tune_grid), "mean", "conf_low", "conf_high")], 3)
#>   max_depth eta nrounds  mean conf_low conf_high
#> 7         2 0.1      30 2.938   -0.057     5.934
```

``` r
head(tune_obj$results[
  order(tune_obj$results$mean),
  c(names(tune_grid), "mean", "conf_low", "conf_high")
], 6)
#>   max_depth  eta nrounds     mean    conf_low conf_high
#> 7         2 0.10      30 2.938398 -0.05709457  5.933891
#> 3         2 0.10      20 3.105323 -0.55410645  6.764753
#> 8         3 0.10      30 3.134498  0.13583466  6.133162
#> 4         3 0.10      20 3.234155 -0.34665172  6.814961
#> 5         2 0.05      30 3.348797 -0.32544499  7.023039
#> 6         3 0.05      30 3.433179 -0.31782192  7.184180
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

## 5. Interpret a fitted model with the same object

The interpretation layer operates on fitted `funcml_fit` objects, so you
do not need a second modeling interface for explanation tasks.

``` r
permute_obj <- interpret(
  fit_obj,
  demo_reg,
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

## 7. Estimate causal effects with the same learner interface

`estimate()` extends the same framework into plug-in g-computation for
common binary-treatment estimands.

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

The same API also supports `ATT`, `CATE`, and `IATE`.

## 8. Use ensembles as first-class learners

`stacking` and `superlearner` live in the same learner registry as the
base models, so ensembles are fit through the same API rather than a
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

## 9. Learner coverage at a glance

The current registry covers 25 learner ids. Broadly:

| Support                            | Learners                                                                                                                                                      |
|------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Regression + classification        | `glm`, `rpart`, `glmnet`, `ranger`, `nnet`, `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`, `lightgbm`, `xgboost`, `stacking`, `superlearner` |
| Regression + binary classification | `earth`, `gam`, `bart`                                                                                                                                        |
| Classification only                | `C50`, `naivebayes`, `fda`, `lda`, `qda`                                                                                                                      |
| Binary classification only         | `adaboost`                                                                                                                                                    |
| Regression only                    | `pls`                                                                                                                                                         |

## 10. Summary

`funcml` is designed so the same fitted object and the same learner
registry can support:

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
