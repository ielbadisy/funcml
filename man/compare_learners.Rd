% Generated manually for funcml
\name{compare_learners}
\alias{compare_learners}
\title{Compare multiple learners with optional tuning}
\usage{
compare_learners(
  data,
  formula,
  models,
  specs = NULL,
  resampling = cv(5),
  metrics = NULL,
  type = NULL,
  seed = NULL,
  tune = FALSE,
  grids = NULL,
  metric = NULL,
  ...
)
}
\arguments{
\item{data}{Data frame.}

\item{formula}{Model formula.}

\item{models}{Character vector of learner ids.}

\item{specs}{Optional named list of fixed specs per learner.}

\item{resampling}{Resampling object from \code{cv()}.}

\item{metrics}{Character vector of metrics to report. When \code{tune = TRUE},
these are computed for each learner's tuned best configuration.}

\item{type}{Prediction type override.}

\item{seed}{Optional seed.}

\item{tune}{Logical; if \code{TRUE}, run \code{\link[=tune]{tune()}} for each learner before comparing.}

\item{grids}{Optional tuning grids. Supply either a single data frame to reuse
across learners or a named list of data frames keyed by learner id.}

\item{metric}{Optimization metric used when \code{tune = TRUE}.}

\item{...}{Additional arguments passed to \code{\link[=evaluate]{evaluate()}} or \code{\link[=tune]{tune()}} / \code{\link[=fit]{fit()}}.}
}
\value{
A \code{funcml_compare} object.
}
\description{
Compares several learners side by side using a shared resampling scheme. By
default it evaluates each learner directly. When \code{tune = TRUE}, it tunes
each learner first, then evaluates the tuned best configuration on the requested
metrics so the results are comparable across models.
}
\examples{
\dontrun{
cmp <- compare_learners(
  mtcars,
  mpg ~ wt + hp + qsec,
  models = c("glm", "rpart", "xgboost"),
  metrics = c("rmse", "mae"),
  resampling = cv(v = 5, seed = 42)
)

cmp_tuned <- compare_learners(
  mtcars,
  mpg ~ wt + hp + qsec,
  models = c("rpart", "xgboost"),
  tune = TRUE,
  metric = "rmse",
  metrics = c("rmse", "mae"),
  grids = list(
    rpart = expand.grid(cp = c(0.001, 0.01), minsplit = c(5, 10)),
    xgboost = expand.grid(max_depth = c(2, 3), eta = c(0.05, 0.1), nrounds = c(20, 40))
  ),
  resampling = cv(v = 5, seed = 42),
  subsample = 1,
  colsample_bytree = 1
)
}
}
