knitr::opts_chunk$set(collapse = TRUE, comment = "#>")
library(funcml)

fit_obj <- fit(mpg ~ wt + hp, data = mtcars, model = "glm")

permute_obj <- interpret(fit_obj, mtcars, method = "permute", nsim = 5)
pdp_obj <- interpret(fit_obj, mtcars, method = "pdp", features = "wt")
ale_obj <- interpret(fit_obj, mtcars, method = "ale", features = "wt")
local_obj <- interpret(fit_obj, mtcars, method = "local_model", newdata = mtcars[1, , drop = FALSE], k = 2)
shap_obj <- interpret(fit_obj, mtcars, method = "shap", newdata = mtcars[1, , drop = FALSE], nsim = 20)
profile_obj <- interpret(fit_obj, mtcars, method = "profile", newdata = mtcars[1, , drop = FALSE])
surrogate_obj <- interpret(fit_obj, mtcars, method = "surrogate")

eval_obj <- evaluate(mpg ~ wt + hp, data = mtcars, model = "glm", resampling = holdout(prop = 0.8, seed = 1))
eval_obj$summary

tune_grid <- expand.grid(intercept = c(TRUE, FALSE))
tune_obj <- tune(mpg ~ wt + hp, data = mtcars, model = "glm", grid = tune_grid, search = "random", n_evals = 1, resampling = cv(v = 3, seed = 1), seed = 1)
tune_obj$best

nested_tune_obj <- tune(
  mpg ~ wt + hp,
  data = mtcars,
  model = "glm",
  grid = tune_grid,
  resampling = cv(v = 3, seed = 1),
  outer_resampling = cv(v = 4, seed = 2),
  metric = "rmse",
  seed = 1
)
nested_tune_obj$nested$summary

# interaction_obj <- interpret(fit_obj, mtcars, method = "interaction")
# plot(interaction_obj)

learners()[1:10]

plot(permute_obj)
plot(pdp_obj)
plot(ale_obj)
plot(local_obj)
plot(shap_obj, kind = "waterfall")
plot(profile_obj)
plot(surrogate_obj)
