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
"ketapain"
