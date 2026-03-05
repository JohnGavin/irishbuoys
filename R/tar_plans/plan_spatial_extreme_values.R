#' Targets Plan: Spatial Extreme Value Analysis
#'
#' This plan computes pairwise extremal dependence (H1) and fits an
#' illustrative max-stable process model across the buoy network.
#' Depends on `analysis_data` from `plan_wave_analysis`.
#'
#' @name plan_spatial_extreme_values
NULL

plan_spatial_extreme_values <- list(

  # H1: Pairwise extremal dependence via Gumbel copula
  # Returns dependence_table with lambda_U, bootstrap CIs, chi statistics
  targets::tar_target(
    spatial_extremal_dependence,
    compute_extremal_dependence(
      data = analysis_data,
      variable = "wave_height",
      n_bootstrap = 100,
      boot_subsample = 5000
    )
  ),

  # Extract the dependence summary table for dashboards/vignettes
  targets::tar_target(
    spatial_dependence_table,
    spatial_extremal_dependence$dependence_table
  ),

  # Max-stable process (illustrative — 5 stations is below minimum)
  targets::tar_target(
    spatial_maxstable_fit,
    fit_spatial_maxstable(
      data = analysis_data,
      variable = "wave_height",
      min_years = 5
    )
  ),

  # Combined spatial EVT results for vignettes
  targets::tar_target(
    spatial_evt_results,
    list(
      dependence = spatial_extremal_dependence,
      maxstable = spatial_maxstable_fit,
      n_pairs = nrow(spatial_dependence_table),
      n_h1_significant = sum(spatial_dependence_table$h1_significant, na.rm = TRUE),
      maxstable_fitted = spatial_maxstable_fit$fitted
    )
  )
)
