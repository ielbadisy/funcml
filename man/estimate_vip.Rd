% Generated manually for funcml
\name{estimate_vip}
\alias{estimate_vip}
\title{Effect-targeted permutation importance for causal estimands.}
\usage{
estimate_vip(
  object,
  data = NULL,
  newdata = NULL,
  variables = NULL,
  perturb = c("permute"),
  mode = c("evaluate", "refit"),
  measure = c("absolute", "squared"),
  relative = FALSE,
  nsim = 30,
  keep = TRUE,
  seed = NULL,
  ...
)
}
\arguments{
\item{object}{A \code{funcml_estimand} object returned by \code{estimate()}.}

\item{data}{Optional training/reference data used to fit the outcome model.
Defaults to the data stored on \code{object}.}

\item{newdata}{Optional target data for \code{object$estimand = "CATE"} or
\code{"IATE"}. Defaults to the target data stored on \code{object}.}

\item{variables}{Optional subset of covariates to perturb.}

\item{perturb}{Perturbation scheme. Currently only \code{"permute"} is supported.}

\item{mode}{One of \code{"evaluate"} or \code{"refit"}.}

\item{measure}{Discrepancy measure: \code{"absolute"} or \code{"squared"}.}

\item{relative}{Should importance be scaled by the baseline effect magnitude?}

\item{nsim}{Number of perturbation repetitions.}

\item{keep}{Keep the per-repetition raw scores.}

\item{seed}{Optional seed.}

\item{...}{Additional arguments passed to \code{fit()} when \code{mode = "refit"}.}
}
\value{
A \code{funcml_estimand_vip} object.
}
\description{
Computes effect-targeted permutation importance by perturbing one covariate
at a time and measuring how much the estimated causal target changes. Scalar
estimands such as \code{"ATE"}, \code{"ATT"}, and \code{"CATE"} are compared
through absolute or squared changes in the estimated contrast. In this
package, \code{"CATE"} refers to the target-average effect over the rows in
\code{newdata}, so \code{estimate_vip()} for \code{"CATE"} measures importance
for that target-average contrast. For \code{"IATE"}, the discrepancy is
aggregated over row-wise individualized effects and is the more direct
heterogeneity-aligned importance target.
}
