# funcml 0.7.0

- Consolidated `funcml` as a machine learning framework for R with stable S3 interfaces for fitting, prediction, evaluation, tuning, learner comparison, interpretation, and plug-in g-computation.
- Added richer resampling support through plain holdout, grouped cross-validation, and time-aware rolling splits.
- Added uncertainty summaries to `evaluate()` and `compare_learners()`, including fold-level standard errors and confidence intervals in summaries and plots.
- Added random-search tuning with `search = "random"` and `n_evals`, plus nested resampling support in `tune()` for outer-fold performance estimates of the model-selection procedure.
- Hardened the fit/predict contract with clearer errors for missing predictor columns and unseen factor levels, stricter probability-output normalization, and broader learner contract coverage across the registry.
- Added multiclass and weighted AUC support and clarified default evaluation behavior for binary versus multiclass classification.
- Added `list_learners()` as a learner capability catalog and improved package metadata, citation, and repository scaffolding for release and paper preparation.
- Removed the `catboost` learner backend from the registry and package metadata.
- Kept `lightgbm` as a separately installed learner engine.

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
