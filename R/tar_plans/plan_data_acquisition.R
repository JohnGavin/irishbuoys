#' Targets Plan: Data Acquisition
#'
#' This plan handles downloading and storing data from the Irish Weather Buoy Network

plan_data_acquisition <- list(
  # Check for latest available data on ERDDAP
  targets::tar_target(
    latest_erddap_timestamp,
    get_latest_timestamp()
  ),

  # Get current database statistics
  targets::tar_target(
    current_db_stats,
    get_database_stats()
  ),

  # Perform incremental update if needed
  targets::tar_target(
    data_update,
    incremental_update(lookback_hours = 48)
  ),

  # Download specific date range for analysis
  targets::tar_target(
    recent_data,
    download_buoy_data(
      start_date = Sys.Date() - 30,
      end_date = Sys.Date()
    )
  ),

  # Get station metadata
  targets::tar_target(
    stations,
    get_stations()
  )
)