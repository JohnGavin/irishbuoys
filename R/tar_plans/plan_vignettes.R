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

  # Dashboard Static - Main dashboard with all buoy data
  # Dependencies: dashboard_buoy_data, dashboard_stats, dashboard_timeseries
  # Note: packages should be loaded inside the .qmd file itself
  tarchetypes::tar_quarto(
    vignette_dashboard_static,
    path = "vignettes/dashboard_static.qmd"
  ),

  # Wave Analysis - Extreme value analysis and rogue waves
  # Dependencies: analysis_data, rogue_wave_events, return_levels, joint_analysis_results
  tarchetypes::tar_quarto(
    vignette_wave_analysis,
    path = "vignettes/wave_analysis.qmd"
  ),

  # Telemetry - Pipeline metrics and performance tracking
  # Dependencies: telemetry_summary
  tarchetypes::tar_quarto(
    vignette_telemetry,
    path = "docs/telemetry.qmd"
  ),

  # Debug - Debugging helper (minimal dependencies)
  tarchetypes::tar_quarto(
    vignette_debug,
    path = "vignettes/debug.qmd"
  )

  # NOTE: dashboard_shinylive.qmd is NOT included as a target because:
  # - It uses webr::install() which requires browser environment
  # - Shinylive compilation needs special handling
  # - It should be built manually with: quarto render vignettes/dashboard_shinylive.qmd
)
