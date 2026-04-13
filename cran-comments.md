## Test environments

* local Ubuntu 24.04.3 LTS, R 4.5.1

## R CMD check results

* `R CMD check --as-cran --no-manual funcml_0.7.1.tar.gz`
  * 0 errors
  * 0 warnings
  * 2 notes

## Notes

* `New submission`
  * This is the first CRAN submission of `funcml`.

* `Imports includes 23 non-default packages. Importing from so many packages makes the package vulnerable to any of them becoming unavailable. Move as many as possible to Suggests and use conditionally.`
  * `funcml` is a unified machine learning framework that exposes a broad learner registry and a single stable API for fitting, evaluation, tuning, interpretation, and causal estimation. The imported packages correspond to the supported learner backends and plotting/explanation infrastructure exposed by the package interface.
  * We reviewed the dependency set and kept only packages that are required for advertised runtime functionality. Optional authoring and test tooling remains in `Suggests`.

* `checking for future file timestamps ... NOTE`
  * `unable to verify current time`
  * This note is environment-specific from the local check host and not package-specific.
