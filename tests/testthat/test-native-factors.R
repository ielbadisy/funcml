heart <- function() transform(funcml::heartdisease, heart_disease = factor(heart_disease))
NATIVE <- c("ranger", "rpart", "randomForest", "gbm", "C50", "adaboost", "ctree", "cforest")
SMALL <- list(ranger = list(num.trees = 50), randomForest = list(ntree = 50), cforest = list(ntree = 10))
fitn <- function(f, d, m) fit(f, d, model = m, spec = SMALL[[m]], seed = 1)

test_that("tree learners receive native factors, others the model matrix", {
  h <- heart()
  for (m in NATIVE) expect_identical(fitn(heart_disease ~ ., h, m)$encoding, "native")
  f <- fit(heart_disease ~ ., h, model = "glm")
  expect_identical(f$encoding, "dummy")
  expect_true("sexMale" %in% f$features)
  expect_identical(fit(heart_disease ~ . + age:sex, h, model = "ranger", seed = 1)$encoding, "dummy")
})

test_that("ranger via funcml matches ranger on the native data frame", {
  h <- heart()
  f <- fit(heart_disease ~ ., h, model = "ranger", seed = 42)
  hd <- h; hd[] <- lapply(hd, function(v) if (is.character(v)) factor(v) else v)
  set.seed(42)
  r <- ranger::ranger(heart_disease ~ ., hd, num.trees = 500, min.node.size = 5, probability = TRUE,
                      importance = "impurity", respect.unordered.factors = "order")
  expect_identical(unname(predict(f, h, type = "prob")), unname(predict(r, hd)$predictions))
  expect_setequal(f$features, setdiff(names(h), "heart_disease"))
})

test_that("ranger same-fold CV AUC on heartdisease reaches the native-factor level", {
  withr::local_options(ranger.num.threads = 1)
  e <- evaluate(heart(), heart_disease ~ ., model = "ranger", resampling = cv(5, seed = 2026),
                metrics = "auc", seed = 1)
  expect_gte(e$summary$mean[1], 0.84)
})

test_that("native predict handles a single row, missing levels and unseen levels", {
  h <- heart()
  for (m in NATIVE) {
    f <- fitn(heart_disease ~ ., h, m)
    expect_equal(dim(predict(f, h[7, ], type = "prob")), c(1L, 2L))
    nd <- h[h$chest_pain == "Asymptomatic", ][1:4, ]
    nd$chest_pain <- factor(nd$chest_pain)
    expect_equal(predict(f, nd, type = "prob"), predict(f, h[rownames(nd), ], type = "prob"),
                 ignore_attr = TRUE)
    expect_length(predict(f, nd), 4L)
    bad <- h[1:2, ]; bad$sex <- "Other"
    expect_error(predict(f, bad), "Unseen factor levels")
  }
})

test_that("native learners work in regression and with ordered factors", {
  d <- transform(heart(), grade = factor(chest_pain, ordered = TRUE))
  for (m in NATIVE[NATIVE != "C50" & NATIVE != "adaboost"]) {
    f <- fitn(bp ~ age + sex + grade + blood_sugar, d, m)
    expect_identical(f$encoding, "native")
    expect_true(is.ordered(.encode_new(f, d[1:3, ])$grade))
    expect_length(predict(f, d[5, ]), 1L)
  }
})

test_that("importance is reported per original variable for native learners", {
  h <- heart()
  vars <- setdiff(names(h), "heart_disease")
  for (m in c("ranger", "rpart", "randomForest", "gbm")) {
    f <- fitn(heart_disease ~ ., h, m)
    v <- interpret(f, h, method = "vip", importance_type = "model")
    expect_setequal(v$result$scores$feature, vars)
    expect_true(any(v$result$scores$importance > 0))
    expect_s3_class(plot(v), "ggplot")
  }
})

test_that("interpret and estimate run with native ranger", {
  h <- heart()
  f <- fit(heart_disease ~ ., h, model = "ranger", seed = 1, num.trees = 100)
  for (meth in c("shap", "ale", "permute")) {
    r <- interpret(f, h[1:40, ], method = meth, features = c("age", "sex"), nsim = 3, seed = 1)
    expect_identical(r$method, meth)
  }
  e <- estimate(h, heart_disease ~ exercise_induced_angina + age + sex + chest_pain, model = "ranger",
                spec = list(num.trees = 100), seed = 1)
  expect_true(is.finite(e$estimate))
  g <- estimate(h, heart_disease ~ exercise_induced_angina + age + sex + chest_pain, model = "glm")
  expect_identical(g$fit$encoding, "dummy")
  expect_true(is.finite(g$std_error))
})

test_that("tune grids for native learners respect the number of variables", {
  d <- heart()
  g <- defaulttunegrid("ranger", data = d, formula = heart_disease ~ .)
  expect_lte(max(g$mtry), 8L)
  t <- tune(d, heart_disease ~ ., model = "rpart", grid = defaulttunegrid("rpart"),
            resampling = cv(3, seed = 1), metric = "auc", seed = 1)
  expect_true(is.list(t))
})
