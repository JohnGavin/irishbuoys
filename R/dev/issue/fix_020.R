# Fix #20: Reach Silver quality gate (>=90) via test coverage >=63%
#
# Issue: https://github.com/JohnGavin/irishbuoys/issues/20
# Branch: fix-issue-20-silver-quality-gate
#
# Root Cause:
#   Quality gate score was 84.7 (Bronze). Coverage was 50.55%, well below
#   the 63% needed for Silver (>=90).
#
# Changes:
#
# 1. tests/testthat/test-plotly-helpers.R (NEW):
#    - 8 tests for irishbuoys_layout() and irishbuoys_ggplotly()
#    - Tests gray 70 theme, title handling, ggplot conversion
#    - Coverage: 0% -> 100%
#
# 2. tests/testthat/test-plot-functions.R (NEW):
#    - 45+ tests covering all 15 create_plot_*() functions
#    - NULL guard tests + positive tests with synthetic data
#    - Coverage: 0% -> 100%
#
# 3. tests/testthat/test-database-parquet.R (NEW):
#    - 14 tests for init, save, query, incremental update, analyze
#    - All use tempdir() for file I/O isolation
#    - Coverage: 0% -> 80.72%
#
# 4. tests/testthat/test-erddap-client.R (NEW):
#    - 10 tests for download_buoy_data, get_stations, get_latest_timestamp
#    - Network-resilient: skips when ERDDAP unreachable
#    - Coverage: 0% -> 2.35% (limited by network dependency)
#
# Result:
#   Overall coverage: 50.55% -> 75.67%
#   Quality gate: Bronze (84.7) -> Silver (>=90)
#   Tests: 411 -> 498 (87 new tests, 0 failures)
#
# Verification:
#   devtools::document()  # No changes
#   devtools::test()      # 498 pass, 0 fail
#   devtools::check()     # 0 errors, 0 warnings, 2 notes (benign)
