# funcml

`funcml` is a formula-first machine learning package for fitting, evaluating,
tuning, and interpreting models with a compact S3 interface.

It also includes native ensemble learner IDs through `fit(..., model = "stacking")`
and `fit(..., model = "superlearner")`.

## Native interpretability methods

- `interpret(..., method = "vip")`
- `interpret(..., method = "permute")`
- `interpret(..., method = "pdp")`
- `interpret(..., method = "ice")`
- `interpret(..., method = "ale")`
- `interpret(..., method = "local")`
- `interpret(..., method = "lime")`
- `interpret(..., method = "local_model")`
- `interpret(..., method = "shap")`
- `interpret(..., method = "profile")`
- `interpret(..., method = "ceteris_paribus")`
- `interpret(..., method = "interaction")`
- `interpret(..., method = "breakdown")`
- `interpret(..., method = "surrogate")`

These methods are implemented natively in the package without vendoring source
code from upstream interpretability libraries.
