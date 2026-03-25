\name{interpret}
\alias{interpret}
\title{Model-agnostic interpretation (global + local).}
\usage{
interpret(
  fit,
  data,
  formula = fit$formula,
  method = c("vip", "permute", "pdp", "ice", "ale", "local", "lime",
    "shap", "local_model", "interaction", "surrogate",
    "profile", "ceteris_paribus"),
  features = NULL,
  type = NULL,
  metric = NULL,
  importance_type = c("permute", "model", "auto"),
  compare = c("difference", "ratio"),
  keep = TRUE,
  k = NULL,
  gower_power = NULL,
  class_level = NULL,
  pos_level = NULL,
  newdata = NULL,
  nsim = NULL,
  nsamples = NULL,
  grid = NULL,
  seed = NULL,
  ...
)
}
\arguments{
\item{fit}{A \code{funcml_fit} object.}

\item{data}{Reference data (typically training set).}

\item{formula}{Optional formula (defaults to \code{fit$formula}).}

\item{method}{One of \code{"vip"}, \code{"permute"}, \code{"pdp"}, \code{"ice"},
\code{"ale"}, \code{"local"}, \code{"lime"}, \code{"shap"},
\code{"local_model"}, \code{"interaction"}, \code{"surrogate"},
\code{"profile"}, or \code{"ceteris_paribus"}.}

\item{features}{Optional subset of features; defaults to all predictors.}

\item{type}{Prediction scale: regression -> \code{"response"}; classification -> \code{"prob"} or \code{"class"}.}

\item{metric}{Loss/score for importance (reg: rmse/mae/rsq; cls: accuracy/logloss/brier/auc).}

\item{importance_type}{Importance engine for \code{method = "vip"}: \code{"permute"}, \code{"model"}, or \code{"auto"}.}

\item{compare}{How to compare baseline and perturbed performance for importance: \code{"difference"} or \code{"ratio"}.}

\item{keep}{Keep per-repetition raw importance scores when \code{nsim > 1}.}

\item{k}{Sparsity target for local surrogate fits (\code{method = "local"}, \code{"local_model"}, or \code{"lime"}).}

\item{gower_power}{Exponent applied to native similarity weights when constructing the local neighborhood.}

\item{class_level}{Target class for multiclass/local probability explanations.}

\item{pos_level}{Alias for binary positive class.}

\item{newdata}{Single-row data frame for local/SHAP explanations; defaults to first row of \code{data}.}

\item{nsim}{Number of Monte Carlo simulations (importance/SHAP) or repetitions.}

\item{nsamples}{Row subsample for speed (reference/background set).}

\item{grid}{Optional list of grids per feature for PDP/ICE/ALE.}

\item{seed}{Optional seed for determinism.}

\item{...}{Additional method-specific arguments.}
}
\description{
Implements native permutation VI, PDP/ICE/ALE, SHAP approximations, local
surrogate explanations, interaction strength, and global surrogate models
without vendoring external package source code.
}
