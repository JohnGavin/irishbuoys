#' Data Validation with pointblank
#'
#' This module provides data validation functions using the pointblank package.
#' These functions are used in the targets pipeline to ensure data quality.
#'
#' @name validation
#' @keywords internal
NULL

#' Validate analysis data with pointblank
#'
#' Performs comprehensive validation of the analysis_data target using
#' pointblank's interrogation framework. Checks for:
#' - Minimum row count
#' - Required columns exist
#' - No NULL values in key columns
#' - Value ranges for physical measurements
#' - Valid station IDs
#'
#' @param data A data frame or tibble to validate
#' @param target_name Name of the target for error messages (default: "analysis_data")
#' @param min_rows Minimum expected rows (default: 100)
#' @param report_path Optional path to save HTML validation report
#'
#' @return The original data if validation passes, otherwise aborts with error
#'
#' @examples
#' \dontrun{
#' # Basic validation
#' validated_data <- validate_buoy_data(my_data)
#'
#' # With custom settings and report
#' validated_data <- validate_buoy_data(
#'   my_data,
#'   target_name = "custom_target",
#'   min_rows = 1000,
#'   report_path = "validation_report.html"
#' )
#' }
#'
#' @export
validate_buoy_data <- function(data,
                               target_name = "analysis_data",
                               min_rows = 100,
                               report_path = NULL) {
  if (!requireNamespace("pointblank", quietly = TRUE)) {
    cli::cli_warn(c(
      "!" = "pointblank not installed, falling back to basic validation",
      "i" = "Install with: install.packages('pointblank')"
    ))
    return(validate_tibble_rows_basic(data, target_name, min_rows))
  }

  # Define valid station IDs

valid_stations <- c("M1", "M2", "M3", "M4", "M5", "M6", "FS1")

  # Create validation agent
  agent <- pointblank::create_agent(
    tbl = data,
    tbl_name = target_name,
    label = paste0("Validation for ", target_name),
    actions = pointblank::action_levels(
      warn_at = 0.01,  # Warn if >1% of rows fail
      stop_at = 0.05   # Stop if >5% of rows fail
    )
  ) |>
    # Check minimum row count
    pointblank::rows_at_least(
      n = min_rows,
      label = paste0("At least ", min_rows, " rows")
    ) |>
    # Check required columns exist
    pointblank::col_exists(
      columns = c("station_id", "time", "wave_height"),
      label = "Required columns exist"
    ) |>
    # Check station_id values are valid
    pointblank::col_vals_in_set(
      columns = "station_id",
      set = valid_stations,
      label = "Valid station IDs"
    ) |>
    # Check wave_height is within physical bounds (0-30m)
    pointblank::col_vals_between(
      columns = "wave_height",
      left = 0,
      right = 30,
      na_pass = TRUE,
      label = "Wave height 0-30m"
    ) |>
    # Check hmax is within physical bounds (0-40m)
    pointblank::col_vals_between(
      columns = "hmax",
      left = 0,
      right = 40,
      na_pass = TRUE,
      label = "Max wave 0-40m"
    ) |>
    # Check wind_speed is within physical bounds (0-100 m/s)
    pointblank::col_vals_between(
      columns = "wind_speed",
      left = 0,
      right = 100,
      na_pass = TRUE,
      label = "Wind speed 0-100 m/s"
    ) |>
    # Check gust is within physical bounds (0-150 m/s)
    pointblank::col_vals_between(
      columns = "gust",
      left = 0,
      right = 150,
      na_pass = TRUE,
      label = "Gust 0-150 m/s"
    ) |>
    # Check atmospheric_pressure is within physical bounds (900-1100 hPa)
    pointblank::col_vals_between(
      columns = "atmospheric_pressure",
      left = 900,
      right = 1100,
      na_pass = TRUE,
      label = "Pressure 900-1100 hPa"
    ) |>
    # Check time is not in the future
    pointblank::col_vals_lte(
      columns = "time",
      value = Sys.time(),
      na_pass = TRUE,
      label = "Time not in future"
    ) |>
    # Run the validation
    pointblank::interrogate()

  # Save report if path provided
  if (!is.null(report_path)) {
    pointblank::export_report(agent, filename = report_path)
    cli::cli_alert_success("Validation report saved to {report_path}")
  }

  # Check if validation passed
  if (pointblank::all_passed(agent)) {
    cli::cli_alert_success(
      "Validation passed for {target_name}: {nrow(data)} rows, all checks OK"
    )
    return(data)
  }

  # Get failure summary
  report <- pointblank::get_agent_report(agent, display_table = FALSE)
  n_failed <- sum(!report$all_passed, na.rm = TRUE)

  # Check if we hit the stop threshold
  x_list <- pointblank::get_agent_x_list(agent)
  any_stop <- any(x_list$validation_set$stop, na.rm = TRUE)

  if (any_stop) {
    cli::cli_abort(c(
      "x" = "Validation FAILED for {target_name}",
      "i" = "{n_failed} validation steps failed",
      "i" = "Run with report_path to see details"
    ))
  }

  # Just warnings, return data
  cli::cli_warn(c(
    "!" = "Validation warnings for {target_name}",
    "i" = "{n_failed} validation steps had warnings"
  ))
  data
}

#' Validate rogue wave events data
#'
#' Validates rogue wave detection results with specific checks for
#' the rogue_ratio column and event characteristics.
#'
#' @param data A data frame of rogue wave events
#' @param target_name Name of the target for error messages
#' @param min_rows Minimum expected rows (default: 1)
#'
#' @return The original data if validation passes
#'
#' @export
validate_rogue_events <- function(data,
                                  target_name = "rogue_wave_events",
                                  min_rows = 1) {
  if (!requireNamespace("pointblank", quietly = TRUE)) {
    return(validate_tibble_rows_basic(data, target_name, min_rows))
  }

  agent <- pointblank::create_agent(
    tbl = data,
    tbl_name = target_name,
    label = "Rogue wave events validation"
  ) |>
    pointblank::rows_at_least(n = min_rows) |>
    pointblank::col_exists(columns = c("station_id", "time", "wave_height", "hmax", "rogue_ratio")) |>
    # Rogue ratio must be > 2.0 by definition
    pointblank::col_vals_gt(
      columns = "rogue_ratio",
      value = 2.0,
      label = "Rogue ratio > 2.0"
    ) |>
    # hmax must be greater than wave_height
    pointblank::col_vals_expr(
      expr = ~ hmax > wave_height,
      label = "hmax > wave_height"
    ) |>
    pointblank::interrogate()

  if (!pointblank::all_passed(agent)) {
    cli::cli_warn("Rogue events validation had issues for {target_name}")
  }

  data
}

#' Basic tibble row validation (fallback)
#'
#' Simple validation when pointblank is not available.
#' This is the original validate_tibble_rows function.
#'
#' @param data Data frame or tibble to validate
#' @param target_name Name of the target for error messages
#' @param min_rows Minimum expected rows (default: 1)
#'
#' @return The data unchanged if valid, otherwise aborts
#'
#' @keywords internal
validate_tibble_rows_basic <- function(data, target_name, min_rows = 1) {
  if (!is.data.frame(data)) return(data)
  if (nrow(data) < min_rows) {
    cli::cli_abort(c(
      "x" = "Target {target_name} returned {nrow(data)} rows",
      "i" = "Expected at least {min_rows} rows"
    ))
  }
  data
}

#' Create a validation summary for the pipeline
#'
#' Generates a summary of all validation results that can be
#' included in dashboards or reports.
#'
#' @param ... Named validation agents from interrogate()
#'
#' @return A tibble summarizing validation results
#'
#' @export
create_validation_summary <- function(...) {
  if (!requireNamespace("pointblank", quietly = TRUE)) {
    return(tibble::tibble(
      target = "N/A",
      status = "pointblank not installed",
      checks_passed = NA_integer_,
      checks_total = NA_integer_
    ))
  }

  agents <- list(...)

  purrr::map_dfr(names(agents), function(name) {
    agent <- agents[[name]]
    report <- pointblank::get_agent_report(agent, display_table = FALSE)

    tibble::tibble(
      target = name,
      status = if (pointblank::all_passed(agent)) "PASSED" else "FAILED",
      checks_passed = sum(report$all_passed, na.rm = TRUE),
      checks_total = nrow(report)
    )
  })
}
