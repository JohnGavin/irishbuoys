# irishbuoys Memory

> Last updated: 2025-02-14
> Session count: 1

## Project Identity

### Package Name
irishbuoys

### Purpose
Provides tools to download, process, and analyze data from the Irish Weather Buoy Network. Includes functions for accessing real-time and historical data via the Marine Institute's ERDDAP server, storing data in DuckDB for efficient querying, and building predictive models for wave height and weather conditions.

### Data Sources
| Source | Type | Update Frequency | Notes |
|--------|------|------------------|-------|
| Marine Institute ERDDAP | API | Real-time + Historical | Primary data source |
| DuckDB (local) | Database | On-demand | Local storage for analysis |
| Parquet files | File | Cached | Pre-processed data |

### Key Stakeholders
- Research users analyzing wave patterns
- Maritime safety applications
- Climate researchers

---

## Domain Knowledge

### Key Concepts

#### Rogue Waves
Waves with height > 2x significant wave height (Hs). Detected using `rogue_ratio = hmax / wave_height`.

**Example**:
```r
# Detect rogue waves
detect_rogue_waves(data, threshold = 2.0)
```

#### Significant Wave Height (Hs)
The mean wave height of the highest third of waves. Stored as `wave_height` in data.

#### Wave Steepness
Ratio of wave height to wavelength. Indicates breaking potential.
```r
steepness = 2 * pi * wave_height / (g * wave_period^2)
```

### Data Semantics

| Column | Type | Units | Valid Range | Notes |
|--------|------|-------|-------------|-------|
| wave_height | numeric | meters | 0-30 | Significant wave height (Hs) |
| hmax | numeric | meters | 0-50 | Maximum wave height |
| wave_period | numeric | seconds | 1-25 | Peak wave period |
| wind_speed | numeric | m/s | 0-60 | 10-minute mean |
| gust | numeric | m/s | 0-80 | Max gust speed |
| atmospheric_pressure | numeric | hPa | 900-1100 | Sea level pressure |
| station_id | character | - | M2-M6 | Buoy identifier |

### Business Rules

1. **Rogue Wave Detection**: hmax/wave_height > 2.0 indicates rogue wave
   - Condition: Valid wave_height and hmax
   - Action: Flag event, calculate steepness

2. **Data Quality**: Minimum 100 rows for validation
   - Condition: Data frame has < 100 rows
   - Action: Return validation error

### Domain Constraints

- Wave period must be positive (physically impossible otherwise)
- Significant wave height <= hmax always
- Wind speed >= 0, gust >= wind_speed

---

## Technical Decisions

### Architecture Choices

#### Use DuckDB for analytics
- **Date**: 2024-01
- **Rationale**: Fast analytical queries on large datasets, Parquet integration
- **Alternatives considered**: SQLite (slower analytics), PostgreSQL (overkill)
- **Trade-offs**: Requires DuckDB extension, slightly more complex than SQLite

#### Modular targets plans
- **Date**: 2025-02
- **Rationale**: Separate pipeline components for data acquisition, QC, analysis
- **Location**: `R/tar_plans/plan_*.R`

#### Use pointblank for validation
- **Date**: 2024-02
- **Rationale**: Declarative data validation, integrates with targets
- **Function**: `validate_buoy_data()`

### Workarounds

#### Munsell package for Shinylive
- **Issue**: ggplot2 fails in WebR due to missing munsell dependency
- **Solution**: Use plotly instead, or explicitly install munsell first
- **Status**: Active workaround
- **Reference**: `vignettes/dashboard_shinylive.qmd`

### Dependencies

| Package | Version | Why | Alternatives |
|---------|---------|-----|--------------|
| duckdb | 0.9+ | Analytical queries | SQLite |
| arrow | 14+ | Parquet I/O | nanoparquet |
| pointblank | 0.11+ | Data validation | assertr |
| evd/extRemes | - | Extreme value analysis | mev |
| ranger | 0.14+ | Wave prediction models | randomForest |

---

## Session History

### Recent Sessions

#### Session 1 - 2025-02-14
**Focus**: Initial MEMORY.md creation

**Changes**:
- Created `.claude/MEMORY.md` from template
- Populated with irishbuoys-specific content

**Decisions Made**:
- Use plotly for Shinylive dashboards (munsell workaround)

**Open Items**:
- [x] Add adversarial tests based on /qa-package analysis (59 tests added)
- [x] Improve NULL handling in `calculate_wave_steepness` (all 8 functions fixed)
- [ ] Issue #8: Multi-page analytical vignette with parallel processing

---

## Lessons Learned

### What Works

1. **DuckDB + Parquet for large datasets**
   - Context: Historical buoy data (millions of rows)
   - Why: Fast queries, efficient storage
   - Example: `connect_duckdb()` + `query_buoy_data()`

2. **pointblank validation pipeline**
   - Context: Data quality checks
   - Why: Declarative, integrates with targets
   - Example: `validate_buoy_data(data, min_rows = 100)`

### What Failed

1. **ggplot2 in Shinylive**
   - Context: Dashboard visualization
   - Why it failed: WebR munsell dependency issue
   - Alternative: Use plotly for all interactive plots

### Gotchas

1. **ERDDAP rate limiting**: API may throttle heavy requests
   - Symptom: HTTP 429 errors
   - Fix: Add delays, cache locally

2. **DuckDB connection management**: Must close connections
   - Symptom: Locked database files
   - Fix: Use `DBI::dbDisconnect()` or `withr::defer()`

---

## Quick Reference

### Common Commands

```r
# Connect to database
con <- connect_duckdb("data/buoy_data.parquet")

# Query with filters
data <- query_buoy_data(con, station = "M3", start_date = "2024-01-01")

# Validate data
validate_buoy_data(data, min_rows = 100)

# Detect rogue waves
rogues <- detect_rogue_waves(data, threshold = 2.0)

# Close connection
DBI::dbDisconnect(con)
```

### File Locations

| Purpose | Location |
|---------|----------|
| R functions | `R/*.R` |
| Pipeline plans | `R/tar_plans/plan_*.R` |
| Tests | `tests/testthat/` |
| Vignettes | `vignettes/` |
| Data | `inst/extdata/` |

### Environment Variables

| Variable | Purpose | Example |
|----------|---------|---------|
| IN_NIX_SHELL | Check if in Nix | 1 |

---

## Contacts & Resources

### Documentation
- Marine Institute ERDDAP: https://erddap.marine.ie/
- Package vignettes: `vignettes/`

### Related Projects
- targets: Pipeline orchestration
- pointblank: Data validation

---

## Auto-Updated by /session-end

<!-- This section is automatically updated by /session-end -->

### Session Log
| Date | Duration | Focus | Changes |
|------|----------|-------|---------|
<!-- session-log-start -->
| 2026-02-14 | - | Defensive programming | Added NULL guards to 8 functions, 59 adversarial tests |
| 2025-02-14 | - | Initial setup | Created MEMORY.md |
<!-- session-log-end -->
