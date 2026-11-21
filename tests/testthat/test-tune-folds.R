test_that("tune() scores every configuration on the same folds", {
  d <- transform(heartdisease, heart_disease = factor(heart_disease))
  g <- data.frame(cp = c(0.01, 0.01))
  t1 <- tune(d, heart_disease ~ ., model = "rpart", grid = g, resampling = cv(5), seed = 3)
  ## two identical configurations must get identical scores on shared folds
  expect_equal(t1$results$mean[1], t1$results$mean[2])
})
