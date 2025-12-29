# 00_config.R
# Project configuration (edit these values to change season, etc.)

# -----------------------
# Season configuration
# -----------------------
SEASON_YEAR <- 2024                 # 2024 typically corresponds to "2024-25"
SEASON_TYPE <- "Regular Season"     # "Regular Season" / "Playoffs" etc.

# -----------------------
# Rate limiting
# -----------------------
SLEEP_SECONDS <- 0.7                # Sleep between API calls to avoid being blocked

# -----------------------
# Paths
# -----------------------
DIR_DATA_RAW <- file.path("data", "raw")
DIR_DATA_PROCESSED <- file.path("data", "processed")
DIR_MODELS <- "models"
DIR_OUTPUTS <- "outputs"
DIR_METRICS <- file.path(DIR_OUTPUTS, "metrics")
DIR_SUMMARIES <- file.path(DIR_OUTPUTS, "summaries")

# -----------------------
# Filenames
# -----------------------
RAW_SHOTS_FILE <- function(season, season_type) {
  # Keep filenames filesystem-friendly
  st <- gsub(" ", "_", season_type)
  file.path(DIR_DATA_RAW, paste0("shots_raw_", season, "_", st, ".parquet"))
}

PROCESSED_SHOTS_FILE <- function(season, season_type) {
  st <- gsub(" ", "_", season_type)
  file.path(DIR_DATA_PROCESSED, paste0("shots_processed_", season, "_", st, ".parquet"))
}

MODEL_FILE_2PT <- function(season, season_type) {
  st <- gsub(" ", "_", season_type)
  file.path(DIR_MODELS, paste0("model_2pt_", season, "_", st, ".rds"))
}

MODEL_FILE_3PT <- function(season, season_type) {
  st <- gsub(" ", "_", season_type)
  file.path(DIR_MODELS, paste0("model_3pt_", season, "_", st, ".rds"))
}

METRICS_FILE <- function(season, season_type) {
  st <- gsub(" ", "_", season_type)
  file.path(DIR_METRICS, paste0("metrics_", season, "_", st, ".csv"))
}

SCORED_SHOTS_FILE <- function(season, season_type) {
  st <- gsub(" ", "_", season_type)
  file.path(DIR_OUTPUTS, paste0("shots_scored_", season, "_", st, ".parquet"))
}
