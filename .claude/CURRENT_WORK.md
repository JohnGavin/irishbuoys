# Current Work

## Branch: main
## Last Session: 2026-03-11

### What Was Done
1. **Wave analysis vignette enhancements** (commit `da784e8`): Plotly legend/layout fixes (irishbuoys_layout), click-to-zoom CSS/JS, tab height fixes, disclaimer, glossary tooltips, external links, Model Summary tab, cross-links, column renames (days_wave_obs etc.)
2. **API Tier 1-3 + Plumber parity** (commits `c6149e6`..`0d954cc`): 16 API routes, methods endpoint, CI comparison
3. **CI fix: api_vignette_stats_dt** (commit `14b0a8a`): station_stats was a data frame not a named list; used dplyr::transmute() instead of $ on atomic vectors
4. **CI fix: api_vignette_rogue_waves_dt** (in API Tier 1 commit): fixed hmax_hs_ratio → rogue_ratio column name
5. **Email staleness feature** (commit `0eb9ad4`): Added report_composed timestamp, staleness_hours, staleness_alert (>18h) to ingestion stats table in weekly email

### CI Status
- Run `22978696222` in progress (commit `14b0a8a`), includes api_vignette_stats_dt fix
- Email staleness commit (`0eb9ad4`) is on main but not yet in this CI run — will be picked up next scheduled run or manual trigger

### Next Steps
- Verify CI run `22978696222` passes (monitor or check next session)
- If CI passes, trigger new run with latest commit to verify email staleness feature
- Continue plan items from `noble-humming-charm.md` (A1 metric hover tooltips, A11 cross-links, A4+B5 caption audit)
- Review remaining 79 test warnings
