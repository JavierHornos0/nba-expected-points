# 02_prepare_dataset.R
# Clean raw shot data and build features for modeling (no tracking)

source(file.path("R", "00_config.R"))

required_pkgs <- c("dplyr", "stringr", "lubridate", "arrow", "hoopR")
to_install <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(dplyr)
library(stringr)
library(lubridate)
library(arrow)
library(hoopR)

season <- hoopR::year_to_season(SEASON_YEAR)

raw_path <- RAW_SHOTS_FILE(season, SEASON_TYPE)
if (!file.exists(raw_path)) stop("Raw file not found: ", raw_path, "\nRun R/01_download_shots.R first.")

shots_raw <- arrow::read_parquet(raw_path)

# -----------------------
# Minimal, robust cleaning
# -----------------------
shots <- shots_raw %>%
  transmute(
    # IDs
    game_id = as.character(GAME_ID),
    game_event_id = suppressWarnings(as.integer(GAME_EVENT_ID)),
    player_id = as.character(PLAYER_ID),
    team_id = as.character(TEAM_ID),
    
    # Names (useful for later summaries)
    player_name = PLAYER_NAME,
    team_name = TEAM_NAME,
    
    # Date/time
    game_date = suppressWarnings(ymd(GAME_DATE)),
    period = suppressWarnings(as.integer(PERIOD)),
    min_rem = suppressWarnings(as.integer(MINUTES_REMAINING)),
    sec_rem = suppressWarnings(as.integer(SECONDS_REMAINING)),
    
    # Shot info
    shot_type = SHOT_TYPE,               # "2PT Field Goal" / "3PT Field Goal"
    action_type = ACTION_TYPE,
    zone_basic = SHOT_ZONE_BASIC,
    zone_area  = SHOT_ZONE_AREA,
    zone_range = SHOT_ZONE_RANGE,
    
    shot_distance = suppressWarnings(as.numeric(SHOT_DISTANCE)),
    loc_x = suppressWarnings(as.numeric(LOC_X)),
    loc_y = suppressWarnings(as.numeric(LOC_Y)),
    
    made = suppressWarnings(as.integer(SHOT_MADE_FLAG))
  ) %>%
  mutate(
    seconds_remaining_in_period = 60L * min_rem + sec_rem,
    is_three = as.integer(str_detect(shot_type, "3PT")),
    y = made
  ) %>%
  # Basic sanity filters
  filter(
    !is.na(y),
    y %in% c(0, 1),
    !is.na(is_three),
    is_three %in% c(0, 1),
    !is.na(shot_distance),
    shot_distance >= 0,
    !is.na(game_date),
    !is.na(period),
    !is.na(seconds_remaining_in_period)
  ) %>%
  arrange(game_date, game_id, game_event_id)

# -----------------------
# Optional: cap extreme distances (rare heaves) for stability
# -----------------------
shots <- shots %>%
  mutate(
    shot_distance_capped = pmin(shot_distance, 40)  # adjust if you want
  )

processed_path <- PROCESSED_SHOTS_FILE(season, SEASON_TYPE)
arrow::write_parquet(shots, processed_path)
message("Saved processed dataset to: ", processed_path)
message("Rows: ", nrow(shots))
