# Current Work

## Branch: main
## Last Session: 2026-03-19

### What Was Done (This Session)
1. **Storm alert gust-trigger bug fixed**:
   - Alert triggered at Beaufort 8 because gusts (49.4 kn) exceeded 41 kn threshold
   - Root cause: `use_gusts = TRUE` default — gusts triggered alert even when sustained wind was below threshold
   - Fix: Changed `use_gusts` default to `FALSE` — only sustained wind speed triggers alerts
   - Also fixed outdated "weekly (Sundays 02:00 UTC)" → "every 6 hours" in email footer

### CI Status (all passing)
- R-CMD-check: passing ✓
- github-install-test: 2 min (RSPM) ✓
- R-universe: all platforms passing (incl. Windows) ✓
- Data Update: 30 min (6-hourly) ✓
- Storm Alert: threshold 41 kn sustained wind only (gusts excluded by default)

### Quality Gate Score
| Component | Score | Weight | Weighted |
|-----------|-------|--------|----------|
| Coverage | 85.8% | 25% | 21.5 |
| Check | 98 | 40% | 39.2 |
| Documentation | 100% | 20% | 20.0 |
| Defensive | 100% | 15% | 15.0 |
| **Total** | **95.7** | | **Gold** |

### Next Steps
- [ ] Add captions to api-usage.qmd (8 tables, 0 captions)
- [ ] Add source attribution to all captions (Marine Institute, ERDDAP)
- [ ] Add Quarto cross-references (@fig/@tbl) to all vignettes
- [ ] Open issues: #61 (Cancer InFocus patterns), llm#46, llm#47
