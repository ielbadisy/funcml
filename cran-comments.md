## Test environments

* local Ubuntu 24.04.3 LTS, R 4.5.1

## R CMD check results

* `R CMD check --as-cran funcml_0.8.8.tar.gz`
  * 0 errors
  * 0 warnings
  * 0 notes

## Notes

* This is a resubmission. The previous CRAN version was 0.7.1.
* `checking package dependencies ... INFO`
  * `Imports includes 25 non-default packages.`
  * This is deliberate: every advertised learner's backend package (e.g.
    `xgboost`, `ranger`, `torch`, `densemlp`) was moved from `Suggests` to
    `Imports` so that a standard installation always has every learner
    listed by `learners()` available, and `fit()` cannot fail at call time
    with a missing-package error for a registered model. All of these
    packages are already on CRAN.
* Summary of changes since 0.7.1 (full detail in `NEWS.md`): added the
  `densemlp` learner; added `roc_curve()`/`auc_ci()` (pROC-backed);
  added decision curve analysis (`dca()`, `interpret(method = "dca")`);
  removed the `shapviz` runtime dependency in favor of native ggplot2
  SHAP plots; reworked the plotting theme; migrated internal row
  aggregation to `data.table`; parallelized SHAP computation via
  `functionals`; various plotting and printing fixes.
