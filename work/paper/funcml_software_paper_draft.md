# funcml: A Machine Learning Framework for R

## Abstract
Applied machine learning in R often requires users to orchestrate multiple packages for model fitting, resampling, tuning, comparison, interpretation, and effect estimation. This can increase pipeline complexity and reduce reproducibility when different stages use different abstractions and object contracts. We present `funcml`, an R package that provides a compact S3-based interface for supervised learning and causal effect estimation. The framework unifies model training (`fit()`), prediction (`predict()`), evaluation under resampling (`evaluate()`), hyperparameter tuning (`tune()`), multi-learner comparison (`compare_learners()`), model interpretation (`interpret()`), and plug-in g-computation estimands (`estimate()`). `funcml` currently exposes 26 registered learners across classical statistical models, tree-based methods, boosting systems, neural networks, support vector machines, and ensemble meta-learners. To improve reliability, the package implements centralized capability checks and a learner-adapter contract tested across all registered learners. We describe the package architecture, design decisions, quality controls, and current benchmark-positioning assets for fair comparison with established ecosystems. `funcml` is positioned as a coherent and reproducible framework for tabular ML tasks in one package.

## 1. Introduction
R offers a rich machine learning ecosystem, but end-to-end applied analysis frequently requires substantial orchestration. Users may train models in one interface, tune in another, evaluate with custom wrappers, and implement interpretation or causal analysis through additional objects and conventions. While this flexibility is powerful, it can create friction in production-facing analysis and reproducible research.

`funcml` was developed to reduce this orchestration burden with a single API for the most common supervised ML lifecycle tasks. The package is designed for users who want a compact and consistent interface without sacrificing backend variety. Its goals are:

1. A stable, minimal API surface for end-to-end model analysis.
2. Consistent model object contracts across learners.
3. Native support for both predictive and causal estimands.
4. Built-in interpretation methods tied to the same fitted objects.
5. Reproducible behavior through explicit capability metadata and contract tests.

This manuscript presents `funcml` as a software systems contribution. The primary claim is not a new prediction algorithm, but a unified framework design that reduces interface fragmentation while maintaining broad practical model coverage.

## 2. Software Context and Positioning
Several mature frameworks in R support machine learning pipelines, including `tidymodels` and `mlr3`. Those ecosystems provide broad functionality through modular package families and extensive extension mechanisms. `funcml` is not intended to replace these ecosystems. Instead, it targets a different software objective: integrated, single-package execution of the full tabular ML lifecycle under one object model.

In this positioning:

- `funcml` prioritizes compact API integration and consistency.
- Established ecosystems remain broader in extension depth and ecosystem scale.
- Benchmarking should therefore focus on task-equivalent analysis completion and reliability, not only leaderboard-style performance.

## 3. Design Principles

### 3.1 Model specification interface
`funcml` uses R formulas as the primary model-specification interface. This keeps specifications concise and familiar, especially for users moving between statistical and ML codebases.

### 3.2 Unified S3 contracts
Core operations return stable S3 objects (`funcml_fit`, `funcml_eval`, `funcml_tune`, `funcml_compare`, and interpretation-specific classes). Downstream operations rely on these contracts, reducing ad hoc glue code.

### 3.3 Capability-aware execution
Learner metadata records support by task and prediction mode (for example, probability support and multiclass support). Centralized checks enforce capability constraints before and during execution.

### 3.4 End-to-end scope in one package
The package intentionally bundles fitting, resampling, tuning, interpretation, and causal effect estimation to support a coherent single-package analysis framework.

### 3.5 Reliability over silent fallback
When requested behavior is unsupported by a learner, `funcml` raises explicit errors rather than silently changing semantics.

## 4. System Architecture
`funcml` is built around a learner registry and adapter layer.

### 4.1 Learner registry
Each learner entry specifies:

- supported task types (regression/classification)
- prediction capabilities (class/probability)
- multiclass and importance support flags
- backend package information

This registry powers both execution checks and user-facing discovery via `list_learners()`.

### 4.2 Adapter contract
Adapters map framework-level operations to backend-specific fit/predict behavior. The contract enforces consistent return formats and class/probability semantics across diverse engines.

### 4.3 Shared encoding and prediction flow
Training and prediction share a consistent design-matrix pathway to avoid feature mismatch drift. Contract tests specifically guard against column ordering and encoding regressions.

### 4.4 Core framework functions
- `fit()`: train a learner with optional backend-specific `spec`.
- `predict()`: return response/class/prob outputs with centralized capability checks.
- `evaluate()`: resampling-based metrics with uncertainty summaries.
- `tune()`: search over parameter grids with metric-directed selection.
- `compare_learners()`: side-by-side learner assessment under common resampling.
- `interpret()`: native model-agnostic interpretation methods.
- `estimate()`: plug-in g-computation estimands for binary treatment settings.

## 5. Functional Coverage
Current implementation includes 26 learners and mixed task support.

Snapshot from `list_learners()` in the current code base:

- total learners: 26
- supports regression: 20
- supports classification: 25
- supports probabilities: 24
- supports multiclass: 19
- supports importance flag: 8

Representative learners include `glm`, `glmnet`, `rpart`, `ranger`, `randomForest`, `xgboost`, `lightgbm`, `catboost`, `kknn`, `nnet`, `e1071_svm`, `C50`, `lda`, `qda`, `naivebayes`, `ctree`, `cforest`, and ensemble strategies (`stacking`, `superlearner`).

## 6. Metrics, Evaluation, and Recent Reliability Updates
`funcml` supports regression and classification metrics including error-based metrics, probability metrics, and calibration diagnostics.

Recent updates in the current development line include:

1. multiclass AUC support using one-vs-rest aggregation (`auc(..., average = "macro")`)
2. weighted multiclass AUC (`auc(..., average = "weighted")` and `auc_weighted()`)
3. explicit classification-only enforcement for AUC metrics in regression contexts
4. clarified default evaluation behavior by separating multiclass defaults from binary-only calibration metrics

These changes were accompanied by targeted tests in the core test suite.

## 7. Interpretation and Causal Estimation
`interpret()` provides model-agnostic tooling including permutation importance, PDP, ICE, ALE, SHAP approximations, surrogate models, and calibration-related diagnostics.

`estimate()` provides plug-in g-computation estimands for binary treatment use cases, including ATE, ATT, CATE, and IATE.

A current architectural boundary is that interpretation methods operate on `funcml_fit` objects, while causal estimands are returned through a separate estimand pathway. Bridging treatment-effect-specific interpretation remains future work.

## 8. Software Quality and Testing
`funcml` includes a learner-contract audit harness and test coverage focused on adapter consistency, supported/unsupported mode handling, and cross-learner behavior guarantees.

Quality controls include:

- centralized enforcement of unsupported multiclass and probability modes
- adapter-level regression tests for known backend failure modes
- checks for probability normalization and class label consistency
- reproducible resampling and summary pipelines

The package has undergone iterative remediation to stabilize multiclass probability reconstruction, eliminate backend-specific artifact leakage, and harden test behavior under package-check contexts.

## 9. Benchmark-Positioning Assets
To support fair software benchmarking, we prepared a task-equivalence learner mapping across `funcml`, `tidymodels`, and `mlr3` in:

- `work/bench/learner_intersection.csv`
- `work/bench/validate_learner_intersection.R`
- `work/bench/learner_intersection_status.csv`

The mapping uses two tiers:

- Tier 1: strict common learners for primary comparisons.
- Tier 2: extension-dependent overlap for supplementary comparisons.

Current local validation snapshot:

- total mapped entries: 24
- available intersection: 19/24
- Tier 1 availability: 14/17
- Tier 2 availability: 5/7

Missing entries in this environment are due to local `tidymodels` extension availability, not `funcml` coverage for those entries.

## 10. Reproducibility Plan for Publication
For software-paper reproducibility, we recommend including:

1. fixed benchmark scripts with explicit seeds
2. session metadata (`sessionInfo()`) for all benchmark runs
3. version-locked dependency manifests
4. machine-readable benchmark outputs (CSV/JSON)
5. release-tagged artifact references

`funcml` already contains a suitable structure under `work/` for this packaging approach.

## 11. Limitations
Current limitations include:

- no native survival task API in current public surface
- no direct interpretation bridge for causal estimand outputs
- extension-dependent parity with external ecosystems for some optional learners
- focus on tabular supervised learning tasks rather than broader modality support

These are software-scope limitations, not hidden implementation defects.

## 12. Future Work
Planned and recommended next steps:

1. causal interpretation bridge (feature attribution for treatment-effect predictions)
2. optional survival-task support
3. benchmark automation outputs for publication tables and figures
4. explicit environment bootstrap scripts for cross-framework parity runs
5. continued contract testing for new backends and adapters

## 13. Conclusion
`funcml` provides a coherent software framework for end-to-end tabular machine learning in R. Its contribution is integration quality: one package and one contract model for fitting, prediction, evaluation, tuning, comparison, interpretation, and causal estimand estimation. The framework is already broad enough for software-paper benchmarking on common tabular tasks and is supported by explicit learner capability metadata and contract-driven testing. In this form, `funcml` is suitable for a software-focused preprint, with clear scope, current strengths, and actionable future extensions.

## Acknowledgments
Development benefited from iterative adapter auditing and reproducibility hardening across multiple backend engines and test harness refinements.

## References (software)
- `funcml` package repository and documentation.
- `tidymodels` package ecosystem documentation.
- `mlr3` and associated ecosystem documentation.
