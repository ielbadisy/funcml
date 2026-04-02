# Learner Audit Test Matrix

Each row represents one learner-by-task scenario from the package-wide screening harness.

learner | backend | task | fit_status | predict_raw_status | predict_prob_status | level_handling_status | prob_shape_status | prob_row_sum_status | prob_column_name_status | raw_vs_prob_class_consistency | interpret_raw_status | interpret_prob_status | warning_summary | error_summary | final_status | notes
--- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | ---
adaboost | ada | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
adaboost | ada | multiclass_classification | unsupported | unsupported | unsupported | not_tested | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported |  | fit: Model 'adaboost' does not support multiclass classification. | unsupported | raw path not evaluated \| probability path not evaluated
bart | dbarts | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
bart | dbarts | multiclass_classification | unsupported | unsupported | unsupported | not_tested | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported |  | fit: Model 'bart' does not support multiclass classification. | unsupported | raw path not evaluated \| probability path not evaluated
bart | dbarts | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
C50 | C50 | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
C50 | C50 | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
catboost | catboost | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
catboost | catboost | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
catboost | catboost | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
cforest | partykit | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
cforest | partykit | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
cforest | partykit | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
ctree | partykit | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
ctree | partykit | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
ctree | partykit | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
e1071_svm | e1071 | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
e1071_svm | e1071 | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
e1071_svm | e1071 | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
earth | earth | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
earth | earth | multiclass_classification | unsupported | unsupported | unsupported | not_tested | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported |  | fit: Model 'earth' does not support multiclass classification. | unsupported | raw path not evaluated \| probability path not evaluated
earth | earth | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
fda | mda | binary_classification | pass | pass | unsupported | pass | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  | predict_prob: Model 'fda' does not support type='prob'. \| interpret_prob: Model 'fda' does not support type='prob'. | pass | Model 'fda' does not support type='prob'.
fda | mda | multiclass_classification | pass | pass | unsupported | pass | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  | predict_prob: Model 'fda' does not support type='prob'. \| interpret_prob: Model 'fda' does not support type='prob'. | pass | Model 'fda' does not support type='prob'.
gam | mgcv | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
gam | mgcv | multiclass_classification | unsupported | unsupported | unsupported | not_tested | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported |  | fit: Model 'gam' does not support multiclass classification. | unsupported | raw path not evaluated \| probability path not evaluated
gam | mgcv | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
gbm | gbm | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
gbm | gbm | multiclass_classification | unsupported | unsupported | unsupported | not_tested | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported |  | fit: Model 'gbm' does not support multiclass classification. | unsupported | raw path not evaluated \| probability path not evaluated
gbm | gbm | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
glm | stats | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
glm | stats | multiclass_classification | unsupported | unsupported | unsupported | not_tested | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported |  | fit: Model 'glm' does not support multiclass classification. | unsupported | raw path not evaluated \| probability path not evaluated
glm | stats | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
glmnet | glmnet | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
glmnet | glmnet | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
glmnet | glmnet | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
kknn | kknn | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
kknn | kknn | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
kknn | kknn | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
lda | MASS | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
lda | MASS | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
lightgbm | lightgbm | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
lightgbm | lightgbm | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
lightgbm | lightgbm | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
naivebayes | naivebayes | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
naivebayes | naivebayes | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
nnet | nnet | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
nnet | nnet | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
nnet | nnet | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
pls | pls | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
qda | MASS | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
qda | MASS | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
randomForest | randomForest | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
randomForest | randomForest | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
randomForest | randomForest | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
ranger | ranger | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
ranger | ranger | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
ranger | ranger | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
rpart | rpart | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
rpart | rpart | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
rpart | rpart | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
stacking | stats | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
stacking | stats | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
stacking | stats | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
superlearner | stats | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
superlearner | stats | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
superlearner | stats | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
xgboost | xgboost | binary_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
xgboost | xgboost | multiclass_classification | pass | pass | pass | pass | pass | pass | pass | pass | pass | pass |  |  | pass | 
xgboost | xgboost | regression | pass | pass | unsupported | unsupported | unsupported | unsupported | unsupported | unsupported | pass | unsupported |  |  | pass | probability path not evaluated
