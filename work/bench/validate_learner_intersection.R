#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
map_path <- if (length(args) >= 1) args[[1]] else "work/bench/learner_intersection.csv"
out_path <- if (length(args) >= 2) args[[2]] else "work/bench/learner_intersection_status.csv"

if (!file.exists(map_path)) {
  stop("Mapping file not found: ", map_path, call. = FALSE)
}

map <- utils::read.csv(map_path, stringsAsFactors = FALSE)
required_cols <- c(
  "tier", "entry_id", "task", "funcml_learner", "tidymodels_model",
  "tidymodels_engine", "tidymodels_extension_pkg", "mlr3_learner",
  "mlr3_extension_pkg", "intersection_note"
)
missing_cols <- setdiff(required_cols, names(map))
if (length(missing_cols)) {
  stop("Missing columns in mapping file: ", paste(missing_cols, collapse = ", "), call. = FALSE)
}

pkg_installed <- function(pkg) {
  if (is.na(pkg) || !nzchar(pkg)) return(TRUE)
  requireNamespace(pkg, quietly = TRUE)
}

all_pkgs_installed <- function(pkg_str) {
  if (is.na(pkg_str) || !nzchar(pkg_str)) return(TRUE)
  pkgs <- trimws(strsplit(pkg_str, "\\|", fixed = FALSE)[[1]])
  all(vapply(pkgs, pkg_installed, logical(1)))
}

mode_from_task <- function(task) {
  if (identical(task, "regression")) return("regression")
  if (identical(task, "classification")) return("classification")
  return(NA_character_)
}

funcml_ids <- character()
funcml_ok <- FALSE
if (requireNamespace("pkgload", quietly = TRUE) && file.exists("DESCRIPTION")) {
  suppressWarnings(try(pkgload::load_all(".", quiet = TRUE, export_all = FALSE), silent = TRUE))
}
if ("package:funcml" %in% search()) {
  funcml_ok <- exists("list_learners", mode = "function")
  if (funcml_ok) {
    funcml_ids <- tryCatch(list_learners()$learner, error = function(e) character())
  }
}
if (!funcml_ok && requireNamespace("funcml", quietly = TRUE)) {
  funcml_ok <- TRUE
  funcml_ids <- tryCatch(funcml::list_learners()$learner, error = function(e) character())
}

parsnip_ok <- requireNamespace("parsnip", quietly = TRUE)

mlr3_ok <- requireNamespace("mlr3", quietly = TRUE)
mlr3learners_ok <- requireNamespace("mlr3learners", quietly = TRUE)
mlr3extra_ok <- requireNamespace("mlr3extralearners", quietly = TRUE)
mlr3_keys <- character()
if (mlr3_ok && mlr3learners_ok) {
  suppressWarnings(invisible(try(loadNamespace("mlr3learners"), silent = TRUE)))
}
if (mlr3_ok && mlr3extra_ok) {
  suppressWarnings(invisible(try(loadNamespace("mlr3extralearners"), silent = TRUE)))
}
if (mlr3_ok) {
  mlr3_keys <- tryCatch(mlr3::mlr_learners$keys(), error = function(e) character())
}

check_tidymodels <- function(model, engine, task, ext_pkgs) {
  if (!parsnip_ok) return(FALSE)
  if (!all_pkgs_installed(ext_pkgs)) return(FALSE)

  engines_tbl <- tryCatch(parsnip::show_engines(model), error = function(e) NULL)
  if (is.null(engines_tbl) || !nrow(engines_tbl)) return(FALSE)

  mode <- mode_from_task(task)
  any(engines_tbl$engine == engine & engines_tbl$mode == mode)
}

check_mlr3 <- function(learner_id, ext_pkgs) {
  if (!mlr3_ok) return(FALSE)
  if (!all_pkgs_installed(ext_pkgs)) return(FALSE)
  learner_id %in% mlr3_keys
}

status <- map
status$funcml_available <- FALSE
status$tidymodels_available <- FALSE
status$mlr3_available <- FALSE
status$intersection_available <- FALSE

for (i in seq_len(nrow(status))) {
  status$funcml_available[i] <- funcml_ok && status$funcml_learner[i] %in% funcml_ids
  status$tidymodels_available[i] <- check_tidymodels(
    model = status$tidymodels_model[i],
    engine = status$tidymodels_engine[i],
    task = status$task[i],
    ext_pkgs = status$tidymodels_extension_pkg[i]
  )
  status$mlr3_available[i] <- check_mlr3(
    learner_id = status$mlr3_learner[i],
    ext_pkgs = status$mlr3_extension_pkg[i]
  )
  status$intersection_available[i] <-
    status$funcml_available[i] && status$tidymodels_available[i] && status$mlr3_available[i]
}

utils::write.csv(status, out_path, row.names = FALSE)

cat("Wrote:", out_path, "\n")
cat("Rows:", nrow(status), "\n")
cat("Intersection available:", sum(status$intersection_available), "/", nrow(status), "\n")
cat("Tier 1 available:", sum(status$intersection_available & status$tier == 1), "/", sum(status$tier == 1), "\n")
cat("Tier 2 available:", sum(status$intersection_available & status$tier == 2), "/", sum(status$tier == 2), "\n")

if (any(!status$intersection_available)) {
  cat("\nMissing entries:\n")
  print(status[!status$intersection_available, c(
    "entry_id", "funcml_available", "tidymodels_available", "mlr3_available",
    "tidymodels_extension_pkg", "mlr3_extension_pkg"
  )], row.names = FALSE)
}
