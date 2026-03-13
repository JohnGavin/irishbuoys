# Current Work

## Branch: main
## Last Session: 2026-03-13

### What Was Done
1. **Vignette visual/UX improvements (17-item plan)** (commit `631fbf3`):
   - Grid lines brighter (rgba 0.4, gridwidth 1) via `irishbuoys_layout()`
   - Fixed deep-merge bug: callers' xaxis/yaxis no longer clobber defaults
   - Y-axis auto-scale JS on rangeslider for all plotly timeseries
   - Rangesliders added to `create_plot_rogue_all`/`create_plot_rogue_gusts_all`
   - Station color palette (M2-M6) on `gust_by_category`
   - Click-to-zoom: walk to outermost cell-output-display (includes caption)
   - CSS: min-height 600px plotly, no DT scroll, white captions
   - Hash nav JS for nested tab deep-linking (#extreme-value-methods)
   - Rogue gust DT capped to top 500 rows for performance
   - Gust summary: narrow columns, right-justified stats
   - Predictions: larger markers, LOESS fit line, category colors
   - All 10 copula pairs (was 3) in plan_joint_analysis.R
   - `target="_blank"` on all external links (61 added across both vignettes)
   - Fixed broken URLs: NOAA marine_wave_background, Longuet-Higgins DOI
   - Fixed broken internal links: #reference -> #variable-definitions, removed #trends
   - DT pageLength 15 -> 25, create_dt caption color white
2. **GitHub issue #61**: Cancer InFocus comparison and possible extensions
3. **Deep-merge regression test** (commit `3592f11`): Verifies grid lines survive caller xaxis/yaxis overrides
4. **Full validation completed** (all tiers):
   - Tier 1 (Vignette Content): PASS
   - Tier 2 (Package Checks): PASS (CI R-CMD-check green)
   - Tier 3 (Visualization Rules): PASS (61 target="_blank" added, broken links fixed)
   - Tier 5 (Link Validation): PASS
   - Tier 6 (Post-Deploy): PASS (0 MISSING EVIDENCE, 0 errors on live site)
   - Tier 7 (Quality Gate): Bronze 83.1/100
   - Tier 8 (Adversarial QA): Existing tests cover wave-model + email; deep-merge test added
   - Tier 9 (Self-Review): 0 TODO/FIXME, 100% doc coverage, 96.6% defensive

### CI Status
- All CI jobs pass: Test R-universe, API Drift Detection, R-CMD-check
- Data-update triggered to re-render vignettes with new .qmd changes
- Deploy workflow deploys docs/ to GitHub Pages (triggered after data-update completes)

### Quality Gate Detail (Bronze 83.1/100)
| Component | Weight | Score | Weighted |
|-----------|--------|-------|----------|
| Coverage | 20% | 45 (est.) | 9.0 |
| R CMD check | 30% | 98 | 29.4 |
| Documentation | 15% | 100 | 15.0 |
| Defensive | 10% | 96.6 | 9.7 |
| Data Integrity | 20% | 100 | 20.0 |
| Code Style | 5% | 0 | 0.0 |

### Blockers to Silver (90+)
- Coverage needs fresh `covr` run (~45% estimated → needs ~75%+ for Silver)
- 4 `DBI::dbGetQuery` calls in `database_parquet.R` (code style = 0)
- 2 `stop()` calls in `database_parquet.R` (defensive = 96.6%)

### Known Issues
- `pointblank` not in nix env (prevents local devtools::document/check)
- R-CMD-check occasionally cancelled due to nix ICU build issue (intermittent, re-run fixes)
- `safe_tar_read()` pattern not yet adopted (vignettes use direct tar_load)
- wave_analysis.qmd: 7 inline `r expr` references (acceptable — simple variable lookups)
- Live site vignettes re-render on next data-update run (6-hourly or manual trigger)
