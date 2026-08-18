# funcml 0.8.5

- Added numeric value labels to every bar-chart-style plot for easier
  reading: SHAP waterfall (`+0.148`/`-0.089` style, signed), SHAP
  feature importance, SHAP interaction strength, and local surrogate
  (`interpret(method = "local_model")`) contributions. The local
  surrogate plot's colors were also swapped to match the SHAP
  convention (positive = red, negative = green).

# funcml 0.8.4

- Fixed a hang introduced in 0.8.2: `interpret(method = "shap", ncores
  = <n>)` with `xgboost`, `lightgbm`, `mlp`, `densemlp`, or `bart` on
  Unix could hang indefinitely, because `functionals::fmap()` forks the
  process (`parallel::mclapply()`) and those models' fitted state holds
  a C/C++ handle that is not valid in the forked child. `ncores` is now
  ignored (with a warning) for those models, falling back to
  sequential; other models parallelize as before.

# funcml 0.8.3

- SHAP waterfall (`kind = "waterfall"`) is now a zero-anchored per-feature
  contribution bar chart instead of a cumulative chained waterfall: every
  bar starts at 0 and extends to its own SHAP value, so no bar crosses
  from one side of the reference line to the other. The vertical
  reference line is fixed at 0 instead of the baseline prediction.
- SHAP beeswarm/summary (`kind = "summary"`/`"beeswarm"`) now uses the
  standard SHAP blue (low) to red (high) colorbar on the right, instead
  of the previous bottom yellow-to-purple legend, and drops the
  per-feature numeric labels for plain feature names. It also gained a
  `v` argument to restrict the plot to a single feature.

# funcml 0.8.2

- `interpret(method = "shap")` gained an `ncores` argument that
  parallelizes the per-observation Monte Carlo SHAP computation via
  `functionals::fmap()` (the same backend already used by
  `evaluate()`/`tune()`/`compare_learners()`). Each observation is now
  seeded independently (`seed + observation_index - 1`) so results are
  identical whether run sequentially or in parallel; this changes the
  exact values produced by a seeded `interpret(method = "shap")` call
  compared to earlier releases, though the estimator itself (Monte
  Carlo permutation SHAP) is unchanged.

# funcml 0.8.1

- Printed result tables (`evaluate()`, `compare_learners()`, `tune()`,
  `interpret(method = "calibration")`, `interpret(method = "dca")`,
  `roc_curve()`, `auc_ci()`) now round numeric columns to 4 digits by
  default (`digits` argument on the relevant `print()`/`summary()`
  methods and on `auc_ci()`), instead of printing full floating-point
  precision.
- Swapped the SHAP waterfall/force colors: positive contributions are
  now red, negative are green.
- Reworked the SHAP beeswarm/summary plot (`kind = "beeswarm"` /
  `"summary"`) to show mean |SHAP value| next to each feature name, a
  yellow-to-purple `viridis` "plasma" feature-value gradient, and a
  bottom legend with Low/High endpoints. Also fixed a row-order
  misalignment bug in the per-feature value scaling introduced by the
  0.8.0 native SHAP plot rewrite.

# funcml 0.8.0

- Added `densemlp` as a new learner, wrapping the published `densemlp`
  CRAN package. It complements the existing built-in `mlp` learner with
  richer architecture options (residual connections, gated blocks, input
  projection, focal loss, label smoothing, LR schedules) for regression
  and classification.
- Added `roc_curve()` and `auc_ci()`, backed by the `pROC` package:
  `roc_curve()` returns the full sensitivity/specificity curve plus a
  `plot()` method, and `auc_ci()` reports AUC with a DeLong (default) or
  bootstrap confidence interval. funcml's own fast `auc()` is unchanged
  and remains what resampling/tuning use internally.
- Added decision curve analysis (Vickers and Elkin, 2006): `dca()` computes
  net benefit across risk thresholds for the model, "treat all", and
  "treat none" strategies, and `interpret(method = "dca")` runs it directly
  on a fitted binary classifier with a `plot()` method.
- Removed the `shapviz` dependency. All SHAP plot kinds (`waterfall`,
  `force`, `summary`/`beeswarm`, `importance`/`bar`, `dependence`,
  `dependence2d`, `interaction`) are now native `ggplot2` implementations
  reading directly from funcml's own SHAP result table. The underlying
  SHAP values were already funcml's own Monte Carlo permutation estimate
  (`interpret(method = "shap")`); shapviz was only ever used for plotting.
- Reworked `theme_funcml()` to match the CLAVUS Nature Medicine figure
  style: `theme_classic()` base, Okabe-Ito colorblind-safe palette, bold
  unboxed strip labels, and `grey92` major gridlines. All package plots
  (`interpret()`, `evaluate()`, `compare_learners()`, `tune()`,
  `estimate()`) now share this theme instead of each building its own
  ad-hoc `theme_bw()`/`theme_minimal()` variant.
- Migrated internal row-accumulation (resampling folds, tuning grids,
  learner comparisons, PDP/ICE/ALE curves, permutation importance,
  interaction grids, MLP training history) from `do.call(rbind, ...)` to
  `data.table::rbindlist()` for faster combination of many small result
  frames. All public return objects remain plain `data.frame`s; no API
  or behavior change.
- Added a citation for Naimi, Cole, and Kennedy (2016)
  <doi:10.1093/ije/dyw323> to `DESCRIPTION`, covering the plug-in
  g-computation method.
- `plot.funcml_pdp()` now fixes the y-axis to the [0, 1] probability scale
  for classification PDPs (`type = "prob"`), instead of auto-scaling to the
  local range of the curve, which could visually exaggerate small effects.
  Regression PDPs are unaffected.
- Moved every learner engine package (`MASS`, `mgcv`, `nnet`, `rpart`,
  `glmnet`, `ranger`, `e1071`, `randomForest`, `gbm`, `C50`, `kknn`,
  `earth`, `naivebayes`, `mda`, `ada`, `pls`, `partykit`, `dbarts`,
  `torch`, `xgboost`, `lightgbm`, `densemlp`) from `Suggests` to
  `Imports`, so a standard installation always has every advertised
  learner available and `learners()`/`fit()` cannot fail with a
  missing-package error for a registered model.

# funcml 0.7.2

- Added `mlp` as an internal torch-backed learner for regression, binary
  classification, and multiclass classification.
- Added CRAN installation instructions to the README and kept the GitHub
  installation path for development snapshots.
- Added a README note that the `funcml` companion paper is submitted to
  JMLR.

# funcml 0.7.1

- Refined the README into a more detailed progressive API walkthrough with
  additional tables, figures, and staged examples covering the full package
  surface.
- Hardened interpretability runtime paths by forcing `vip` to use
  permutation importance consistently while retaining `shapviz`-enhanced
  SHAP plotting when the optional plotting packages are installed.

# funcml 0.7.0

- Consolidated `funcml` as a machine learning framework for R with stable S3 interfaces for fitting, prediction, evaluation, tuning, learner comparison, interpretation, and plug-in g-computation.
- Added richer resampling support through plain holdout, grouped cross-validation, and time-aware rolling splits.
- Added uncertainty summaries to `evaluate()` and `compare_learners()`, including fold-level standard errors and confidence intervals in summaries and plots.
- Added random-search tuning with `search = "random"` and `n_evals`, plus nested resampling support in `tune()` for outer-fold performance estimates of the model-selection procedure.
- Hardened the fit/predict contract with clearer errors for missing predictor columns and unseen factor levels, stricter probability-output normalization, and broader learner contract coverage across the registry.
- Added multiclass and weighted AUC support and clarified default evaluation behavior for binary versus multiclass classification.
- Added `list_learners()` as a learner capability catalog and improved package metadata, citation, and repository scaffolding for release and paper preparation.
- Removed the `catboost` learner backend from the registry and package metadata.
- Kept `lightgbm` as a standard learner dependency available with `funcml`.

# funcml 0.2.0

- Added richer evaluation-centered resampling with plain holdout, grouped cross-validation, and time-aware rolling splits.
- Added uncertainty summaries to `evaluate()` and `compare_learners()`, including fold-level standard errors and confidence intervals in summaries and plots.
- Extended `estimate()` with configurable interval reporting, including bootstrap percentile intervals for average causal estimands.
- Added random-search tuning with `search = "random"` and `n_evals` for budgeted hyperparameter search.
- Added nested resampling to `tune()` via `outer_resampling`, so tuning can report unbiased outer-fold performance estimates for the selected workflow.
- Hardened the fit/predict contract with clearer errors for missing predictor columns and unseen factor levels, plus stricter probability-output normalization.
- Expanded the test suite with focused coverage for resampling, uncertainty, tuning, and prediction-contract behavior.

# funcml 0.1.1

- Vendored canonical interpretability implementations from `vip`, `pdp`, `iml`, and a minimal internal `shapviz` layer.
- Replaced runtime `vip` and `pdp` dependencies with internal implementations while preserving the existing `funcml` entrypoints.
- Added parity tests against sourced upstream reference code for permutation importance, PDP, ICE, ALE, Shapley values, and local surrogate explanations.
- Switched `local` / `local_model` to an `iml::LocalModel`-style sparse local surrogate using `glmnet` and Gower weighting.
