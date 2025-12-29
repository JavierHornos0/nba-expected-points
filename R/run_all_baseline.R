# run_all_baseline.R
# Runs a standard 01->04 pipeline if those files exist.
# Safe to keep in template: it will tell you what is missing.

scripts <- c(
  "R/01_download_shots.R",
  "R/02_prepare_dataset.R",
  "R/03_train_models.R",
  "R/04_score_and_export.R"
)

missing <- scripts[!file.exists(scripts)]
if (length(missing) > 0) {
  stop(
    "Missing pipeline scripts:\n",
    paste(" -", missing, collapse = "\n"),
    "\n\nAdd your project scripts or adjust run_all_baseline.R.",
    call. = FALSE
  )
}

for (s in scripts) {
  message("\n==============================")
  message("Running: ", s)
  message("==============================\n")
  source(s)
}

message("\nAll pipeline steps completed.")
