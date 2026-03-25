pkg_available <- function(pkg) requireNamespace(pkg, quietly = TRUE)

dir.create("dev/plot_validation", showWarnings = FALSE, recursive = TRUE)

pkgload::load_all(".", quiet = TRUE)
library(ggplot2)

set.seed(42)
dat <- transform(
  mtcars,
  am = factor(am, levels = c(0, 1), labels = c("auto", "manual"))
)

fit_obj <- fit(mpg ~ wt + hp + qsec + drat, data = dat, model = "glm")

save_plot <- function(filename, plot, width = 8, height = 5) {
  ggplot2::ggsave(file.path("dev/plot_validation", filename), plot, width = width, height = height, dpi = 160)
}

safe_step <- function(label, expr) {
  tryCatch(
    force(expr),
    error = function(e) {
      message(sprintf("[plot_validation] %s failed: %s", label, conditionMessage(e)))
      NULL
    }
  )
}

# funcml reference plots
safe_step("funcml_permutation", save_plot(
  "funcml_permutation.png",
  plot(interpret(fit_obj, dat, method = "permute", metric = "rmse", nsim = 10, seed = 1))
))
safe_step("funcml_pdp", save_plot(
  "funcml_pdp.png",
  plot(interpret(fit_obj, dat, method = "pdp", features = c("wt", "hp"), nsamples = 32))
))
safe_step("funcml_ice", save_plot(
  "funcml_ice.png",
  plot(interpret(fit_obj, dat, method = "ice", features = "wt", nsamples = 20))
))
safe_step("funcml_ale", save_plot(
  "funcml_ale.png",
  plot(interpret(fit_obj, dat, method = "ale", features = c("wt", "hp"), nsamples = 32))
))
safe_step("funcml_breakdown", save_plot(
  "funcml_breakdown.png",
  plot(interpret(fit_obj, dat, method = "breakdown", newdata = dat[1, , drop = FALSE], nsamples = 32))
))
safe_step("funcml_shap_waterfall", save_plot(
  "funcml_shap_waterfall.png",
  plot(interpret(fit_obj, dat, method = "shap", newdata = dat[1, , drop = FALSE], nsim = 40, nsamples = 32), kind = "waterfall")
))
safe_step("funcml_shap_summary", save_plot(
  "funcml_shap_summary.png",
  plot(interpret(fit_obj, dat, method = "shap", newdata = dat[1:20, , drop = FALSE], nsim = 30, nsamples = 32), kind = "summary")
))

# Reference package comparisons where available.
if (pkg_available("vip")) {
  vi <- vip::vi_permute(
    object = stats::lm(mpg ~ wt + hp + qsec + drat, data = dat),
    feature_names = c("wt", "hp", "qsec", "drat"),
    train = dat,
    target = dat$mpg,
    metric = "rmse",
    nsim = 10,
    pred_wrapper = function(object, newdata) stats::predict(object, newdata = newdata)
  )
  safe_step("reference_vip", save_plot("reference_vip.png", vip::vip(vi)))
}

if (pkg_available("pdp")) {
  pd_wt <- pdp::partial(stats::lm(mpg ~ wt + hp + qsec + drat, data = dat), pred.var = "wt", train = dat)
  write.csv(as.data.frame(pd_wt), file.path("dev/plot_validation", "reference_pdp_values.csv"), row.names = FALSE)
}

if (pkg_available("fastshap")) {
  safe_step("reference_fastshap", {
    object <- stats::lm(mpg ~ wt + hp + qsec + drat, data = dat)
    shap_vals <- fastshap::explain(
      object,
      X = dat[, c("wt", "hp", "qsec", "drat"), drop = FALSE],
      nsim = 30,
      pred_wrapper = function(object, newdata) stats::predict(object, newdata = newdata),
      newdata = dat[1:20, c("wt", "hp", "qsec", "drat"), drop = FALSE]
    )
    write.csv(as.data.frame(shap_vals), file.path("dev/plot_validation", "reference_fastshap_values.csv"), row.names = FALSE)
  })
}

message("Plot validation artifacts written to dev/plot_validation/")
