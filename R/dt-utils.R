# Internal data.table helpers.
#
# funcml's public return objects (`$folds`, `$results`, `$curves`, ...) are
# documented and tested as plain data.frames, and downstream code throughout
# the package relies on base-R `[` / `[<-` semantics on them. `.rbind_dt()`
# swaps the row-accumulation step (previously `do.call(rbind, list_of_dfs)`,
# which re-copies the growing frame on every call) for `data.table::rbindlist()`,
# then converts back to a plain data.frame so every caller keeps working
# unchanged.

.rbind_dt <- function(x) {
  x <- Filter(Negate(is.null), x)
  if (!length(x)) {
    return(data.frame())
  }
  as.data.frame(data.table::rbindlist(x, fill = TRUE, use.names = TRUE))
}
