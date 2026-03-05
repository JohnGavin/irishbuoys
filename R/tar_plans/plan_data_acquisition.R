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

  # Single source of truth for data updates.

  # CI controls lookback via LOOKBACK_HOURS env var (e.g., storm-alert sets 72).
  # tar_make() is the ONLY caller — no explicit incremental_update() in CI.
  targets::tar_target(
    data_update,
    {
      lookback <- as.integer(Sys.getenv("LOOKBACK_HOURS", unset = "48"))
      incremental_update(
        db_path = "inst/extdata/irish_buoys.duckdb",
        lookback_hours = lookback
      )
    },
    cue = targets::tar_cue(mode = "always")
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