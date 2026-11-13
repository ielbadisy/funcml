#' Deprecated functions
#'
#' These functions were renamed to glued lowercase names (no underscores). The
#' old names still work but are deprecated and will be removed in a future
#' release.
#'
#' @param ... Arguments passed to the new function.
#' @name funcml-deprecated
#' @keywords internal
NULL

#' @rdname funcml-deprecated
#' @export
auc_ci <- function(...) {
  .Deprecated("aucci")
  aucci(...)
}

#' @rdname funcml-deprecated
#' @export
auc_weighted <- function(...) {
  .Deprecated("aucweighted")
  aucweighted(...)
}

#' @rdname funcml-deprecated
#' @export
balanced_accuracy <- function(...) {
  .Deprecated("balancedaccuracy")
  balancedaccuracy(...)
}

#' @rdname funcml-deprecated
#' @export
calibration_curve <- function(...) {
  .Deprecated("calibrationcurve")
  calibrationcurve(...)
}

#' @rdname funcml-deprecated
#' @export
default_tune_grid <- function(...) {
  .Deprecated("defaulttunegrid")
  defaulttunegrid(...)
}

#' @rdname funcml-deprecated
#' @export
group_cv <- function(...) {
  .Deprecated("groupcv")
  groupcv(...)
}

#' @rdname funcml-deprecated
#' @export
list_interpretability_methods <- function(...) {
  .Deprecated("listinterpretabilitymethods")
  listinterpretabilitymethods(...)
}

#' @rdname funcml-deprecated
#' @export
list_learners <- function(...) {
  .Deprecated("listlearners")
  listlearners(...)
}

#' @rdname funcml-deprecated
#' @export
list_metrics <- function(...) {
  .Deprecated("listmetrics")
  listmetrics(...)
}

#' @rdname funcml-deprecated
#' @export
list_tunable_learners <- function(...) {
  .Deprecated("listtunablelearners")
  listtunablelearners(...)
}

#' @rdname funcml-deprecated
#' @export
roc_curve <- function(...) {
  .Deprecated("roccurve")
  roccurve(...)
}

#' @rdname funcml-deprecated
#' @export
theme_funcml <- function(...) {
  .Deprecated("themefuncml")
  themefuncml(...)
}

#' @rdname funcml-deprecated
#' @export
time_cv <- function(...) {
  .Deprecated("timecv")
  timecv(...)
}
