# 01_download_shots.R
# Download shot-level data (FGA) for all teams for a given season via hoopR

source(file.path("R", "00_config.R"))

# -----------------------
# Create directories if missing
# -----------------------
dir.create(DIR_DATA_RAW, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_DATA_PROCESSED, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_MODELS, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_OUTPUTS, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_METRICS, recursive = TRUE, showWarnings = FALSE)
dir.create(DIR_SUMMARIES, recursive = TRUE, showWarnings = FALSE)

# -----------------------
# Packages
# -----------------------
required_pkgs <- c("hoopR", "dplyr", "purrr", "tidyr", "arrow")
to_install <- required_pkgs[!vapply(required_pkgs, requireNamespace, logical(1), quietly = TRUE)]
if (length(to_install) > 0) install.packages(to_install)

library(hoopR)
library(dplyr)
library(purrr)
library(tidyr)
library(arrow)

# -----------------------
# Resolve season string
# -----------------------
season <- hoopR::year_to_season(SEASON_YEAR)

message("Season: ", season, " | Season type: ", SEASON_TYPE)

# -----------------------
# Pull teams list (TEAM_ID)
# -----------------------
teams <- hoopR::nba_leaguedashteamstats(
  season = season,
  season_type = SEASON_TYPE
)$LeagueDashTeamStats %>%
  transmute(
    team_id = as.character(TEAM_ID),
    team_name = TEAM_NAME
  ) %>%
  distinct()

message("Teams found: ", nrow(teams))

# -----------------------
# Helper: download shots for a single team
# -----------------------
get_team_shots <- function(team_id) {
  # nba_shotchartdetail returns a list: Shot_Chart_Detail + LeagueAverages
  res <- hoopR::nba_shotchartdetail(
    context_measure = "FGA",
    player_id = 0,
    team_id = team_id,
    season = season,
    season_type = SEASON_TYPE
  )
  
  shots <- res$Shot_Chart_Detail
  if (is.null(shots) || nrow(shots) == 0) {
    warning("No shots returned for team_id=", team_id)
    return(NULL)
  }
  
  shots$TEAM_ID_REQUEST <- team_id
  shots
}

# -----------------------
# Download all teams with basic retry
# -----------------------
safe_get_team_shots <- function(team_id, retries = 3) {
  for (i in seq_len(retries)) {
    Sys.sleep(SLEEP_SECONDS)
    out <- try(get_team_shots(team_id), silent = TRUE)
    if (!inherits(out, "try-error") && !is.null(out)) return(out)
    message("Retry ", i, "/", retries, " for team_id=", team_id)
    Sys.sleep(2)
  }
  warning("Failed to download team_id=", team_id)
  NULL
}

shots_raw <- teams %>%
  mutate(shots = map(team_id, safe_get_team_shots)) %>%
  filter(!map_lgl(shots, is.null)) %>%
  select(team_id, team_name, shots) %>%
  unnest(shots)

message("Total shots downloaded: ", nrow(shots_raw))

# -----------------------
# Save raw parquet cache
# -----------------------
raw_path <- RAW_SHOTS_FILE(season, SEASON_TYPE)
arrow::write_parquet(shots_raw, raw_path)
message("Saved raw shots to: ", raw_path)
