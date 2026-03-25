# funcml Plot Audit

This audit treats established package outputs as the behavioral specification for
plot semantics and figure grammar. The aim is recognizability first, package
styling second.

## Inventory

| Source file | Function | Method | Status | Current issues / notes | Target reference | Action |
| --- | --- | --- | --- | --- | --- | --- |
| `R/interpret.R` | `plot.funcml_permute` | Permutation importance | rewritten | now uses vip-style horizontal point + interval grammar with explicit metric label | `vip` | keep |
| `R/interpret.R` | `plot.funcml_pdp` | Partial dependence | rewritten | now uses standard line plot with support rug and precise dependence label | `pdp` | keep |
| `R/interpret.R` | `plot.funcml_ice` | ICE | rewritten | thin individual curves plus average overlay, centered title when applicable | `pdp` / `iml` | keep |
| `R/interpret.R` | `plot.funcml_ale` | ALE | rewritten | centered zero line, support rug, prediction-scale axis label | ALE conventions / `iml` | keep |
| `R/interpret.R` | `plot.funcml_iml_local_model` | Local surrogate contribution plot | acceptable but secondary | generic local surrogate contribution display; should remain secondary to SHAP / breakdown | `iml` local surrogate conventions | keep secondary |
| `R/interpret.R` | `plot.funcml_shap` | Approximate SHAP | rewritten | now distinguishes local waterfall vs multi-observation summary/importance; labeled as approximate SHAP | `fastshap`, SHAP conventions | keep |
| `R/interpret.R` | `plot.funcml_breakdown` | Breakdown | rewritten | now standard sequential path with endpoint labels outside bars | `DALEX` / `iml` breakdown style | keep |
| `R/interpret.R` | `plot.funcml_surrogate` | Surrogate fidelity | rewritten | simple scatter vs identity line, unobtrusive fidelity subtitle | diagnostic fidelity plot conventions | keep |
| `R/interpret.R` | `plot.funcml_interaction` | Interaction strength | acceptable | simple ranked dot plot; semantics depend on Friedman H approximation | `iml` interaction overview | refine later |
| `R/evaluate.R` | `plot.funcml_eval` | Resampling performance | acceptable but nonstandard | boxplot grammar acceptable, but metric-specific faceting/order can still improve | standard benchmarking plots | refine later |
| `R/tune.R` | `plot.funcml_tune` | Tuning trace | acceptable but nonstandard | uses config index instead of parameter labels; serviceable but not ideal | tuning/benchmark traces | refine later |
| `R/compare.R` | `plot.funcml_compare` | Learner comparison | acceptable | already close to standard dot + interval benchmarking grammar | benchmarking plots | minor polish later |
| `R/estimate.R` | `plot.funcml_estimand` | Effect distribution | acceptable | not an interpretability plot; histogram grammar is standard enough | effect distribution diagnostics | leave |

## Reference mapping

| funcml plot | target standard | reference package | action |
| --- | --- | --- | --- |
| permutation importance | horizontal point + interval importance plot | `vip` | rewritten |
| PDP | line PDP with support rug | `pdp` | rewritten |
| ICE | thin ICE curves + mean overlay | `pdp` / `iml` | rewritten |
| ALE | centered ALE with zero line + support rug | `iml` / ALE literature | rewritten |
| SHAP summary | beeswarm-like SHAP summary | `fastshap` / SHAP conventions | rewritten |
| SHAP waterfall | local additive waterfall | `fastshap` / SHAP conventions | rewritten |
| breakdown | sequential local attribution path | `DALEX` / `iml` style | rewritten |
| local surrogate | secondary contribution plot | `iml` local surrogate conventions | retained as secondary |
| surrogate fidelity | prediction vs surrogate prediction | standard diagnostic plot | rewritten |

## Immediate follow-up

1. Add side-by-side figure snapshots for the rewritten methods under `dev/plot_validation.R`.
2. If `iml`/`DALEX` become available locally, extend the validation script to compare breakdown and ALE outputs directly.
3. Revisit `plot.funcml_tune()` so configurations can be labeled by actual hyperparameters rather than a raw index.
