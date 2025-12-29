# doctor.R
# Lightweight checks to reduce "it doesn't run on my machine" problems.

check <- function(ok, msg_ok, msg_bad) {
  if (isTRUE(ok)) message("OK: ", msg_ok) else stop("ERROR: ", msg_bad, call. = FALSE)
}

message("Running project checks...")

# 1) Working directory: should contain README.md (template) or an .Rproj
check(file.exists("README.md") || length(list.files(pattern = "\\.Rproj$")) > 0,
      "Working directory looks like the project root.",
      "You're probably not in the project root. Open the .Rproj or setwd() to the repo root.")

# 2) Core folders (create if missing)
dirs <- c("R", "docs", "data", "models", "outputs")
for (d in dirs) {
  if (!dir.exists(d)) {
    dir.create(d, recursive = TRUE, showWarnings = FALSE)
    message("Created missing dir: ", d)
  }
}
message("Folder structure present.")

# 3) Optional: check for baseline pipeline scripts
baseline_scripts <- c(
  "R/00_config.R",
  "R/01_download_shots.R",
  "R/02_prepare_dataset.R",
  "R/03_train_models.R",
  "R/04_score_and_export.R"
)

missing <- baseline_scripts[!file.exists(baseline_scripts)]
if (length(missing) > 0) {
  message("Note: baseline scripts not found (this is OK for the template). Missing:")
  message(paste(" -", missing, collapse = "\n"))
} else {
  message("Baseline scripts detected.")
}

message("Doctor checks complete.")
