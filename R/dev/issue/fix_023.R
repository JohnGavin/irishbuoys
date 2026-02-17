# Fix #23: Vignette formatting overhaul
# Gray 70 theme, heading renames, delete debug.qmd
#
# Issue: https://github.com/JohnGavin/irishbuoys/issues/23
# Branch: fix-issue-23-vignette-overhaul
#
# Changes:
#
# 1. R/plotly_helpers.R - irishbuoys_layout() theme:
#    - plot_bgcolor/paper_bgcolor: "black"/"#1a1a1a" -> "#B3B3B3" (gray 70)
#    - gridcolor: "white" -> "#666666"
#    - zerolinecolor: "white" -> "#333333"
#    - All font colors: "white" -> "#1a1a1a"
#    - Legend: bgcolor="#D9D9D9", bordercolor="#999999"
#    Fixes 16+ plotly plots globally.
#
# 2. R/plot_functions.R - create_plot_stl() ggplot theme:
#    - Added gray 70 panel/plot background, dark text/grid
#
# 3. vignettes/dashboard_static.qmd:
#    - Inline Wind vs Wave ggplot: black -> gray 70 theme
#    - Renamed ~16 generic "## Row"/"### Column" headings
#      to descriptive: "## Time Series", "## Station Comparison",
#      "## Scatter Analysis", "## Data Table", "## Technical Reference", etc.
#
# 4. vignettes/wave_analysis.qmd:
#    - Renamed ~20 generic headings to descriptive names
#    - Changed Column width splits (60%/40%) to full width (100%)
#    - Named blank ##### {.tabset} headings
#
# 5. vignettes/debug.qmd - DELETED
#    - Broken code (orphaned ")"), all placeholder text
#    - Fundamentally requires targets pipeline unavailable during pkgdown build
#
# 6. _pkgdown.yml:
#    - Removed "debug" from Monitoring section
#
# 7. vignettes/telemetry.qmd:
#    - Verified already compliant (descriptive headings with anchors)
#
# Verification:
#   devtools::document()  # Updated irishbuoys_layout.Rd
#   devtools::test()      # 0 failures, 411 passed
#   devtools::check()     # 0 errors, 0 warnings, 2 notes (benign)
