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
3. **Validation Tiers 1-3 + partial 5**: All checks pass

### CI Status
- All CI jobs pass: Test R-universe, API Drift Detection, R-CMD-check (on re-run)

### Remaining Validation Tiers
- **Tier 4**: Local pkgdown build + visual rendering check
- **Tier 6**: Post-deploy validation table
- **Tier 7-8**: Quality gate scoring + adversarial QA
- **Tier 9-11**: Final sign-off

### Known Issues
- `pointblank` not in nix env (prevents local devtools::document/check)
- R-CMD-check occasionally cancelled due to nix ICU build issue (intermittent, re-run fixes)
- `safe_tar_read()` pattern not yet adopted (vignettes use direct tar_load)
- wave_analysis.qmd: 7 inline `r expr` references (acceptable — simple variable lookups)
