#' Arthritis survey data
#'
#' A classification dataset on arthritis status and related demographic and
#' behavioral covariates.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 4,856 rows and 12 variables:
#' \describe{
#'   \item{id}{Participant identifier.}
#'   \item{status}{Arthritis status (`"Yes"` or `"No"`).}
#'   \item{heart_attack_relative}{Whether a relative had a heart attack.}
#'   \item{gender}{Participant gender.}
#'   \item{age}{Participant age in years.}
#'   \item{bmi}{Body mass index.}
#'   \item{diabetes}{Whether the participant has diabetes.}
#'   \item{alcohol}{Whether the participant reports alcohol use.}
#'   \item{smoke}{Whether the participant smokes.}
#'   \item{prehypertension}{Whether the participant has prehypertension.}
#'   \item{vegetarian}{Whether the participant follows a vegetarian diet.}
#'   \item{covered_health}{Whether the participant has health coverage.}
#' }
#' @source Original arthritis survey dataset distributed with the project
#'   materials.
#' @examples
#' str(funcml::arthritis)
#' table(funcml::arthritis$status)
"arthritis"

#' Bangladesh maternal risk data
#'
#' A classification dataset for maternal health risk level with vital signs,
#' diabetes history, and related clinical indicators.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 1,205 rows and 12 variables:
#' \describe{
#'   \item{age}{Maternal age in years.}
#'   \item{systolic_bp}{Systolic blood pressure.}
#'   \item{diastolic}{Diastolic blood pressure.}
#'   \item{bs}{Blood sugar measurement.}
#'   \item{body_temp}{Body temperature.}
#'   \item{bmi}{Body mass index.}
#'   \item{previous_complications}{Indicator for previous pregnancy complications.}
#'   \item{preexisting_diabetes}{Indicator for preexisting diabetes.}
#'   \item{gestational_diabetes}{Indicator for gestational diabetes.}
#'   \item{mental_health}{Indicator for mental health concerns.}
#'   \item{heart_rate}{Heart rate.}
#'   \item{risk_level}{Maternal risk level outcome.}
#' }
#' @source Mojumdar MU, Sarker D, Assaduzzaman M, et al. (2025). Maternal
#'   health risk factors dataset: Clinical parameters and insights from rural
#'   Bangladesh. *Data in Brief*, 59(Suppl 2), 111363.
#'   doi:10.1016/j.dib.2025.111363.
#' @examples
#' str(funcml::bangladeshmaternalrisk)
#' table(funcml::bangladeshmaternalrisk$risk_level)
"bangladeshmaternalrisk"

#' Pima diabetes data
#'
#' A diabetes classification dataset with clinical measurements and a predefined
#' train/test split column.
#'
#' @format A data frame with 532 rows and 9 variables:
#' \describe{
#'   \item{npreg}{Number of pregnancies.}
#'   \item{glu}{Plasma glucose concentration.}
#'   \item{bp}{Diastolic blood pressure.}
#'   \item{skin}{Triceps skin fold thickness.}
#'   \item{bmi}{Body mass index.}
#'   \item{ped}{Diabetes pedigree function.}
#'   \item{age}{Age in years.}
#'   \item{diabetes}{Diabetes outcome (`"Yes"` or `"No"`).}
#'   \item{split}{Suggested split indicator (`"train"` or `"test"`).}
#' }
#' @source National Institute of Diabetes and Digestive and Kidney Diseases
#'   Pima Indians Diabetes Database.
#' @references Smith JW, Everhart JE, Dickson WC, Knowler WC, Johannes RS
#'   (1988). Using the ADAP learning algorithm to forecast the onset of
#'   diabetes mellitus. In *Proceedings of the Annual Symposium on Computer
#'   Application in Medical Care*, 261-265.
#' @examples
#' str(funcml::pimadiabetes)
#' table(funcml::pimadiabetes$split)
"pimadiabetes"

#' Youth tobacco survey data
#'
#' A classification-oriented survey dataset on smoking exposure, tobacco use,
#' and tobacco-related environments among youth respondents.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 3,915 rows and 27 variables:
#' \describe{
#'   \item{final_wgt}{Survey final weight.}
#'   \item{age}{Age group.}
#'   \item{gender}{Gender.}
#'   \item{income}{Personal spending money category.}
#'   \item{parent_work}{Parental work status.}
#'   \item{father_education}{Father's education level.}
#'   \item{mother_education}{Mother's education level.}
#'   \item{living_env}{Living environment.}
#'   \item{age_first_cig}{Age at first cigarette.}
#'   \item{cigar_use}{Cigar use indicator.}
#'   \item{noncig_use}{Non-cigarette tobacco use indicator.}
#'   \item{smokeless_use}{Smokeless tobacco use indicator.}
#'   \item{parent_smoke}{Parental smoking exposure.}
#'   \item{friends_smoke}{Friends' smoking exposure.}
#'   \item{home_shs}{Secondhand smoke exposure at home.}
#'   \item{outside_shs}{Secondhand smoke exposure outside the home.}
#'   \item{indoor_ban}{Indoor smoking ban indicator.}
#'   \item{outdoor_ban}{Outdoor smoking ban indicator.}
#'   \item{antitobacco_media}{Exposure to antitobacco media.}
#'   \item{antitobacco_school}{Exposure to school antitobacco education.}
#'   \item{tobacco_media}{Exposure to tobacco media.}
#'   \item{offer_freetobacco}{Whether free tobacco was offered.}
#'   \item{own_items}{Ownership of tobacco-branded items.}
#'   \item{knowledge_harm}{Knowledge that tobacco is harmful.}
#'   \item{e_cig}{Electronic cigarette use indicator.}
#'   \item{stratum}{Survey stratum identifier.}
#'   \item{psu}{Primary sampling unit identifier.}
#' }
#' @source Morocco Global Youth Tobacco Survey public-use survey data.
#' @references Kim N, Loh WY, McCarthy DE (2021). Machine learning models of
#'   tobacco susceptibility and current use among adolescents from 97 countries
#'   in the Global Youth Tobacco Survey, 2013-2017. *PLOS Global Public
#'   Health*, 1(12), e0000060. doi:10.1371/journal.pgph.0000060.
#' @examples
#' str(funcml::cigsmoke)
#' table(funcml::cigsmoke$e_cig)
"cigsmoke"

#' Birth weight data
#'
#' A regression-oriented birth weight dataset with maternal risk factors and a
#' derived low-birth-weight indicator.
#'
#' @format A data frame with 189 rows and 10 variables:
#' \describe{
#'   \item{age}{Maternal age in years.}
#'   \item{lwt}{Maternal weight at the last menstrual period.}
#'   \item{race}{Maternal race code.}
#'   \item{smoke}{Smoking status indicator.}
#'   \item{ptl}{Number of previous premature labors.}
#'   \item{ht}{History of hypertension indicator.}
#'   \item{ui}{Presence of uterine irritability indicator.}
#'   \item{ftv}{Number of physician visits in the first trimester.}
#'   \item{birth_weight_g}{Birth weight in grams.}
#'   \item{low_birth_weight}{Low-birth-weight outcome indicator.}
#' }
#' @source Hosmer DW, Lemeshow S (1989). *Applied Logistic Regression*. Wiley.
#'   The packaged data are a lightly renamed version of the classic
#'   `MASS::birthwt` dataset.
#' @examples
#' str(funcml::birthweight)
#' summary(funcml::birthweight$birth_weight_g)
"birthweight"

#' Ketamine pain management data
#'
#' A regression dataset on ketamine dosing, treatment characteristics, cost,
#' quality-adjusted life years, and administration mode.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 184 rows and 11 variables:
#' \describe{
#'   \item{patient_id}{Patient identifier.}
#'   \item{sexe}{Recorded sex.}
#'   \item{age}{Patient age in years.}
#'   \item{av_dose}{Average dose.}
#'   \item{level_dose}{Dose level category.}
#'   \item{cum_dose}{Cumulative dose.}
#'   \item{cum_days}{Cumulative treatment days.}
#'   \item{perfusion}{Perfusion duration.}
#'   \item{cost}{Treatment cost.}
#'   \item{qaly}{Quality-adjusted life years.}
#'   \item{mode}{Administration mode.}
#' }
#' @source Original ketamine pain management dataset distributed with the
#'   project materials.
#' @examples
#' str(funcml::ketapain)
#' summary(funcml::ketapain$qaly)
"ketapain"

#' Haberman survival data
#'
#' A binary classification dataset on breast cancer survival after surgery.
#'
#' @format A data frame with 306 rows and 4 variables:
#' \describe{
#'   \item{age}{Age of patient at operation time in years.}
#'   \item{operation_year}{Year of operation minus 1900.}
#'   \item{positive_axillary_nodes}{Number of positive axillary nodes detected.}
#'   \item{survival_status}{Survival status (`1` = survived 5 years or longer,
#'   `2` = died within 5 years).}
#' }
#' @source Haberman's Survival Data from the University of Chicago's Billings
#'   Hospital study, distributed through the UCI Machine Learning Repository.
#' @examples
#' str(funcml::haberman)
#' table(funcml::haberman$survival_status)
"haberman"

#' Wisconsin breast cancer data
#'
#' A binary classification dataset for breast cancer diagnosis from cytology
#' measurements.
#'
#' @format A data frame with 699 rows and 10 variables:
#' \describe{
#'   \item{clump_thickness}{Clump thickness score.}
#'   \item{uniformity_cell_size}{Uniformity of cell size score.}
#'   \item{uniformity_cell_shape}{Uniformity of cell shape score.}
#'   \item{marginal_adhesion}{Marginal adhesion score.}
#'   \item{single_epithelial_cell_size}{Single epithelial cell size score.}
#'   \item{bare_nuclei}{Bare nuclei score.}
#'   \item{bland_chromatin}{Bland chromatin score.}
#'   \item{normal_nucleoli}{Normal nucleoli score.}
#'   \item{mitoses}{Mitoses score.}
#'   \item{class}{Diagnostic class (`2` = benign, `4` = malignant).}
#' }
#' @source Wisconsin Breast Cancer Database from University of Wisconsin
#'   Hospitals, distributed through the UCI Machine Learning Repository.
#' @examples
#' str(funcml::breastcancerwisconsin)
#' table(funcml::breastcancerwisconsin$class)
"breastcancerwisconsin"

#' Mammography calcification data
#'
#' A binary classification dataset for detection of mammographic
#' microcalcifications.
#'
#' @format A data frame with 11,183 rows and 7 variables:
#' \describe{
#'   \item{attr1}{Numeric imaging-derived predictor 1.}
#'   \item{attr2}{Numeric imaging-derived predictor 2.}
#'   \item{attr3}{Numeric imaging-derived predictor 3.}
#'   \item{attr4}{Numeric imaging-derived predictor 4.}
#'   \item{attr5}{Numeric imaging-derived predictor 5.}
#'   \item{attr6}{Numeric imaging-derived predictor 6.}
#'   \item{class}{Calcification class (`\"-1\"` or `\"1\"`).}
#' }
#' @source Woods K, Doss C, Bowyer K, Solka J, Priebe C, Kegelmeyer P
#'   (1993). Comparative evaluation of pattern recognition techniques for
#'   detection of microcalcifications in mammography.
#' @examples
#' str(funcml::mammography)
#' table(funcml::mammography$class)
"mammography"

#' Thyroid function data
#'
#' A multiclass classification dataset on thyroid functional state using five
#' laboratory test measurements.
#'
#' @format A data frame with 215 rows and 6 variables:
#' \describe{
#'   \item{t3_resin_uptake}{T3-resin uptake percentage.}
#'   \item{total_serum_thyroxin}{Total serum thyroxin measurement.}
#'   \item{total_serum_triiodothyronine}{Total serum triiodothyronine
#'   measurement.}
#'   \item{basal_tsh}{Basal thyroid-stimulating hormone measurement.}
#'   \item{max_abs_tsh_diff}{Maximum absolute TSH difference after thyrotropin-
#'   releasing hormone injection.}
#'   \item{class}{Thyroid class (`1` = normal, `2` = hyperthyroid,
#'   `3` = hypothyroid).}
#' }
#' @source Thyroid gland data distributed through the UCI Machine Learning
#'   Repository.
#' @examples
#' str(funcml::newthyroid)
#' table(funcml::newthyroid$class)
"newthyroid"

#' Doctor visits data
#'
#' A regression dataset on annual doctor visit counts and related health,
#' demographic, and insurance covariates.
#'
#' @format A data frame with 5,190 rows and 12 variables:
#' \describe{
#'   \item{visits}{Number of doctor visits.}
#'   \item{gender}{Recorded gender.}
#'   \item{age}{Age in years scaled to decades.}
#'   \item{income}{Income measure scaled by household composition.}
#'   \item{illness}{Number of illnesses in the previous two weeks.}
#'   \item{reduced}{Number of days with reduced activity.}
#'   \item{health}{Self-rated health score.}
#'   \item{private}{Private insurance indicator.}
#'   \item{freepoor}{Free care indicator for low-income patients.}
#'   \item{freerepat}{Free care indicator for pensioners or veterans.}
#'   \item{nchronic}{Indicator for no chronic condition.}
#'   \item{lchronic}{Indicator for limiting chronic condition.}
#' }
#' @source Cameron AC, Trivedi PK (1998). *Regression Analysis of Count Data*.
#'   Cambridge University Press. The packaged data are from `AER::DoctorVisits`.
#' @examples
#' str(funcml::doctorvisits)
#' summary(funcml::doctorvisits$visits)
"doctorvisits"

#' CD4 follow-up data
#'
#' A regression dataset relating baseline CD4 counts to one-year follow-up CD4
#' measurements in HIV-positive patients.
#'
#' @format A data frame with 20 rows and 2 variables:
#' \describe{
#'   \item{baseline}{Baseline CD4 count.}
#'   \item{oneyear}{One-year follow-up CD4 count.}
#' }
#' @source Davison AC, Hinkley DV (1997). *Bootstrap Methods and Their
#'   Application*. Cambridge University Press. The packaged data are from
#'   `boot::cd4`.
#' @examples
#' str(funcml::cd4counts)
#' summary(funcml::cd4counts$oneyear)
"cd4counts"

#' Cancer remission data
#'
#' A binary classification dataset on cancer remission status using leukemia
#' index and treatment group indicators.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 27 rows and 3 variables:
#' \describe{
#'   \item{li}{Leukemia index measurement.}
#'   \item{m}{Treatment group indicator.}
#'   \item{remission}{Remission outcome indicator (`0` = no remission,
#'   `1` = remission).}
#' }
#' @source Davison AC, Hinkley DV (1997). *Bootstrap Methods and Their
#'   Application*. Cambridge University Press. The packaged data are from
#'   `boot::remission`.
#' @examples
#' str(funcml::cancerremission)
#' table(funcml::cancerremission$remission)
"cancerremission"

#' Infant mortality data
#'
#' A regression dataset on infant mortality with country-level income, region,
#' and oil-export status covariates.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 105 rows and 5 variables:
#' \describe{
#'   \item{country}{Country name.}
#'   \item{income}{Per-capita income.}
#'   \item{infant}{Infant mortality rate.}
#'   \item{region}{Geographic region.}
#'   \item{oil}{Oil-exporting country indicator.}
#' }
#' @source Fox J, Weisberg S (2019). *An R Companion to Applied Regression*.
#'   Sage. The packaged data are from `carData::Leinhardt`.
#' @examples
#' str(funcml::infantmortality)
#' summary(funcml::infantmortality$infant)
"infantmortality"

#' Heart failure data
#'
#' A binary classification dataset on heart failure mortality using demographic,
#' laboratory, and clinical covariates.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 299 rows and 13 variables:
#' \describe{
#'   \item{age}{Age in years.}
#'   \item{anaemia}{Anaemia indicator.}
#'   \item{creatinine_phosphokinase}{Creatinine phosphokinase level.}
#'   \item{diabetes}{Diabetes indicator.}
#'   \item{ejection_fraction}{Ejection fraction percentage.}
#'   \item{high_blood_pressure}{High blood pressure indicator.}
#'   \item{platelets}{Platelet count.}
#'   \item{serum_creatinine}{Serum creatinine level.}
#'   \item{serum_sodium}{Serum sodium level.}
#'   \item{sex}{Sex indicator.}
#'   \item{smoking}{Smoking indicator.}
#'   \item{time}{Follow-up time.}
#'   \item{death_event}{Death event outcome indicator (`0` = no event,
#'   `1` = death).}
#' }
#' @source CardioDataSets package dataset
#'   `CardioDataSets::cardiac_failure_df`.
#' @examples
#' str(funcml::heartfailure)
#' table(funcml::heartfailure$death_event)
"heartfailure"

#' Heart disease patient data
#'
#' A binary classification dataset on heart disease status using demographic
#' and clinical risk factors.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 303 rows and 9 variables:
#' \describe{
#'   \item{age}{Age in years.}
#'   \item{sex}{Recorded sex.}
#'   \item{chest_pain}{Chest pain type.}
#'   \item{bp}{Resting blood pressure.}
#'   \item{cholesterol}{Serum cholesterol measurement.}
#'   \item{blood_sugar}{High fasting blood sugar indicator.}
#'   \item{maximum_hr}{Maximum heart rate achieved.}
#'   \item{exercise_induced_angina}{Exercise-induced angina indicator.}
#'   \item{heart_disease}{Heart disease outcome (`"Yes"` or `"No"`).}
#' }
#' @source CardioDataSets package dataset
#'   `CardioDataSets::heartdisease_tbl_df`.
#' @examples
#' str(funcml::heartdisease)
#' table(funcml::heartdisease$heart_disease)
"heartdisease"

#' Breast cancer diagnostic data
#'
#' A binary classification dataset for breast cancer diagnosis using tumor
#' morphology measurements.
#'
#' Column names were standardized to `snake_case` when packaging the data.
#'
#' @format A data frame with 569 rows and 31 variables:
#' \describe{
#'   \item{radius_mean}{Mean radius.}
#'   \item{texture_mean}{Mean texture.}
#'   \item{perimeter_mean}{Mean perimeter.}
#'   \item{area_mean}{Mean area.}
#'   \item{smoothness_mean}{Mean smoothness.}
#'   \item{compactness_mean}{Mean compactness.}
#'   \item{concavity_mean}{Mean concavity.}
#'   \item{concave_pts_mean}{Mean number of concave points.}
#'   \item{symmetry_mean}{Mean symmetry.}
#'   \item{fractal_dim_mean}{Mean fractal dimension.}
#'   \item{radius_se}{Radius standard error.}
#'   \item{texture_se}{Texture standard error.}
#'   \item{perimeter_se}{Perimeter standard error.}
#'   \item{area_se}{Area standard error.}
#'   \item{smoothness_se}{Smoothness standard error.}
#'   \item{compactness_se}{Compactness standard error.}
#'   \item{concavity_se}{Concavity standard error.}
#'   \item{concave_pts_se}{Concave points standard error.}
#'   \item{symmetry_se}{Symmetry standard error.}
#'   \item{fractal_dim_se}{Fractal dimension standard error.}
#'   \item{radius_worst}{Worst radius.}
#'   \item{texture_worst}{Worst texture.}
#'   \item{perimeter_worst}{Worst perimeter.}
#'   \item{area_worst}{Worst area.}
#'   \item{smoothness_worst}{Worst smoothness.}
#'   \item{compactness_worst}{Worst compactness.}
#'   \item{concavity_worst}{Worst concavity.}
#'   \item{concave_pts_worst}{Worst number of concave points.}
#'   \item{symmetry_worst}{Worst symmetry.}
#'   \item{fractal_dim_worst}{Worst fractal dimension.}
#'   \item{diagnosis}{Diagnosis outcome (`"B"` = benign, `"M"` = malignant).}
#' }
#' @source Breast Cancer Wisconsin Diagnostic Dataset from the UCI Machine
#'   Learning Repository, packaged in `dslabs::brca`.
#' @examples
#' str(funcml::breastcancerdiagnostic)
#' table(funcml::breastcancerdiagnostic$diagnosis)
"breastcancerdiagnostic"
