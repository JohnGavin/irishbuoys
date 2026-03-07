# Fix #8: Analysis vignette — scoped-down increment
#
# Original spec called for outlier_detection.R, Mann-Kendall trend test,
# ACF/PACF for individual stations, plan_analysis_vignette.R, and a
# multi-page analysis vignette. This increment adds 3 analysis functions
# to existing files without creating new vignettes.
#
# What was added (this commit):
#
# 1. detect_outliers_iqr() — IQR-based outlier detection
#    File: R/trend_analysis.R
#    Returns input data with is_outlier logical column.
#    Simple global IQR; sliding window version deferred.
#
# 2. mann_kendall_test() — non-parametric trend test
#    File: R/trend_analysis.R
#    Uses stats::cor.test(method = "kendall") on (time_index, variable).
#    Returns list(tau, p_value, trend_direction).
#
# 3. compute_acf_summary() — ACF as tibble
#    File: R/trend_analysis.R
#    Wraps stats::acf(), returns tibble(lag, acf). Excludes lag-0.
#
# 4. Three new targets in plan_wave_analysis.R:
#    - wave_outliers_iqr
#    - wave_mann_kendall
#    - wave_acf_summary
#
# 5. Tests for all 3 functions in test-trend-analysis.R
#
# NOT included (future issues):
# - Multi-page analysis vignette
# - Sliding window outlier detection
# - Per-station ACF/PACF
# - GAM/ARIMA models
# - crew parallelism for analysis
