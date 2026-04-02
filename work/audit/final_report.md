# Final Audit Report

- Total learners audited: 26
- Total learner-task rows audited: 70
- Total supported combinations passing: 64
- Total unsupported-by-design combinations: 6
- Total rows with warnings: 0
- Total rows failing: 0

## Direct Answer

Are all `funcml` learners well implemented? Yes.
All audited learner-task rows passed without caveats.

## Caveats

- None.

## Unsupported By Design

- `adaboost` / `multiclass_classification`
- `bart` / `multiclass_classification`
- `earth` / `multiclass_classification`
- `gam` / `multiclass_classification`
- `gbm` / `multiclass_classification`
- `glm` / `multiclass_classification`

## Package-wide patterns discovered

- Learners with fully passing advertised rows: 26
- Learners with at least one failing advertised row: 0
- Learners with at least one probability-path failure: 0
- Learners with at least one interpret integration failure: 0

## Recommended Priority Order

- None.

## Readiness Table

learner | task | raw | prob | multiclass | interpret | final_status | notes
--- | --- | --- | --- | --- | --- | --- | ---
glm | binary_classification, multiclass_classification, regression | pass | pass | unsupported | pass | supported and validated | raw path not evaluated \| probability path not evaluated \| probability path not evaluated
rpart | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
glmnet | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
ranger | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
nnet | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
e1071_svm | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
randomForest | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
gbm | binary_classification, multiclass_classification, regression | pass | pass | unsupported | pass | supported and validated | raw path not evaluated \| probability path not evaluated \| probability path not evaluated
C50 | binary_classification, multiclass_classification | pass | pass | pass | pass | supported and validated | 
kknn | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
earth | binary_classification, multiclass_classification, regression | pass | pass | unsupported | pass | supported and validated | raw path not evaluated \| probability path not evaluated \| probability path not evaluated
gam | binary_classification, multiclass_classification, regression | pass | pass | unsupported | pass | supported and validated | raw path not evaluated \| probability path not evaluated \| probability path not evaluated
naivebayes | binary_classification, multiclass_classification | pass | pass | pass | pass | supported and validated | 
fda | binary_classification, multiclass_classification | pass | unsupported | pass | pass | supported and validated | Model 'fda' does not support type='prob'.
adaboost | binary_classification, multiclass_classification | pass | pass | unsupported | pass | supported and validated | raw path not evaluated \| probability path not evaluated
pls | regression | pass | unsupported | unsupported | pass | supported and validated | probability path not evaluated
ctree | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
cforest | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
lda | binary_classification, multiclass_classification | pass | pass | pass | pass | supported and validated | 
qda | binary_classification, multiclass_classification | pass | pass | pass | pass | supported and validated | 
lightgbm | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
catboost | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
bart | binary_classification, multiclass_classification, regression | pass | pass | unsupported | pass | supported and validated | raw path not evaluated \| probability path not evaluated \| probability path not evaluated
xgboost | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
stacking | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
superlearner | binary_classification, multiclass_classification, regression | pass | pass | pass | pass | supported and validated | probability path not evaluated
