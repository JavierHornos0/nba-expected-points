# 04_score_and_export.R
# Score all shots with 2PT and 3PT models, compute expected points, and export.

source(file.path("R", "00_config.R"))

required_pkgs <- c("dplyr", "arrow", "hoopR", "readr")
to_install <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(dplyr)
library(arrow)
library(hoopR)
library(readr)

season <- hoopR::year_to_season(SEASON_YEAR)

processed_path <- PROCESSED_SHOTS_FILE(season, SEASON_TYPE)
if (!file.exists(processed_path)) stop("Processed file not found: ", processed_path)

model_path_2pt <- MODEL_FILE_2PT(season, SEASON_TYPE)
model_path_3pt <- MODEL_FILE_3PT(season, SEASON_TYPE)
if (!file.exists(model_path_2pt) || !file.exists(model_path_3pt)) {
  stop("Model files not found. Run R/03_train_models.R first.")
}

shots <- arrow::read_parquet(processed_path)

fit_2pt <- readRDS(model_path_2pt)
fit_3pt <- readRDS(model_path_3pt)

# -----------------------
# Score 2PT and 3PT separately then bind back
# -----------------------
score_subset <- function(df, fit, shot_value) {
  pred <- predict(fit, new_data = df, type = "prob") %>%
    bind_cols(df) %>%
    rename(p_make = .pred_1) %>%
    mutate(
      shot_value = shot_value,
      ep = shot_value * p_make,
      actual_pts = shot_value * y,
      added_value = actual_pts - ep
    )
  pred
}

shots_2pt <- shots %>% filter(is_three == 0)
shots_3pt <- shots %>% filter(is_three == 1)

scored_2pt <- score_subset(shots_2pt, fit_2pt, 2)
scored_3pt <- score_subset(shots_3pt, fit_3pt, 3)

shots_scored <- bind_rows(scored_2pt, scored_3pt) %>%
  arrange(game_date, game_id, game_event_id)

# -----------------------
# Export shot-level scored file
# -----------------------
scored_path <- SCORED_SHOTS_FILE(season, SEASON_TYPE)
arrow::write_parquet(shots_scored, scored_path)
message("Saved scored shots: ", scored_path)

# -----------------------
# Simple summaries (player, team)
# -----------------------
player_summary <- shots_scored %>%
  group_by(player_id, player_name) %>%
  summarise(
    fga = n(),
    fg_pct = mean(y),
    avg_ep = mean(ep),
    total_ep = sum(ep),
    total_actual_pts = sum(actual_pts),
    total_added_value = sum(added_value),
    .groups = "drop"
  ) %>%
  arrange(desc(total_added_value), desc(total_ep))

team_summary <- shots_scored %>%
  group_by(team_id, team_name) %>%
  summarise(
    fga = n(),
    fg_pct = mean(y),
    avg_ep = mean(ep),
    total_ep = sum(ep),
    total_actual_pts = sum(actual_pts),
    total_added_value = sum(added_value),
    .groups = "drop"
  ) %>%
  arrange(desc(total_added_value), desc(total_ep))

player_path <- file.path(DIR_SUMMARIES, paste0("player_summary_", season, "_", gsub(" ", "_", SEASON_TYPE), ".csv"))
team_path   <- file.path(DIR_SUMMARIES, paste0("team_summary_", season, "_", gsub(" ", "_", SEASON_TYPE), ".csv"))

readr::write_csv(player_summary, player_path)
readr::write_csv(team_summary, team_path)

message("Saved player summary: ", player_path)
message("Saved team summary:   ", team_path)
