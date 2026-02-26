# fix_033.R - Per-Station GPD Return Levels (Issue #33)
# Date: 2026-02-25
#
# Replace pooled GEV return levels with per-station GPD fits for
# 4 variables: avg wave, rogue wave, avg wind, wind gust.
# Return periods changed from 10/50/100yr to 1/5/10yr.
#
# Files Modified:
# - R/extreme_values.R: Added calculate_gpd_return_levels()
# - R/plot_functions.R: Added create_plot_return_levels_per_station()
# - R/tar_plans/plan_wave_analysis.R: Added gpd_gust_per_station,
#     return_levels_per_station, 4 plot targets; updated analysis_summary
# - R/tar_plans/plan_api.R: Replaced api_return_levels with per-station JSON
# - R/tar_plans/plan_dashboard.R: Added dashboard_return_levels target
# - R/api_static.R: Updated return-levels.json description
# - R/tar_plans/plan_vignettes.R: Added quiet=FALSE for debug output
# - vignettes/wave_analysis.qmd: Rewrote "Extreme Value Views" tabset
#     with per-station tabs; fixed tar_load for new targets; fixed plotly
#     inherit=FALSE for rf-actual-vs-predicted chunk
# - vignettes/dashboard_static.qmd: Added "Forecasts" page
# - tests/testthat/test-extreme-values.R: Added 3 tests for
#     calculate_gpd_return_levels (valid, shape=0, error fit)
# - tests/testthat/test-plot-functions.R: Added tests for
#     create_plot_return_levels_per_station (NULL, missing var, valid)
#
# Verification:
#   devtools::document()  # NAMESPACE + man pages OK
#   devtools::test()      # 546/546 pass
#   devtools::check()     # 0 errors, 0 warnings, 2 notes
#   targets::tar_make()   # All targets build incl vignettes
#   Adversarial QA: 20/20 (after string-input guard added)
