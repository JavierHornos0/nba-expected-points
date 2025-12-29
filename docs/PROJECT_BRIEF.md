
---

## `docs/PROJECT_BRIEF.md`
```md
# Project Brief

## Goal
Describe the project in 5–10 lines (what metric/model you are building, why it matters, and what the deliverables are).

## Data
- Sources (APIs / packages)
- Seasons covered
- Unit of analysis (shot-level, play-by-play event, possession, etc.)
- Known limitations (e.g., no tracking / no defender distance)

## Pipeline overview
1) Download raw data -> `data/raw/`
2) Build modeling dataset -> `data/processed/`
3) Train model(s) -> `models/`
4) Score + export -> `outputs/`

## Current status
- [ ] Download works
- [ ] Dataset preparation works
- [ ] Model training works
- [ ] Scoring/export works
- [ ] Basic validation checks

## Next steps
List the next 3–8 tasks in priority order.
