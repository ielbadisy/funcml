# funcml

`funcml` is a formula-first functional machine learning package for building
end-to-end modeling workflows with a compact S3 interface.

The package is centered on the core machine learning workflow:

- model fitting through `fit()`
- prediction through `predict()`
- learner discovery through `learners()`
- resampling through `cv()`
- model evaluation through `evaluate()`
- hyperparameter tuning through `tune()`
- effect estimation through `estimate()`
- native ensemble learners through `fit(..., model = "stacking")` and
  `fit(..., model = "superlearner")`

Interpretability is included as one part of the package, not the main purpose.

## Core workflow

The main workflow is:

`fit() -> predict() -> evaluate() -> tune() -> estimate() -> interpret()`

```r
fit_obj <- fit(mpg ~ wt + hp, data = mtcars, model = "glm")

pred <- predict(fit_obj, mtcars[1:5, , drop = FALSE])
resampling <- cv(v = 5, seed = 1)
eval_obj <- evaluate(mtcars, mpg ~ wt + hp, model = "glm", resampling = resampling)

grid <- data.frame(degree = c(1, 2))
tune_obj <- tune(mtcars, mpg ~ wt + hp, model = "earth", grid = grid, resampling = resampling)

est_obj <- estimate(
  transform(mtcars, trt = as.integer(wt > median(wt))),
  mpg ~ trt + hp + qsec,
  model = "glm",
  estimand = "ATE"
)

int_obj <- interpret(fit_obj, mtcars, method = "pdp", features = "wt")
```

## Native interpretability methods

- `interpret(..., method = "vip")`
- `interpret(..., method = "permute")`
- `interpret(..., method = "pdp")`
- `interpret(..., method = "ice")`
- `interpret(..., method = "ale")`
- `interpret(..., method = "local")`
- `interpret(..., method = "lime")`
- `interpret(..., method = "local_model")`
- `interpret(..., method = "shap")`
- `interpret(..., method = "profile")`
- `interpret(..., method = "ceteris_paribus")`
- `interpret(..., method = "interaction")`
- `interpret(..., method = "breakdown")`
- `interpret(..., method = "surrogate")`

These methods are implemented natively in the package without vendoring source
code from upstream interpretability libraries.

## Package focus

`funcml` is primarily designed as a unified functional ML interface over
multiple learners and workflows. The package combines:

- formula-first model specification
- a shared `fit()` / `predict()` API across learners
- native stacking and super learner ensembles
- evaluation and tuning utilities
- estimand-oriented analysis
- built-in interpretability methods

## Learners

Current learner ids exposed through `learners()` include:

| Task support | Learners |
| --- | --- |
| Regression + classification | `glm`, `rpart`, `glmnet`, `ranger`, `nnet`, `e1071_svm`, `randomForest`, `gbm`, `kknn`, `ctree`, `cforest`, `lightgbm`, `catboost`, `xgboost`, `stacking`, `superlearner` |
| Regression + binary classification | `earth`, `gam`, `bart` |
| Classification only | `C50`, `naivebayes`, `fda`, `lda`, `qda` |
| Binary classification only | `adaboost` |
| Regression only | `pls` |

Example:

```r
learners()

fit(Species ~ ., data = iris, model = "ctree")
fit(mpg ~ wt + hp, data = mtcars, model = "gam")
```
