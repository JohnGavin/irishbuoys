# Current Work

## Branch: main
## Last Session: 2026-03-17

### What Was Done
1. **Dashboard rollback + incremental restore** (#64, closed):
   - Rolled back CSS that broke dygraphs (`overflow:visible` on `.card-body`)
   - Re-added 4 features with deploy+verify: white captions, DT helper, click-to-zoom JS, DT nowrap
   - Added safe tab scrollbar CSS (`overflow-y:auto; max-height:80vh` on `.tab-pane`)
   - Fixed same dangerous CSS in wave_analysis.qmd

2. **Telemetry captions** (0/31 → 31/31):
   - Updated `create_telemetry_dt()` to use `htmltools::tags$caption()` with white text
   - Changed all `caption-side: bottom` → `top`
   - Enhanced all 15 table captions with variable definitions, units, source
   - Added captions to 4 inline kable/DT tables in telemetry.qmd
   - 3 prediction table captions enhanced

3. **Coverage timeline** removed (useless plot)

4. **@examples** added to 35 functions (68 → 91/117 exports)

5. **Storm alert threshold** raised: Beaufort 8 (34kn) → Beaufort 9 (41kn)
   - Fixed test that used old threshold value

6. **CI fixes** (github-install-test: >45min timeout → 2 min):
   - Root cause: `repos = "https://cloud.r-project.org"` forced source compilation
   - Fix: Use RSPM env var from `setup-r` for pre-compiled Linux binaries
   - Also fixed: missing CRAN mirror, missing GITHUB_PAT, missing auth_token

7. **Forecasts Method tab**: removed false "95% CI via delta method" claim
8. **wave_analysis key metrics**: converted to sortable DT::datatable

### Quality Gate Score
| Component | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Coverage | 85.8% | 25% | 21.5 |
| Check | 98 | 40% | 39.2 |
| Documentation | 100% | 20% | 20.0 |
| Defensive | 100% | 15% | 15.0 |
| **Total** | **95.7** | | **Gold** |

### CI Status (both passing)
- R-CMD-check: 13 min, 0E/0W/2N
- github-install-test: 2 min (RSPM binaries)
- Data Update: 30 min (6-hourly)

### Next Steps
- [ ] Add captions to api-usage.qmd (8 tables, 0 captions)
- [ ] Add source attribution to all captions (Marine Institute, ERDDAP)
- [ ] Add Quarto cross-references (@fig/@tbl) to all vignettes
- [ ] Consider optimising `spatial_extremal_dependence` target (15 min, 48% of pipeline)
- [ ] Open issues: llm#46 (socviz comparison), llm#47 (prediction follow-ups)
