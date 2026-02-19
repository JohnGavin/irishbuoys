# fix_030.R — Commit _targets/ to git with LFS for CI vignette rendering
#
# Problem:
#   The weekly-update GitHub Actions workflow downloads new buoy data and runs
#   tar_make(), then tries to render vignettes. This always fails because:
#   1. _targets/ was in .gitignore — git add _targets/ silently did nothing
#   2. _targets/.gitignore contained * (ignore all) — blocked objects even if
#      the outer ignore was removed
#   3. Root _targets.yaml had store: ../_targets — wrong path for project root
#   4. inst/extdata/*.rds was gitignored — dashboard_static.qmd reads these
#   5. Only wave_analysis.qmd was rendered — telemetry and dashboard_static skipped
#
# Solution:
#   - Remove _targets/ from .gitignore (commit store to git)
#   - Replace _targets/.gitignore to allow objects/ and meta/meta
#   - Fix _targets.yaml: store: ../_targets -> store: _targets
#   - Remove inst/extdata/*.rds from .gitignore (allow RDS, keep duckdb ignored)
#   - Track 5 large files (> 1 MB) via Git LFS in .gitattributes
#   - Rewrite weekly-update.yml: LFS checkout, 3 vignette renders, fix git add
#   - Restore _targets/.gitignore after tar_make (it regenerates the file)
#
# Files changed:
#   .gitattributes                          — NEW: LFS tracking for 5 large files
#   .gitignore                              — Remove _targets/ and inst/extdata/*.rds
#   _targets/.gitignore                     — Allow objects/ and meta/meta
#   _targets.yaml                           — Fix store path
#   .github/workflows/weekly-update.yml     — LFS, 3 renders, fix git add
#   DESCRIPTION                             — Version 0.1.2 -> 0.1.3
#
# LFS-tracked files (> 1 MB):
#   _targets/objects/dashboard_buoy_data    — 4.6 MB
#   _targets/objects/dashboard_timeseries   — 1.1 MB
#   inst/extdata/wave_analysis_summary.rds  — 9.0 MB
#   inst/extdata/dashboard_buoy_data.rds    — 2.3 MB
#   inst/extdata/seasonal_analysis.rds      — 1.7 MB
#
# Verification:
#   git lfs status                          — 5 files tracked via LFS
#   devtools::check(args = "--no-vignettes") — passes
#   gh workflow run weekly-update.yml       — renders all 3 vignettes
