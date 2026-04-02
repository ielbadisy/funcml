# `funcml` Learner Adapter Contract

## Purpose

This document defines the concrete contract used to audit every learner adapter registered in `funcml`.

The public entry points are:

- `fit()` in [R/fit.R](/home/imad-el-badisy/Desktop/BIOSTAT/PROJECTS/project_funcml/funcml-package/R/fit.R)
- `predict.funcml_fit()` in [R/fit.R](/home/imad-el-badisy/Desktop/BIOSTAT/PROJECTS/project_funcml/funcml-package/R/fit.R)
- `interpret()` in [R/interpret.R](/home/imad-el-badisy/Desktop/BIOSTAT/PROJECTS/project_funcml/funcml-package/R/interpret.R)

The learner registry and adapter implementations live in [R/registry.R](/home/imad-el-badisy/Desktop/BIOSTAT/PROJECTS/project_funcml/funcml-package/R/registry.R), and shared encoding and prediction normalization live in [R/utils.R](/home/imad-el-badisy/Desktop/BIOSTAT/PROJECTS/project_funcml/funcml-package/R/utils.R).

## Terminology

- `raw prediction` means the primary non-probability prediction path.
- For classification, the current public API spells this as `type = "class"`.
- For regression, the current public API spells this as `type = "response"`.
- `probability prediction` means `type = "prob"` for classification only.

`funcml` does not currently expose a literal `type = "raw"` token. This audit therefore evaluates the semantic raw path through `type = "class"` for classification and `type = "response"` for regression.

## Registry Contract

Each learner entry in the registry must provide:

- a stable learner id
- a backend package name
- `tasks`
- `defaults`
- `supports`
- `fit_xy()`
- `predict_xy()`

Optional adapter methods, such as `importance()`, must only be advertised when they are callable through the public workflow.

The `supports` field is part of the user-facing contract. If it claims `prob = TRUE` or `multiclass = TRUE`, the adapter must pass the corresponding audit checks. If the backend cannot deliver that mode correctly, the registry must not claim it.

## Fit Contract

For every supported learner-task combination:

- `fit()` must accept valid formula/data input and train successfully.
- The returned `funcml_fit` object must preserve:
- the original formula
- encoded design-matrix metadata
- the inferred task
- the stored training outcome levels for classification
- the adapter state needed for later prediction and interpretation

For unsupported configurations:

- failure must happen at fit time or at the first relevant prediction call
- the error must be explicit enough to identify the unsupported mode
- unsupported binary versus multiclass behavior must not be left implicit

## Outcome Metadata Contract

For classification fits:

- training outcome levels must be stored explicitly in `fit$levels`
- the stored order is authoritative
- all later raw and probability predictions must align to this order

For regression fits:

- `fit$levels` must be `NULL`
- predictions must remain numeric

## Raw Prediction Contract

For classification:

- `predict(fit, newdata, type = "class")` must return one label per row
- the result must be a factor
- the factor levels must match `fit$levels`
- every predicted label must belong to `fit$levels`
- the number of predictions must equal `nrow(newdata)`

For regression:

- `predict(fit, newdata, type = "response")` must return one finite numeric value per row

If the backend returns a probability matrix for a raw request, `funcml` may reconstruct class labels from the maximum-probability class, but the final public result must still satisfy the raw contract above.

## Probability Prediction Contract

For classification learners that advertise probability support:

- `predict(fit, newdata, type = "prob")` must return a numeric matrix or data frame
- rows must equal `nrow(newdata)`
- columns must equal the number of stored class levels
- column names must exactly match `fit$levels`
- values must be finite
- values must lie in `[0, 1]`
- each row must sum to 1 within tolerance after any documented normalization

This contract applies to both binary and multiclass classification.

If a learner does not advertise probability support, `predict(..., type = "prob")` must fail clearly and intentionally.

## Level-Handling Contract

For classification:

- non-alphabetical training level order must be preserved
- probability outputs must be reordered to `fit$levels` before returning
- raw predictions must use the same level set and order
- the class implied by the maximum predicted probability should match the raw prediction path unless the backend has a documented reason not to

This is a core correctness requirement for multiclass support.

## Error Contract

Unsupported combinations must:

- fail early
- fail clearly
- not produce malformed downstream objects
- not silently coerce to a different task or prediction mode

The audit treats vague downstream crashes as contract failures, even if the backend eventually errors.

## Interpretation Contract

`interpret()` is part of the learner contract because it depends on prediction semantics.

For supported interpretation paths:

- regression learners must support at least a raw prediction path used by permutation importance
- classification learners must support raw/class interpretation when metrics such as accuracy are used
- learners that advertise probability support must also work with probability-based interpretation paths such as permutation importance with `metric = "logloss"`

If a learner cannot support the required prediction type:

- the failure must be explicit
- the limitation must be reflected in the registry and documentation

## Audit Status Definitions

The audit uses these learner-level status labels:

- `working`: all advertised combinations validated
- `working with caveats`: core contract passes but warnings or narrower caveats remain
- `broken`: at least one advertised combination fails
- `unsupported by design`: the registry intentionally does not claim that mode
- `overclaimed`: the registry claims a mode that fails the contract

## Structural Expectations

To keep the learner layer stable package-wide:

- support claims must be enforced centrally, not only by individual adapters
- raw and probability outputs must be normalized through shared helpers
- interpretation must rely only on audited prediction paths
- every confirmed bug or overclaim must gain a deterministic regression test
