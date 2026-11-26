test_that("interpret() docs state the lime, SHAP baseline and interaction-weight conventions", {
  rd <- testthat::test_path("..", "..", "man", "interpret.Rd")
  skip_if_not(file.exists(rd))
  txt <- paste(readLines(rd), collapse = " ")
  expect_match(txt, "not the K-Lasso", fixed = TRUE)
  expect_match(txt, "mean prediction at the background rows drawn for that row", fixed = TRUE)
  expect_match(txt, "both-precede", fixed = TRUE)
  expect_match(txt, "2 (p - |S| - 1) / p", fixed = TRUE)
})

test_that("MC SHAP baseline is the per-row mean over the drawn background rows", {
  f <- fit(mpg ~ wt + hp, mtcars, "glm")
  s <- interpret(f, mtcars, method = "shap", newdata = mtcars[1:2, ], nsim = 5, seed = 1)$result
  b <- tapply(s$baseline, s$observation, unique)
  expect_false(isTRUE(all.equal(b[[1]], b[[2]])))
  tot <- tapply(s$shap, s$observation, sum)
  expect_equal(unname(tot), unname(tapply(s$prediction - s$baseline, s$observation, unique)))
})
