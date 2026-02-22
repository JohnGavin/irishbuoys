# Plan: Telemetry & Debug Vignette Overhaul

## Problem Statement

The current telemetry and debug vignettes have multiple issues:
1. Poor structure (confusing "Row" sections from dashboard layout)
2. Misleading data (3.7k rows instead of ~250k)
3. Unhelpful error messages ("not available")
4. Missing content (no explanation of what's being measured)
5. Article names don't match vignette titles

---

## Part 1: Understand Current Issues

### 1.1 Why "Row" Appears in Navigation

The telemetry.qmd uses Quarto Dashboard format (`format: dashboard`). In this format:
- `# Heading` = Page
- `## Row` = Layout row (NOT meant for navigation)
- `### Column` = Layout column

**Problem**: Dashboard row/column syntax creates confusing anchor links like `#row-1`, `#row-2`.

**Solution**: Either:
- A) Switch to standard HTML format with explicit tabsets
- B) Keep dashboard format but add explicit `{#page-name}` anchors

### 1.2 Why Database Shows 3.7k Rows

Likely causes:
1. Database hasn't been fully populated (only sample data)
2. Query is hitting wrong table
3. Data acquisition targets haven't run

**Solution**: Add explicit data health checks with expected vs actual counts.

### 1.3 Why QC Chart Shows Only 2 Months

The `telemetry_qc_trends` target likely:
1. Uses recent data window
2. Filters to specific date range
3. Database doesn't have historical data

**Solution**: Query full historical data, aggregate by month, add seasonal coloring.

---

## Part 2: Telemetry Vignette Purpose & Structure

### 2.1 Purpose

A telemetry vignette should answer: **"Is the project healthy?"**

Categories:
1. **Data Health**: Is data being collected? How much? Quality?
2. **Pipeline Health**: Are targets running? How fast? Errors?
3. **Code Health**: Test coverage? Check results? Documentation?
4. **Development Activity**: Commits? Issues? PRs?
5. **Validation**: pointblank reports embedded

### 2.2 Proposed Structure

```
# Overview (valueboxes: total rows, coverage, latest update)

# Data
  ## Coverage {.tabset}
    ### By Station
    ### By Time Period
    ### Freshness
  ## Quality {.tabset}
    ### QC Flag Distribution (5-year monthly, seasonal colors)
    ### Missing Data Patterns
    ### Anomaly Detection

# Pipeline
  ## Targets {.tabset}
    ### Summary (total, completed, errored, skipped)
    ### By Plan (table: plan_name, n_targets, total_size_mb, total_time_sec)
    ### Slowest Targets (top 10)
    ### Network Graph (link to tar_visnetwork)
  ## Timing {.tabset}
    ### Execution History
    ### Performance Trends

# Development
  ## Git Activity {.tabset}
    ### Commits (by month, by author)
    ### Issues (open/closed/by label)
    ### Pull Requests (merged/open)
    ### Branches (by version)
  ## Code Quality {.tabset}
    ### Test Coverage (covr by file)
    ### R CMD Check Results
    ### lintr Results

# Validation (embedded pointblank reports)
  ## analysis_data
    ### Report (iframe)
    ### Notes (explain pointblank)
  ## rogue_wave_events
    ### Report (iframe)
    ### Notes (explain targets)

# Session Info
```

---

## Part 3: Implementation Tasks

### Task 1: Fix Article Titles in _pkgdown.yml

Update vignette titles to match actual content:

| Current | New |
|---------|-----|
| Irish Weather Buoy Explorer | Irish Buoys Dashboard |
| Analysis | Wave Analysis |
| Pipeline Telemetry | Telemetry |
| Analysis Data Validation | Pointblank: Analysis Data |
| Rogue Wave Validation | Pointblank: Rogue Waves |

### Task 2: Update Vignette YAML Headers

Each vignette needs correct `title:` in YAML front matter.

### Task 3: Rewrite telemetry.qmd

**Format Decision**: Use HTML format with explicit panels, NOT dashboard format.

Reason: Dashboard format creates confusing row/column anchors and is designed for single-page apps, not multi-page documentation.

```yaml
---
title: "Telemetry"
format:
  html:
    toc: true
    toc-depth: 3
    toc-expand: 2
    number-sections: false
execute:
  echo: false
---
```

Use `::: {.panel-tabset}` for tabs instead of dashboard `{.tabset}`.

### Task 4: Fix Data Targets

Update `plan_telemetry.R` targets:

1. **telemetry_qc_trends**: Query full historical data, not just recent
2. **telemetry_db_info**: Add expected vs actual row count check
3. **telemetry_coverage_timeline**: 5-year view with seasonal coloring
4. Add new targets:
   - `telemetry_git_issues`: GitHub issues by status
   - `telemetry_git_prs`: Pull requests by status
   - `telemetry_coverage`: covr package coverage
   - `telemetry_target_by_plan`: Aggregate by plan file

### Task 5: Embed Validation Reports

Add pages to telemetry.qmd:
- `## Validation: Analysis Data`
- `## Validation: Rogue Waves`

Each with:
- iframe embedding the pointblank HTML
- "Notes" tabset explaining what validation checks

### Task 6: Rewrite debug.qmd

**Purpose**: Debug page answers: "Why isn't something working?"

**New Structure**:

```
# Debug Dashboard

## Current Status {.tabset}
  ### Pipeline Status (outdated targets, errors)
  ### Data Status (database exists? populated?)
  ### Environment Status (packages installed? versions?)

## Diagnostics {.tabset}
  ### Targets Errors (actual error messages)
  ### Missing Dependencies
  ### Configuration Issues

## Debug Actions
  ### How to Fix Common Issues
  ### Run tar_make()
  ### Rebuild Database

## Session Info
  ### R Session
  ### Package Versions
  ### Environment Variables
```

**"Not available" messages** should become:

```
❌ Validation reports not generated

**Why?** The targets pipeline hasn't been run successfully.

**What to do:**
1. Enter Nix shell: `./default.sh`
2. Run pipeline: `targets::tar_make()`
3. Refresh this page

**Common issues:**
- Database not initialized: Run `initialize_database()`
- DuckDB connection error: Check if another process has lock
- Missing packages: Re-enter Nix shell
```

### Task 7: Update Rules for Vignette Standards

Create/update `~/.claude/rules/quarto-files.md`:

```markdown
## Vignette Structure Standards

1. **Format**: Use `format: html` NOT `format: dashboard` for documentation
2. **Sections**: `#` = Page/major section
3. **Tabs**: Use `::: {.panel-tabset}` for related content
4. **Anchors**: Add explicit `{#section-name}` to avoid auto-generated anchors
5. **Pre-compute**: All data via `tar_load()`, never compute in vignette
```

---

## Part 4: Targets Modifications

### plan_telemetry.R Changes

```r
# New: Full historical QC trends (5 years, monthly, with season)
targets::tar_target(
  telemetry_qc_trends_full,
  {
    con <- connect_duckdb()
    on.exit(DBI::dbDisconnect(con))

    dplyr::tbl(con, "buoy_data") |>
      dplyr::collect() |>
      dplyr::mutate(
        month = lubridate::floor_date(time, "month"),
        season = dplyr::case_when(
          lubridate::month(time) %in% c(12, 1, 2) ~ "Winter",
          lubridate::month(time) %in% c(3, 4, 5) ~ "Spring",
          lubridate::month(time) %in% c(6, 7, 8) ~ "Summer",
          TRUE ~ "Autumn"
        )
      ) |>
      dplyr::group_by(month, season, qc_flag) |>
      dplyr::summarise(n = dplyr::n(), .groups = "drop")
  }
)

# New: Data health check with expected vs actual
targets::tar_target(
  telemetry_data_health,
  {
    con <- connect_duckdb()
    on.exit(DBI::dbDisconnect(con))

    # Calculate expected rows: ~6 years * 365 days * 24 hours * 6 stations
    expected_min <- 6 * 365 * 24 * 5  # ~260k minimum

    actual <- dplyr::tbl(con, "buoy_data") |>
      dplyr::count() |>
      dplyr::collect() |>
      dplyr::pull(n)

    tibble::tibble(
      expected_min = expected_min,
      actual = actual,
      pct_of_expected = round(100 * actual / expected_min, 1),
      status = if (actual >= expected_min * 0.8) "OK" else "LOW",
      message = if (actual < 10000) {
        "Database appears to have only sample data. Run initialize_database() to populate."
      } else if (actual < expected_min * 0.5) {
        "Database has less than 50% expected data. Check data acquisition."
      } else "Data coverage acceptable"
    )
  }
)

# New: Git issues summary
targets::tar_target(
  telemetry_git_issues,
  {
    tryCatch({
      issues <- gh::gh("GET /repos/{owner}/{repo}/issues",
        owner = "JohnGavin",
        repo = "irishbuoys",
        state = "all",
        per_page = 100
      )

      tibble::tibble(
        number = sapply(issues, `[[`, "number"),
        title = sapply(issues, `[[`, "title"),
        state = sapply(issues, `[[`, "state"),
        created = sapply(issues, `[[`, "created_at"),
        labels = sapply(issues, function(i) paste(sapply(i$labels, `[[`, "name"), collapse = ", "))
      )
    }, error = function(e) {
      tibble::tibble(number = integer(), title = character(), state = character())
    })
  }
)

# New: Targets grouped by plan
targets::tar_target(
  telemetry_targets_by_plan,
  {
    meta <- targets::tar_meta()

    meta |>
      dplyr::mutate(
        plan = dplyr::case_when(
          grepl("^evidence_", name) ~ "plan_evidence",
          grepl("^telemetry_|^table_telemetry_|^plot_telemetry_", name) ~ "plan_telemetry",
          grepl("^dashboard_|^caption_", name) ~ "plan_dashboard",
          grepl("^wave_|^rogue_|^extreme_", name) ~ "plan_wave_analysis",
          grepl("^joint_|^copula_", name) ~ "plan_joint_analysis",
          grepl("^code_|^src_", name) ~ "plan_doc_examples",
          grepl("^vignette_", name) ~ "plan_vignettes",
          TRUE ~ "other"
        )
      ) |>
      dplyr::group_by(plan) |>
      dplyr::summarise(
        n_targets = dplyr::n(),
        size_mb = round(sum(bytes, na.rm = TRUE) / 1024^2, 2),
        time_sec = round(sum(seconds, na.rm = TRUE), 1),
        .groups = "drop"
      ) |>
      dplyr::arrange(dplyr::desc(n_targets))
  }
)
```

---

## Part 5: Execution Order

| Phase | Task | Effort |
|-------|------|--------|
| 1 | Update _pkgdown.yml article titles | Low |
| 2 | Update vignette YAML headers | Low |
| 3 | Add new targets to plan_telemetry.R | Medium |
| 4 | Rewrite telemetry.qmd structure | High |
| 5 | Rewrite debug.qmd with actionable messages | Medium |
| 6 | Update quarto-files.md rules | Low |
| 7 | Test and rebuild site | Medium |

---

## Part 6: Validation

After implementation:

1. `tar_validate()` passes
2. `tar_make()` runs without errors
3. `pkgdown::build_site()` succeeds
4. All pages render correctly
5. No "Row" anchors in navigation
6. Database shows ~250k rows (after full data load)
7. QC chart shows 5-year trend

---

## Approval Requested

Please review this plan. Key decisions needed:

1. **Format**: Switch telemetry from `dashboard` to `html` format? (Recommended: Yes)
2. **Embed validation**: As iframe in telemetry or keep separate pages?
3. **Git metrics**: Include GitHub issues/PRs via gh API? (Requires token)
4. **covr coverage**: Include in telemetry? (Adds dependency)
5. **Debug page**: Keep as dashboard or switch to html?

Reply with approval or modifications.
