# Fix #15: Display RF model predictions in wave_analysis vignette
#
# Issue: https://github.com/JohnGavin/irishbuoys/issues/15
# Branch: feat/issue-15-rf-predictions
# Date: 2026-02-15
#
# Changes:
#   1. R/tar_plans/plan_wave_analysis.R
#      - Added 4 targets: wave_features, wave_rf_model, wave_rf_eval, wave_rf_report
#      - Uses prepare_wave_features(), train_wave_model(), evaluate_wave_model(),
#        wave_model_report() from R/wave_model.R
#
#   2. vignettes/wave_analysis.qmd
#      - Added "Predictions" page between "Joint Analysis" and "Reference"
#      - Loads RF targets with tryCatch (graceful fallback if not built)
#      - 4 valueboxes: R-squared, RMSE, MAE, N_test
#      - Actual vs Predicted scatter (plotly, colored by wave category)
#      - Residuals by category boxplot
#      - Feature importance horizontal bar (top 10)
#      - Performance by category DT table
#      - Model report text output
#
# Model performance (265K observations, 13 predictors, 500 trees):
#   Training R-squared: 0.986
#   Test R-squared:     0.983
#   Test RMSE:          0.223 m
#   Test MAE:           (see wave_rf_eval$overall)
#
# Verification:
#   - tar_validate(): PASS
#   - tar_make(wave_rf_*): all 4 targets completed
#   - devtools::document(): OK
#   - devtools::test(): 72 PASS, 0 FAIL, 2 SKIP
#   - devtools::check(--as-cran): 0 errors, 0 warnings, 1 NOTE
#   - quarto render wave_analysis.qmd: 95/95 chunks, OK
