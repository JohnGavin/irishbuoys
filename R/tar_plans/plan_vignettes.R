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
#'
#' @name plan_vignettes
NULL

plan_vignettes <- list(


  # Dashboard Static - Main dashboard with all buoy data
  # Dependencies: dashboard_buoy_data, dashboard_stats, dashboard_timeseries
  tarchetypes::tar_quarto(
    vignette_dashboard_static,
    path = "vignettes/dashboard_static.qmd",
    packages = c("dplyr", "ggplot2", "plotly", "DT", "dygraphs", "xts", "tidyr")
  ),

# Wave Analysis - Extreme value analysis and rogue waves
  # Dependencies: analysis_data, rogue_wave_events, return_levels, joint_analysis_results
  tarchetypes::tar_quarto(
    vignette_wave_analysis,
    path = "vignettes/wave_analysis.qmd",
    packages = c("dplyr", "ggplot2", "plotly", "DT", "dygraphs", "xts", "tidyr", "targets")
  ),

  # Telemetry - Pipeline metrics and performance tracking
  # Dependencies: telemetry_summary
  tarchetypes::tar_quarto(
    vignette_telemetry,
    path = "vignettes/telemetry.qmd",
    packages = c("dplyr", "ggplot2", "DT", "targets")
  ),

  # Debug - Debugging helper (minimal dependencies)
  tarchetypes::tar_quarto(
    vignette_debug,
    path = "vignettes/debug.qmd",
    packages = c("dplyr", "targets")
  )

  # NOTE: dashboard_shinylive.qmd is NOT included as a target because:
  # - It uses webr::install() which requires browser environment
  # - Shinylive compilation needs special handling
  # - It should be built manually with: quarto render vignettes/dashboard_shinylive.qmd
)
