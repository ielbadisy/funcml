# Contributing to funcml

`funcml` is developed as a compact machine learning framework for R.
Contributions should preserve that scope: explicit inputs, stable S3 object
contracts, and clear learner capability boundaries.

## Development setup

Install the package and development dependencies in a clean R library before
making changes.

```r
install.packages(c("remotes", "devtools"))
devtools::install_deps(dependencies = TRUE)
```

## Expected checks

Run targeted tests for the files you change and finish with a package check.

```r
testthat::test_dir("tests/testthat")
```

```sh
R CMD check --no-manual .
```

If you change learner adapters or registry metadata, also run the learner audit
test at `tests/testthat/test-learner-audit-contract.R`.

## Design expectations

- Keep the public API explicit and internally consistent.
- Prefer centralized capability checks over adapter-specific silent fallbacks.
- Add or update tests with behavior changes.
- Keep documentation and examples aligned with the exported API.
