# funcml 0.1.1

- Vendored canonical interpretability implementations from `vip`, `pdp`, `iml`, and a minimal internal `shapviz` layer.
- Replaced runtime `vip` and `pdp` dependencies with internal implementations while preserving formula-first `funcml` entrypoints.
- Added parity tests against sourced upstream reference code for permutation importance, PDP, ICE, ALE, Shapley values, and local surrogate explanations.
- Switched `local` / `local_model` to an `iml::LocalModel`-style sparse local surrogate using `glmnet` and Gower weighting.
