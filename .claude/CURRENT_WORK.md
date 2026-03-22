# Current Work

## Branch: main
## Last Session: 2026-03-22

### What Was Done
1. **Email formatting improvements**:
   - Missing hours color-coded by severity (>150h large red, >100h red, >50h orange, >0h amber, 0 green)
   - Extreme events renamed "Rogue and high waves (last week, reverse time order)", limited to top half
   - Removed duplicate section headings (inner `<h2>` when `<details><summary>` already has title)
   - Default email font size 18px
   - Fixed test in both test-coverage-boost.R and test-adversarial-email.R

2. **Data-update pipeline fix** (from previous session):
   - M3 ERDDAP outage (<30% coverage) was aborting entire pipeline
   - Changed `cli_abort()` → `cli_warn()` so pipeline continues with available stations
   - Downgraded email freshness check from `stop()` → `warning()` for recovery

3. **deslop skill installed** (global, ~/.claude/skills/deslop/):
   - 10 core rules for removing AI writing patterns from prose
   - 4 project-specific overrides: captions MUST have units/source, values MUST be dynamic in captions AND prose, code quality paramount, plain bullets allowed
   - Reference catalogs: 215 phrases, 257 structures, 326 tropes, 179 examples
   - New rule: `dynamic-prose-values` (mandatory, no exceptions)
   - CLAUDE.md updated: 61 skills, new "Prose Quality" category

### CI Status
- R-CMD-check: passing (after test fix for renamed heading)
- github-install-test: transient GitHub API download failures
- R-universe: all platforms passing
- Data Update: passing (M3 outage handled gracefully)

### Quality Gate: Gold (95.7)
- Coverage: 85.8%, Check: 0E/0W, Tests: 1074 pass

### Next Steps
- [ ] Add captions to api-usage.qmd (8 tables, 0 captions)
- [ ] Add source attribution to all captions
- [ ] Apply deslop skill to existing vignette prose
- [ ] Open issues: #61 (Cancer InFocus), llm#46, llm#47
