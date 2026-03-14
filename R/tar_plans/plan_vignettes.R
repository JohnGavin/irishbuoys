#' Targets Plan: Vignette Rendering
#'
#' This plan ensures all vignettes are rendered reproducibly via targets.
#' MANDATORY: All vignettes must be rendered through targets for reproducibility.
#'
#' @details
#' Each vignette:
#' - Loads pre-computed data via tar_load()/tar_read()
#' - Does NOT compute anything inline (except trivial formatting)
#' - Is tracked as a target so changes trigger re-rendering
#' - Loads R packages inside the Quarto report (not via tar_quarto packages arg)
#'
#' @name plan_vignettes
NULL

plan_vignettes <- list(

  # Dashboard Static
  tarchetypes::tar_quarto(
    vignette_dashboard_static,
    path = "vignettes/dashboard_static.qmd",
    quiet = FALSE
  ),

  # Wave Analysis - Extreme value analysis and rogue waves
  # Dependencies: analysis_data, rogue_wave_events, return_levels, joint_analysis_results
  tarchetypes::tar_quarto(
    vignette_wave_analysis,
    path = "vignettes/wave_analysis.qmd",
    quiet = FALSE
  ),

  # Telemetry - Pipeline metrics and performance tracking
  # Dependencies: telemetry_summary
  tarchetypes::tar_quarto(
    vignette_telemetry,
    path = "vignettes/telemetry.qmd",
    quiet = FALSE
  ),

  # Static Data API - Endpoint documentation
  # Dependencies: api_index, api_vignette_endpoints_dt, save_api_files
  tarchetypes::tar_quarto(
    vignette_api_usage,
    path = "vignettes/api-usage.qmd",
    quiet = FALSE
  ),

  # Spatial Extremes - Max-stable processes and spatial EVT
  # Dependencies: spatial_extremal_dependence, spatial_maxstable_fit, spatial_evt_results
  tarchetypes::tar_quarto(
    vignette_spatial_extremes,
    path = "inst/articles/spatial_extremes.qmd",
    quiet = FALSE
  )

  # NOTE: dashboard_shinylive.qmd is NOT included as a target because:
  # - It uses webr::install() which requires browser environment
  # - Shinylive compilation needs special handling
  # - It should be built manually with: quarto render vignettes/dashboard_shinylive.qmd
)
