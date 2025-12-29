# R Sports Analytics Template

A reusable template for R-based sports analytics projects (pipelines, modeling, scoring, reports).

## Folder structure (recommended)

- `R/` scripts
- `data/` raw + processed (ignored by git)
- `models/` saved models (ignored by git)
- `outputs/` plots/tables/scored data (ignored by git)
- `docs/` project notes and decisions

## Quick start

1) Open this project in RStudio (recommended: create/open a `.Rproj`).
2) Run the sanity checks:

```r
source("R/doctor.R")
