# funcml 0.7.3

- Fixed a bug in the `glmnet` learner's `predict_xy` where, if `spec$lambda`
  was not supplied at prediction time, prediction silently fell back to
  `state$state$lambda[1]` -- the *largest* (most-regularized) value in
  glmnet's default lambda path, rather than the lambda actually used or
  intended at fit time. This could collapse predictions toward the
  intercept-only (null) model when a learner was fit with a full default
  regularization path (`lambda = NULL`), producing near-constant predicted
  probabilities and chance-level discrimination downstream. The lambda used
  to fit is now recorded explicitly at `fit_xy` time and always reused at
  `predict_xy` time.
- Fixed a related, more fundamental bug in the `glmnet` learner's `fit_xy`:
  requesting a single lambda value directly in `glmnet::glmnet(..., lambda =
  spec$lambda)` cold-starts the coordinate-descent solver with no warm start
  along the regularization path. On wide or high-cardinality design matrices
  (e.g. many one-hot-encoded categorical predictors) this can fail to
  converge, and glmnet silently returns an empty, all-zero-coefficient model
  (`fit$lambda == Inf`) that predicts a constant probability for every
  observation -- independent of, and not fixed by, the `predict_xy` change
  above. `fit_xy` now always fits the full regularization path and the
  desired lambda is extracted via `s=` at predict time, matching how the
  path is intended to be used.

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
