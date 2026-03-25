% Generated manually for funcml
\name{estimate}
\alias{estimate}
\title{Causal effect estimation via plug-in g-computation.}
\usage{
estimate(
  data,
  formula,
  model = NULL,
  treatment = NULL,
  estimand = c("ATE", "ATT", "CATE", "IATE"),
  newdata = NULL,
  treatment_level = NULL,
  control_level = NULL,
  spec = NULL,
  type = NULL,
  interval = c("normal", "bootstrap"),
  conf_level = 0.95,
  n_boot = 200,
  seed = NULL,
  fit = NULL,
  ...
)
}
\arguments{
\item{data}{Data frame.}

\item{formula}{Outcome model formula. The first term on the right-hand side
is treated as the treatment variable unless \code{treatment} is supplied.}

\item{model}{Learner id (ignored if \code{fit} supplied).}

\item{treatment}{Optional treatment variable name.}

\item{estimand}{One of \code{"ATE"}, \code{"ATT"}, \code{"CATE"}, or \code{"IATE"}.}

\item{newdata}{Optional target population for \code{estimand = "CATE"} or
\code{"IATE"}.}

\item{treatment_level}{Optional treated level for binary treatment.}

\item{control_level}{Optional control level for binary treatment.}

\item{spec}{Hyperparameter list passed to \code{fit()}.}

\item{type}{Prediction type override for the outcome model.}

\item{interval}{Interval method: \code{"normal"} or \code{"bootstrap"}.}

\item{conf_level}{Confidence level for uncertainty intervals.}

\item{n_boot}{Number of bootstrap resamples used when \code{interval = "bootstrap"}.}

\item{seed}{Optional seed.}

\item{fit}{Optional preconfigured \code{funcml_fit} object.}

\item{...}{Passed to \code{fit()}.}
}
\value{
A \code{funcml_estimand} object.
}
\description{
Estimates simple causal targets with plug-in g-computation from a fitted
outcome model. The current implementation is intentionally narrow: binary
treatment only, no hidden-confounding adjustment beyond supplied covariates,
and outcome-model-based estimation. \code{"IATE"} returns row-wise individualized
treatment effects rather than a single aggregated contrast.
}
