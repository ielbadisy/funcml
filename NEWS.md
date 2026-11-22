# funcml 0.9.19

* A fold seed (`cv(seed = )`, and the default `cv(5, seed = 1)` of `superlearner`) now fixes the
  splits without resetting the caller's random stream. Before, each `superlearner` fit reset the
  global seed, so all bootstrap replicates in `estimate()` were identical and the standard error
  was 0. Results of code that drew random numbers after a seeded `cv()` change.

# funcml 0.9.18

* Tree learners whose engines split on factors natively (`ranger`, `rpart`, `randomForest`, `gbm`,
  `C50`, `adaboost`, `ctree`, `cforest`) now receive the predictors as a data frame with factor columns
  kept as factors, instead of the one-hot model matrix. Levels are fixed from the training data, so
  `predict()` accepts new data with missing levels or a single row; unseen levels are still an error.
  Splits on one-hot columns cost these learners accuracy: same-fold 5-fold CV AUC on `heartdisease`
  rises from 0.826 to 0.846 for `ranger` and from 0.734 to 0.795 for `rpart`. Results of these learners
  change wherever the data have factor or character predictors. The other learners keep the model matrix.
  The switch is a registry field (`encoding = "native"`); the encoding used is stored in the fit at
  `$encoding`. Formulas with interactions or matrix terms, and factors with more levels than the engine
  accepts (53 for `randomForest`, 1024 for `gbm`), fall back to the model matrix. Base learners inside
  `stacking` and `superlearner` still receive the model matrix.
* Native model importance (`interpret(method = "vip", importance_type = "model")`) of these learners is
  now the engine's score per original variable instead of a sum over dummy columns.
* `defaulttunegrid()` sizes `mtry` from the number of variables for these learners, so the grid never
  asks for more variables than the engine sees.
* `listlearners(columns = "encoding")` reports each learner's predictor encoding.

# funcml 0.9.17

* `estimate(interval = "bootstrap")` (and the bootstrap SE used for non-glm learners) predicted every
  replicate on the original rows. For the ATT the treated weights came from the resampled rows but were
  applied to the original rows, so each replicate averaged the effects over a random subset instead of the
  treated (bug fix). For the ATE the replicates missed the sampling variability of the covariates. Each
  replicate now refits and averages over its own resampled rows; CATE still averages over `newdata`.
  ATT and ATE bootstrap intervals change.
* `estimate()` took the default control and treated arms of a factor or character treatment in order of
  appearance, so the sign of the effect depended on the row order (bug fix). Factors now use `levels()`
  (first level = control, second = treated) and characters use sorted values, as numerics already did.
* Metrics in `evaluate()`, `tune()`, `compare()` and `bootvalidate()` dropped classes absent from a test
  fold (`factor(truth)`) and renormalised the predicted probabilities over the classes present, so log
  loss, Brier score and multiclass AUC were computed on probabilities the model never produced (bug fix).
  The model's full class set is now kept; a one-vs-rest AUC is skipped for an absent class. Results change
  only on folds where a class is absent (small or rare-class data).
* `f1(average = "macro")`, and `f1()` for outcomes with more than two classes, returned the harmonic mean
  of macro precision and macro recall instead of the documented macro F1, the mean of the per-class F1
  scores (bug fix). Binary F1 is unchanged.
* Class predictions from tied probabilities were broken at random in `evaluate()`, `tune()` and the
  ranger and randomForest adapters (`max.col()` default), so fold metrics such as accuracy depended on the
  random number stream for trees and kNN. Ties now go to the first class everywhere, as in `predict()`,
  `interpret()` and `bootvalidate()`.
* `tune()` scored each configuration on different folds unless the resampling object carried its own
  seed (each configuration's seed redrew the folds), so the selection mixed fold noise with the
  hyperparameter effect (bug fix). The folds are now drawn once and shared by all configurations, as in
  `compare()`. Tuning results change when `resampling` has no seed.
* `listinterpretabilitymethods()` now lists all 15 `interpret()` methods (`dca` was missing), and the
  `interpret_methods` column of `listlearners()` includes `local_model`, `profile` and `ceteris_paribus`.
* `evaluate(data, fit = f)` failed with "argument formula is missing"; `formula` now defaults to the
  formula stored in `fit` (bug fix).
* `fit(seed = )` (and the seeds of `evaluate()`, `tune()`, `compare()`) did not reach the `densemlp`,
  `mlp` and `fastgbm` engines, which always used seed 1 (bug fix). Their seed is now drawn from R's
  random stream unless `spec$seed` is given, so it follows `seed` and `set.seed()`.
* `compare()` gains `reference` (default: the first model) and returns `differences`: fold-wise paired
  differences of each learner against the reference on the shared folds, with standard error, t interval
  and p-value. They are printed under the results table.
* `compare()` and `tune()` gain `se_method` (default `"naive"`, unchanged). `"corrected"` applies the
  Nadeau and Bengio (2003) variance to the learner and configuration summaries, the nested estimates and
  the paired differences (corrected resampled t test).
* `gbm` now fits multiclass outcomes (multinomial deviance). Its multiclass prediction branch existed
  but was unreachable because the adapter declared `multiclass = FALSE`.

# funcml 0.9.16

* `plot(<funcml_bootvalidate>)` facet strips showed raw metric codes ("auc", "calslope"); they now carry
  the same direction labels as `plot(<funcml_compare>)` and `plot(<funcml_eval>)`, e.g.
  "auc (higher is better)" (bug fix).
* `plot()` for `interpret(method = "ale")`, `"pdp"` and `"ice"` results gains `labels =`, a named vector
  of per-feature axis titles (e.g. `c(age = "Age (years)")`). Each panel then shows its own title under
  its axis; the default `NULL` keeps the strips and the shared "Feature value" title.

# funcml 0.9.15

Plot look and defaults changed (bug fixes); no numeric result changes except the ALE curve and the
default permutation metric for classification, both noted below.

* No plot method writes an automatic title or subtitle any more. Every `plot()` method takes
  `title`, `subtitle` and `caption` arguments (default `NULL`, no text).
* `plot(<funcml_compare>)` shared one value axis across metrics, so AUC and Brier were squeezed onto a
  common scale. It now draws one panel per metric with free scales (`scales = "free_x"`, set
  `"fixed"` for the old behaviour), strips such as "auc (higher is better)", models ordered best on
  top by the first metric, a grey interval and a black point, without `coord_flip()`.
* `plot(<funcml_eval>)` used blue labels and one shared axis. It now shows one free panel per metric
  (fold values as a grey box with points, the mean and its interval) in greys and black, with the
  same direction strips.
* `interpret(method = "ale")` cut the feature at the inner deciles and plotted bin midpoints, so the
  tails and the first bin were lost. Cut points are now the observed quantiles at 0, 1/K, ..., 1
  (`grid.resolution`, default 20) and the curve is returned at the cut points, starting at the
  minimum; results equal `iml::FeatureEffect(method = "ale")` on the same grid (test). ALE values
  change (bug fix).
* The interaction heatmap used different feature orders on its two axes. Both axes now share one order
  (diagonal of self-pairs), with 45 degree x labels and a square panel.
* `interpret(method = "permute")` scored predicted probabilities with accuracy by default. The default
  for classification is now `"auc"` (`"accuracy"` only with `type = "class"`); explicit `metric =`
  calls give the same numbers as before. The axis label states the direction ("Drop in AUC after
  permutation", "Increase in RMSE after permutation").
* `calibrationfit()` now returns class `funcml_calfit` (columns and values unchanged) with a new
  `plot.funcml_calfit(x, ..., bins = 10, strategy, ci = TRUE, stats = TRUE)` method: the binned
  calibration curve, the logistic recalibration curve and the estimated intercept and slope with their
  intervals.
* Calibration plots (`calibrationcurve()`, `interpret(method = "calibration")`) gain Wilson intervals
  per bin (`ci = TRUE`, `level = 0.95`; equal to `prop.test(correct = FALSE)`, test) and no longer fix
  the coordinate system, so `+ coord_cartesian()` works without a message (square panel kept).
* New `plot.funcml_bootvalidate(x, ..., what = c("optimism", "orig", "boot"), metrics = NULL,
  bins = 25)`: histograms of the bootstrap optimism (or apparent, or bootstrap) values per metric,
  with the mean and a reference line (0 for optimism, 1 and 0 for `calslope` and `citl`).
* The SHAP waterfall was a red/green bar chart without feature values. It now runs from the baseline
  to the prediction, labels each bar "feature = value", and uses vermillion/blue (Okabe-Ito) for
  contributions that raise or lower the prediction. All SHAP plots use the same two colours.
* ROC, tuning, decision curve, estimand, surrogate and local-model plots use greys/black plus blue and
  vermillion only.
* `iml` added to Suggests (tests only); `tools` dropped from Imports (no longer used).

# funcml 0.9.14

* `plot()` on a `dca()` result drew a pairs plot because `dca()` returned a plain data frame. `dca()` now returns a data frame of class `funcml_dcacurve` (columns unchanged) with a new `plot.funcml_dcacurve(x, ..., labels = NULL, ylim = NULL, title = NULL)` method: net benefit against threshold for one or more models (extra `dca()` results via `...`), with "treat all" (dashed) and "treat none" reference lines and a default net benefit axis from -0.05 to the largest net benefit. Plotted values equal `dcurves::dca()` (test).
* `calibrationcurve()` had the same problem; it now returns class `funcml_calcurve` (columns unchanged) with a `plot()` method drawing observed against mean predicted risk per bin with the ideal diagonal.
* `plot()` on `interpret(method = "dca")` uses the same drawing: sober black/grey lines and the -0.05 axis floor (was -0.1 and coloured lines). `interpret(method = "calibration")` plots share the calibration drawing code (same look).
* `dcurves` added to Suggests (tests only).

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

