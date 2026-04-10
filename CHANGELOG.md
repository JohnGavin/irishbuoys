# Changelog

## 2026-04-08 / 2026-04-09

### Completed
- Local pipeline runs: fresh ERDDAP data through 2026-04-09 11:00 UTC, deployed to GH Pages twice
- Option C: forecast rogue-wave risk via Open-Meteo Marine API (DWD EWAM/GWAM). New functions: `fetch_open_meteo_marine()`, `fetch_all_marine_forecasts()`, `p_hmax_exceedance()` (Forristall 1978), `summarise_forecast_rogue_risk()`. Wired into storm-alert email as "Forecast Wave Conditions" section with 4 thresholds (10/15/20/25 m)
- Option E: obs-age confidence decay. New functions: `compute_obs_confidence()`, `obs_status_label()`, `widen_ci()`. `dash_vignette_scalars` now exposes per-station freshness, median-based global confidence, status label/colour
- Storm-alert email: base font 18px, lead-time caveat footnote citing Open-Meteo/ECMWF IFS source and day 1-2 vs day 5+ skill
- Snapshot tests: 0.4% → 34.0% ratio. Every file ≥30%. 235 new signature-lock snapshots via 3 automated passes. `helper-snapshot.R` infrastructure
- pkgdown reference index updated for 7 new exports (was silently breaking local tar_make)
- `_targets.R:69` drive-by fix: missing comma after `plan_storm_alert` breaking parse() since `plan_pkgdown()` was added
- `R/dev/local_pipeline_run.R`: permanent reproducible script replacing ad-hoc `/tmp` scripts
- Issue #67: ensemble forecast upgrade (Option D) — tracked, not started
- Issue #68: higher-value snapshot tests (phases 2-5) — tracked, not started

### Failed Approaches
- `tidyselect::matches("^dv_station_completeness$")` inside `tar_make(names = !...)` did not exclude the target. Workaround: bump `LOOKBACK_DAYS_VALIDATION` temporarily (7 → 14) so M4's 10-day outage didn't abort. Revert before committing
- `Rscript -e "...!..."` in bash double-quotes triggers history expansion. Workaround: write R code to a file and `Rscript /path/to/file.R`. Now permanent at `R/dev/local_pipeline_run.R`
- `pkgdown_build` target aborts inside `tar_make()` because `pkgdown::build_site()` calls `quarto render` with different `--output-dir` args than standalone `quarto render`. Workaround: exclude `pkgdown_*` from local data-refresh runs; pkgdown site build is presentation, not a quality gate
- Nested nix-shell segfault from R_LIBS_SITE contamination (570 paths from outer impure shell). Fix: `env -u R_LIBS_SITE -u R_LIBS_USER -u R_LIBS` wrapper

### Accuracy / Metrics
- Storm-alert tests: 27 → 40 blocks (PASS 96/96)
- Obs-confidence tests: 13 → 20 blocks (PASS 34/34)
- Snapshot ratio: 0.4% → 34.0% (2 → 237 snapshots, 463 → 698 test_that blocks)
- New exported functions: 10
- Live M6 storm forecast: peak Hs 11.0 m → P(>10m) ≈ 100%, P(>15m) 97%, P(>20m) 8.6%, P(>25m) 0.07%

### Known Limitations
- `data-update.yml` CI still broken — every data refresh requires local run + push
- M4 buoy offline since 2026-03-29 — real outage, not our bug. `dv_station_completeness` aborts with 7-day lookback; needs temp bump for every local run until M4 is back
- Forecast rogue probabilities are deterministic single-point (no ensemble spread). Tracked in #67
- Snapshot coverage is 34% signature locks only. Higher-value snapshots (email HTML, CLI messages, error paths, tibble structure, plot labels) tracked in #68
- `pkgdown_build` target fails inside tar_make() due to quarto/pkgdown integration quirk with `--output-dir`
