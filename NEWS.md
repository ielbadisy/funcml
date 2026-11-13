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

