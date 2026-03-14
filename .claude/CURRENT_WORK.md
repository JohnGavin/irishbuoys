# Current Work

## Branch: main
## Last Session: 2026-03-14

### What Was Done
1. **Live site bug fixes** (commit `8c9dc7d`):
   - `hoverinfo = "text"` added to 7 inline plots in wave_analysis.qmd (M2-M6 rogue events, RF scatter, RF residuals)
   - Dashboard hoverlabel: replaced `hovertemplate` with `text`+`hoverinfo`, `bgcolor` white→`rgba(0,0,0,0.9)`
   - `missing_data_grid` target: now derives from `analysis_data` (full 6-yr history) instead of DuckDB (was only 31 days)
   - CSS: `abbr { cursor: default; text-decoration: none; }` — metric column no longer looks clickable
   - Gust factor table: `targets = numeric_cols` (was `as.list()`), removed fixed `width = "200px"`
2. **9-step workflow validation**:
   - `devtools::document()` → OK (pure nix-shell)
   - `devtools::test()` → 878 PASS, 0 FAIL, 15 SKIP (53.7s)
   - `devtools::check()` → 0 errors, 0 warnings, 1 NOTE (inst dir, pre-existing)
   - Cachix push: irishbuoys pushed (74.54 MiB) + fontconfig-2.17.1-lib (377 KiB) — strict limit is 1, fontconfig was new dep
3. Previous session fixes (commits `ec56be5`, `979ab91`): legend/hoverlabel theme, return level dotplots, DT nowrap, captions

### CI Status
- Pushed `8c9dc7d` to main
- R-CMD-check: cancelled (exceeded 20min CI timeout — nix build time, not code failure)
- API Drift Detection: success
- Test R-universe: in-progress
- Next data-update (6-hourly) will deploy vignette changes to live site

### Known Issues
- R-CMD-check CI timeout (20min) — nix env build takes too long on fresh runners
- `pointblank` available in nix env but nix-shell needs rebuild for current derivation
- `wave_rf_model` (731MB) not committed — needs LFS or CI-only rebuild
- Cachix push_to_cachix.sh strict=1 path violated by fontconfig dep — update script or pre-cache

### Next Steps
- [ ] Verify live site after next data-update deploy:
  - Hover rogue wave plots → black hoverlabel bg
  - Hover dashboard plots → black hoverlabel bg
  - total_days → ~2700 (not 31)
  - Metric names → default cursor (not pointer)
  - Gust factor table → right-justified, auto-width
- [ ] Fix R-CMD-check CI timeout (cache nix env, or increase timeout)
- [ ] Coverage improvement for Silver quality gate
