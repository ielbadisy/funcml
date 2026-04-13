## Test environments

* local Ubuntu 24.04.3 LTS, R 4.5.1
* win-builder (R-devel), submitted 2026-04-13, results pending
* win-builder (R-release), submitted 2026-04-13, results pending

## R CMD check results

* `R CMD check --as-cran` on `funcml_0.7.1.tar.gz`
  * 0 errors
  * 0 warnings
  * 1 note

## Notes

* The remaining local NOTE is:
  * `checking for future file timestamps ... NOTE`
  * `unable to verify current time`
* This appears to be environment-specific from the sandboxed/local check environment rather than package-specific.
