# Fix #28: Articles index titles, sections, and telemetry vignette layout
#
# Issue: https://github.com/JohnGavin/irishbuoys/issues/28
# Branch: fix-issue-28-articles-telemetry
#
# Root Cause:
#   1. docs/articles/index.html was a hand-crafted HTML file with
#      hardcoded titles that did not match actual vignette titles.
#   2. vignettes/telemetry.qmd used format: dashboard which renders
#      "Row"/"Column" labels in pkgdown instead of proper layout.
#
# Changes:
#
# 1. docs/articles/index.html:
#    - "Irish Weather Buoy Explorer" -> "Irish Buoys Explorer"
#    - "Comprehensive Wave Analysis" -> "Irish Buoys Analysis"
#    - Removed "Analysis" section heading (merged into Dashboards)
#    - "Pipeline Telemetry" -> "Telemetry" (moved to Data Quality section)
#    - Removed "Technical" section heading
#    - "Data Quality (pointblank)" -> "Data Quality"
#    - "Analysis Data Validation" -> "analysis_data Validation"
#    - "Rogue Wave Validation" -> "rogue_wave_events Validation"
#    - Reviewed and condensed all bullet point descriptions
#
# 2. vignettes/telemetry.qmd:
#    - Changed format: dashboard -> format: html
#    - Value boxes replaced with knitr::kable() summary table
#    - Dashboard cards/rows/columns replaced with standard sections
#    - Tabsets use ::: {.panel-tabset} (html-compatible)
#    - Pipeline timing rendered as table instead of bullet list
#    - Test types rendered as markdown table
#    - Validation reports consolidated into single section with iframes
#
# 3. vignettes/dashboard_static.qmd:
#    - title: "Irish Buoys" -> "Irish Buoys Explorer"
#
# 4. _pkgdown.yml:
#    - Removed "Analysis" section (wave_analysis merged into Dashboards)
#    - Renamed "Monitoring" -> "Data Quality"
#    - Removed "internal" entry for dashboard_shinylive (keep internal)
#
# Result:
#   Articles index titles match actual vignette titles.
#   Telemetry renders as clean HTML with tables instead of broken dashboard.
