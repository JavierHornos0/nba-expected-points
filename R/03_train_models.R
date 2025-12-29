# 03_train_models.R
# Train two separate models:
# - 2PT make probability
# - 3PT make probability
# Using a temporal split to avoid leakage
#
# This version computes log loss / Brier / AUC with robust manual functions
# (AUC via pROC) to avoid yardstick version differences.

source(file.path("R", "00_config.R"))

required_pkgs <- c(
  "dplyr", "arrow", "hoopR",
  "rsample", "recipes", "parsnip", "workflows",
  "readr", "tibble", "pROC"
)

to_install <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(dplyr)
library(arrow)
library(hoopR)

library(rsample)
library(recipes)
library(parsnip)
library(workflows)
library(readr)
library(tibble)
library(pROC)

season <- hoopR::year_to_season(SEASON_YEAR)

processed_path <- PROCESSED_SHOTS_FILE(season, SEASON_TYPE)
if (!file.exists(processed_path)) {
  stop("Processed file not found: ", processed_path, "\nRun R/02_prepare_dataset.R first.")
}

shots <- arrow::read_parquet(processed_path) %>%
  arrange(game_date, game_id, game_event_id)

# -----------------------
# Temporal split (80/20 by date quantile) - robust for Date
# -----------------------
cut_num  <- stats::quantile(as.numeric(shots$game_date), probs = 0.80, na.rm = TRUE, names = FALSE)
cut_date <- as.Date(cut_num, origin = "1970-01-01")

train_df <- filter(shots, game_date <= cut_date)
test_df  <- filter(shots, game_date >  cut_date)

# Make outcome a factor for classification (tidymodels requirement)
# Levels explicitly set so "1" is the positive class.
train_df <- train_df %>% mutate(y = factor(y, levels = c(0, 1)))
test_df  <- test_df  %>% mutate(y = factor(y, levels = c(0, 1)))

message("Train rows: ", nrow(train_df), " | Test rows: ", nrow(test_df), " | Cut date: ", cut_date)

# -----------------------
# Robust metric functions
# -----------------------
manual_log_loss <- function(truth_factor, p_make, eps = 1e-15) {
  y_num <- as.integer(truth_factor == "1")
  p <- pmin(pmax(p_make, eps), 1 - eps)
  -mean(y_num * log(p) + (1 - y_num) * log(1 - p))
}

manual_brier <- function(truth_factor, p_make) {
  y_num <- as.integer(truth_factor == "1")
  mean((y_num - p_make)^2)
}

manual_auc <- function(truth_factor, p_make) {
  # pROC expects levels order: controls then cases (0 then 1)
  r <- pROC::roc(response = truth_factor, predictor = p_make,
                 levels = c("0", "1"), direction = "<", quiet = TRUE)
  as.numeric(pROC::auc(r))
}

# -----------------------
# Helper: fit + evaluate model for a subset (2PT or 3PT)
# -----------------------
fit_eval_subset <- function(train_sub, test_sub, label) {
  
  rec <- recipe(
    y ~ shot_distance_capped + zone_basic + zone_area + zone_range +
      period + seconds_remaining_in_period + action_type,
    data = train_sub
  ) %>%
    step_novel(all_nominal_predictors()) %>%
    step_unknown(all_nominal_predictors()) %>%
    step_other(all_nominal_predictors(), threshold = 0.01) %>%
    step_dummy(all_nominal_predictors())
  
  model <- logistic_reg() %>% set_engine("glm")
  
  wf <- workflow() %>%
    add_recipe(rec) %>%
    add_model(model)
  
  fit <- fit(wf, data = train_sub)
  
  pred <- predict(fit, new_data = test_sub, type = "prob") %>%
    bind_cols(test_sub %>% select(y)) %>%
    mutate(p_make = .pred_1)
  
  # Metrics
  m_logloss <- manual_log_loss(pred$y, pred$p_make)
  m_brier   <- manual_brier(pred$y, pred$p_make)
  m_auc     <- manual_auc(pred$y, pred$p_make)
  
  metrics <- tibble(
    .metric = c("log_loss", "brier", "auc"),
    .estimator = "binary",
    .estimate = c(m_logloss, m_brier, m_auc),
    model = label
  )
  
  list(fit = fit, metrics = metrics)
}

# -----------------------
# Train 2PT model
# -----------------------
train_2pt <- filter(train_df, is_three == 0)
test_2pt  <- filter(test_df,  is_three == 0)

message("2PT train: ", nrow(train_2pt), " | 2PT test: ", nrow(test_2pt))
res_2pt <- fit_eval_subset(train_2pt, test_2pt, "2PT")

# -----------------------
# Train 3PT model
# -----------------------
train_3pt <- filter(train_df, is_three == 1)
test_3pt  <- filter(test_df,  is_three == 1)

message("3PT train: ", nrow(train_3pt), " | 3PT test: ", nrow(test_3pt))
res_3pt <- fit_eval_subset(train_3pt, test_3pt, "3PT")

# -----------------------
# Save models
# -----------------------
model_path_2pt <- MODEL_FILE_2PT(season, SEASON_TYPE)
model_path_3pt <- MODEL_FILE_3PT(season, SEASON_TYPE)

saveRDS(res_2pt$fit, model_path_2pt)
saveRDS(res_3pt$fit, model_path_3pt)

message("Saved 2PT model: ", model_path_2pt)
message("Saved 3PT model: ", model_path_3pt)

# -----------------------
# Save metrics
# -----------------------
metrics <- bind_rows(res_2pt$metrics, res_3pt$metrics)

metrics_path <- METRICS_FILE(season, SEASON_TYPE)
readr::write_csv(metrics, metrics_path)

message("Saved metrics: ", metrics_path)
print(metrics)
