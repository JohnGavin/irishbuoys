# Current Work

## Branch: main
## Last Session: 2026-03-15

### What Was Done
1. **Prediction calibration tracking** (llm#47):
   - `R/predictions.R` — `read_predictions()`, `compute_calibration()`, `store_predictions_duckdb()`
   - `R/tar_plans/plan_predictions.R` — 11 targets (data, tables, plots)
   - `_targets.R` — added `plan_predictions`
   - `vignettes/telemetry.qmd` — Prediction Tracking section (7 subsections with tabset)
   - `~/.claude/hooks/record_prediction.sh` — CLI for recording predictions/outcomes
   - Seeded 5 predictions, verified Brier=0.121, accuracy=75%
   - All 6 acceptance criteria verified
2. **CI fixes**:
   - Created `data-freshness` label (freshness monitor workflow was failing)
   - Bumped `github-install-test` timeout 45→60min (was timing out)
3. **Cross-project (llm repo)**:
   - `llm/R/predictions.R` — `discover_project_predictions()`, `load_all_predictions()`
   - `llm/R/tar_plans/plan_predictions.R` — 9 cross-project targets
   - `llm/vignettes/telemetry.qmd` — Prediction Calibration section
   - GitHub issue llm#47 created and acceptance criteria checked off

### CI Status
- R-CMD-check: passing (24 min)
- github-install-test: was timing out at 45min, bumped to 60min
- Data Update / Storm Alert / R-universe: all passing
- Data Freshness Monitor: was failing (missing label), now fixed

### Known Issues
- `wave_rf_model` (731MB) not committed — needs LFS or CI-only rebuild
- `pointblank` available in nix env but nix-shell needs rebuild for current derivation
- R-CMD-check CI may still be slow on truly cold runs — johngavin cachix is the safety net

### Next Steps
- [ ] Coverage improvement for Silver quality gate
- [ ] Monitor cachix cache hit rate on next cold CI run
- [ ] Verify live site after next data-update deploy
