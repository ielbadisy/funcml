# funcml 0.9.13

* New calibration metrics `calslope()` (calibration slope) and `citl()` (calibration-in-the-large), the `slope` and `intercept` rows of `calibrationfit()`. As metric names `"calslope"` and `"citl"` they work in `bootvalidate()` and `evaluate()` and are listed by `listmetrics()` (direction `"target"`: ideal values 1 and 0). In `bootvalidate()` the optimism-corrected slope equals `rms::validate()`'s corrected `Slope` when both are seeded identically; `gamma` and `est632plus` are `NA` for these metrics. `tune()` refuses them as tuning criteria; `compare()` ranks them by distance to the ideal value.

# funcml 0.9.12

* `auc()` overflowed integer arithmetic in the pair count (positives times
  negatives) and returned `NA` for large samples. This broke
  `bootvalidate()` with `metrics = "auc"` (and the default classification
  metrics) for n of about 400 and more, where the no-information value was
  computed on 250,000 sampled pairs. Fixed; the no-information AUC in
  `bootvalidate()` is now exactly 0.5 (bug fix: `gamma` and `est632plus`
  for `auc` change slightly at large n).
* `coef()` on a `glmnet` fit returns the coefficients at the selected
  lambda (`$state$lambda_sel`), as `coef(enginemodel(m), s = m$state$lambda_sel)`,
  a matrix with one column per class for multinomial fits.
* `calibrationcurve()`, `ece()` and `mce()` with `strategy = "quantile"`
  collapsed to few bins when tied scores made quantile break points
  coincide. The bins are now cut between distinct scores, giving
  `min(bins, number of distinct scores)` bins of near equal size (bug fix:
  results change only for tied scores).
* New `calibrationfit()` returns the calibration intercept
  (calibration-in-the-large), the calibration slope and the recalibration
  intercept with Wald confidence intervals, matching `glm()` and
  `rms::val.prob()`.

# funcml 0.9.11

* The `xgboost` learner accepts a regression `objective` in `spec`
  (default `"reg:squarederror"`), so count and skewed outcomes can be fitted
  with `"count:poisson"`, `"reg:gamma"` or `"reg:tweedie"` (plus
  `tweedie_variance_power`). Predictions are on the mean scale.
* New `bootvalidate()` for bootstrap internal validation of any learner.
  It returns the apparent performance, the Harrell optimism-corrected
  estimate (as `rms::validate()`), the leave-one-out bootstrap (OOB)
  estimate, and the Efron `.632` and Efron-Tibshirani `.632+` estimates
  for each metric, with per-replicate values and the bootstrap indices.
  With the same seed the optimism-corrected values match `rms::validate()`
  for `lrm` and `ols` fits.
* `kknn` treated `k` as the largest k of a leave-one-out search, so the
  fitted model could use fewer neighbours than asked. `k` is now the exact
  number of neighbours. The kernel, fixed at `"optimal"` before, is now the
  spec entry `kernel` (default `"optimal"`).
* `e1071_svm` gains the spec entry `epsilon` (default 0.1, the e1071
  default), so support vector regression can be tuned on it.
* New `splits()` draws the train/test row indices of any resampling scheme
  (`cv()`, `holdout()`, `groupcv()`, `timecv()`) outside `evaluate()`. For a
  holdout split the indices are returned directly as `$train` and `$test`.
  The result is frozen: passing it back to `evaluate()`, `compare()` or
  `tune()` on the same data reuses the same folds.

# funcml 0.9.10

* `brier()` and `logloss()` given a plain probability vector for a binary
  outcome returned `mean(p^2)` and `NA` respectively. The vector is now read
  as the probability of the second (positive) level, so `brier()` returns
  `mean((p - y)^2)`; a vector with a multiclass outcome is an error.
* `precision()`, `recall()`, `specificity()` and `f1()` macro-averaged over
  both classes of a binary outcome, so recall and specificity always equalled
  balanced accuracy (and `compare()` showed the same value for all three).
  For binary outcomes they are now computed for the positive class (second
  factor level, or `positive`). New `average = c("binary", "macro")` and
  `positive` arguments; multiclass outcomes stay macro-averaged and
  `balancedaccuracy()` is unchanged.
* `estimate()` reported the spread of the unit-level effects as the standard
  error, which ignores uncertainty in the outcome model (SE 0 and a
  zero-width CI for an additive `glm`). With `model = "glm"` the normal
  interval now uses a delta-method SE of the g-computation contrast; other
  learners and `interval = "bootstrap"` use the SD of `n_boot` bootstrap
  refits. `$bootstrap` now keeps the replicate estimates and their SD.
* The `stacking` learner fitted its meta-learner on in-sample base-learner
  predictions. It now uses K-fold out-of-fold predictions (new spec entry
  `folds`, default 5, reproducible with `seed`) and refits the base learners
  on all rows for prediction. The meta-features are stored at
  `$state$meta_x`.
* `compare()` checks for missing values before drawing folds and stops with
  an error that names `compare()`, the affected columns and the number of
  incomplete rows (before, the error came from `evaluate()` or from fold
  generation). The behaviour is documented in `?compare` and `?evaluate`.

# funcml 0.9.9

* `compare()` now draws the resampling folds once (from `seed` or the
  resampling's own seed) and shares them across all learners. Before, with
  the default `cv(5)` (no seed) each learner got different folds even when
  `compare(seed = )` was set. The frozen folds are returned in
  `$resampling` and are reused when passed back to `evaluate()` or
  `compare()` on the same data.
* `compare(tune = TRUE)` now estimates performance by nested resampling
  (new `nested = TRUE` default and `inner_resampling` argument): tuning runs
  inside each outer training fold, so the estimate is no longer
  optimistically biased by tuning and scoring on the same folds.
  `nested = FALSE` restores the old, optimistic estimate. Per-fold selected
  configurations are in `$details[[learner]]$selected_specs`.
* `compare()` and `evaluate()` now return out-of-fold predictions in
  `$predictions` (row, repeat, fold, truth, and predictions or class
  probabilities), ready for paired tests such as DeLong or a bootstrap.
* `evaluate()` gains `pooled = FALSE`; when `TRUE`, metrics are also
  computed on the pooled out-of-fold predictions (`$pooled`). The docs now
  explain that fold-averaged ECE/MCE are inflated by bin noise compared with
  the pooled values.
* `fit()` lets `NA` predictors through to learners that handle them natively
  (currently `fastgbm`) when `na_action` is not supplied; an `NA` outcome is
  still an error. `evaluate()` follows the same rule.
* `interpret(method = "permute")` (and the calibration and DCA methods)
  aligned the outcome with the predictions incorrectly when predictors had
  `NA`, which gave odd negative importances; fixed.
* New `enginemodel()` returns the fitted engine object, stored at
  `$state$state` (now documented in `?fit`).

# funcml 0.9.8

Exported functions are now glued lowercase, with no underscores. The old names
still work but are deprecated and will be removed in a future release.

| Old name | New name |
|----------|----------|
| `auc_ci()` | `aucci()` |
| `auc_weighted()` | `aucweighted()` |
| `balanced_accuracy()` | `balancedaccuracy()` |
| `calibration_curve()` | `calibrationcurve()` |
| `default_tune_grid()` | `defaulttunegrid()` |
| `group_cv()` | `groupcv()` |
| `list_interpretability_methods()` | `listinterpretabilitymethods()` |
| `list_learners()` | `listlearners()` |
| `list_metrics()` | `listmetrics()` |
| `list_tunable_learners()` | `listtunablelearners()` |
| `roc_curve()` | `roccurve()` |
| `theme_funcml()` | `themefuncml()` |
| `time_cv()` | `timecv()` |

Metric identifiers such as `"balanced_accuracy"` and `"auc_weighted"` are unchanged.

