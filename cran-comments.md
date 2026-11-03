## Test environments

* local Ubuntu 24.04.3 LTS, R 4.5.1

## R CMD check results

* `R CMD check --as-cran funcml_0.9.6.tar.gz`
  (with `_R_CHECK_CRAN_INCOMING_REMOTE_=TRUE`)
  * 0 errors
  * 0 warnings
  * 0 notes

## Notes

* This is an update. The current CRAN version is 0.9.0.
* `checking package dependencies ... INFO`
  * `Imports includes 25 non-default packages.`
  * This is deliberate: every advertised learner's backend package (e.g.
    `xgboost`, `ranger`, `densemlp`, `fastgbm`) is in `Imports` so that a
    standard installation always has every learner listed by `learners()`
    available, and `fit()` cannot fail at call time with a missing-package
    error for a registered model. All of these packages are on CRAN.
* `torch` is no longer a dependency: the `mlp` learner now runs on the
  `densemlp` engine (C++, RcppArmadillo).
* Summary of changes since 0.9.0 is in `NEWS.md`.
