#' Perform Incremental Data Update
#'
#' @description
#' Downloads new data since the last update and appends it to the database.
#' Designed to be run on a schedule (e.g., daily or weekly via cron/GitHub Actions).
#'
#' @param db_path Path to DuckDB database file
#' @param lookback_hours Number of hours to look back for safety (default: 48)
#'   This ensures we don't miss data due to delays in ERDDAP updates
#'
#' @return List with update statistics
#'
#' @export
#' @examples
#' \dontrun{
#' # Perform incremental update
#' result <- incremental_update()
#'
#' # Check what was updated
#' print(result$summary)
#' }
incremental_update <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_hours = 48
) {

  cli::cli_h1("Starting Incremental Data Update")

  # Connect to database
  con <- connect_duckdb(db_path = db_path, create_new = FALSE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Get the latest timestamp in the database
  latest_db <- DBI::dbGetQuery(con, "
    SELECT MAX(time) as max_time FROM buoy_data
  ")$max_time

  if (is.na(latest_db)) {
    cli::cli_alert_warning("Database is empty. Performing initial data load...")
    # If database is empty, get last 30 days
    start_time <- Sys.Date() - 30
  } else {
    # Convert to POSIXct
    latest_db <- as.POSIXct(latest_db, tz = "UTC")

    # Start from latest_db minus lookback period
    start_time <- latest_db - (lookback_hours * 3600)

    cli::cli_alert_info("Latest data in database: {latest_db}")
    cli::cli_alert_info("Checking for updates from: {start_time}")
  }

  # Get current time
  end_time <- Sys.time()

  # Download new data
  tryCatch({
    new_data <- download_buoy_data(
      start_date = start_time,
      end_date = end_time
    )

    if (nrow(new_data) == 0) {
      cli::cli_alert_info("No new data available")
      return(list(
        status = "up_to_date",
        records_added = 0,
        start_time = start_time,
        end_time = end_time
      ))
    }

    # Load to database
    records_added <- load_to_duckdb(new_data, con, update_metadata = TRUE)

    # Get summary statistics
    if (records_added > 0) {
      summary_stats <- DBI::dbGetQuery(con, glue::glue("
        SELECT
          station_id,
          COUNT(*) as n_records,
          MIN(time) as earliest,
          MAX(time) as latest
        FROM buoy_data
        WHERE time >= '{start_time}'
        GROUP BY station_id
        ORDER BY station_id
      "))

      cli::cli_h2("Update Summary")
      cli::cli_alert_success("Added {records_added} new records")
      print(summary_stats)
    } else {
      summary_stats <- data.frame()
    }

    return(list(
      status = "success",
      records_added = records_added,
      start_time = start_time,
      end_time = end_time,
      summary = summary_stats,
      update_time = Sys.time()
    ))

  }, error = function(e) {
    cli::cli_alert_danger("Error during update: {e$message}")
    return(list(
      status = "error",
      error = e$message,
      start_time = start_time,
      end_time = end_time,
      update_time = Sys.time()
    ))
  })
}

#' Initialize Database with Historical Data
#'
#' @description
#' Downloads and loads a larger set of historical data into the database.
#' Use this for initial setup or to rebuild the database.
#'
#' @param db_path Path to DuckDB database file
#' @param start_date Start date for historical data (default: 1 year ago)
#' @param end_date End date for historical data (default: today)
#' @param chunk_days Number of days to download at once (default: 30)
#'
#' @return Total number of records loaded
#'
#' @export
#' @examples
#' \dontrun{
#' # Initialize with last year of data
#' records <- initialize_database(start_date = "2023-01-01")
#' }
initialize_database <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    start_date = Sys.Date() - 365,
    end_date = Sys.Date(),
    chunk_days = 30
) {

  cli::cli_h1("Initializing Database with Historical Data")

  # Create new database
  con <- connect_duckdb(db_path = db_path, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Convert dates
  start_date <- as.Date(start_date)
  end_date <- as.Date(end_date)

  # Create date chunks
  date_seq <- seq(start_date, end_date, by = chunk_days)
  if (utils::tail(date_seq, 1) < end_date) {
    date_seq <- c(date_seq, end_date)
  }

  total_records <- 0

  # Download and load data in chunks
  pb <- cli::cli_progress_bar(
    "Downloading historical data",
    total = length(date_seq) - 1
  )

  for (i in 1:(length(date_seq) - 1)) {
    chunk_start <- date_seq[i]
    chunk_end <- min(date_seq[i + 1], end_date)

    cli::cli_progress_update(id = pb)
    cli::cli_alert_info("Processing: {chunk_start} to {chunk_end}")

    tryCatch({
      # Download chunk
      data <- download_buoy_data(
        start_date = chunk_start,
        end_date = chunk_end
      )

      if (nrow(data) > 0) {
        # Load to database
        records_added <- load_to_duckdb(data, con, update_metadata = TRUE)
        total_records <- total_records + records_added
      }

      # Small delay to be nice to the server
      Sys.sleep(1)

    }, error = function(e) {
      cli::cli_alert_warning("Error downloading chunk {i}: {e$message}")
    })
  }

  cli::cli_progress_done(id = pb)

  # Display final statistics
  stats <- DBI::dbGetQuery(con, "
    SELECT
      COUNT(DISTINCT station_id) as n_stations,
      COUNT(*) as n_records,
      MIN(time) as earliest_date,
      MAX(time) as latest_date
    FROM buoy_data
  ")

  cli::cli_h2("Database Statistics")
  cli::cli_alert_success("Total records loaded: {stats$n_records}")
  cli::cli_alert_info("Stations: {stats$n_stations}")
  cli::cli_alert_info("Date range: {stats$earliest_date} to {stats$latest_date}")

  return(total_records)
}

#' Get Database Statistics
#'
#' @description
#' Returns summary statistics about the current state of the database.
#'
#' @param db_path Path to DuckDB database file
#'
#' @return List with database statistics
#'
#' @export
#' @examples
#' \dontrun{
#' stats <- get_database_stats()
#' print(stats)
#' }
get_database_stats <- function(db_path = "inst/extdata/irish_buoys.duckdb") {

  if (!file.exists(db_path)) {
    cli::cli_alert_warning("Database does not exist at {db_path}")
    return(NULL)
  }

  con <- connect_duckdb(db_path = db_path, create_new = FALSE)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  # Overall statistics
  overall <- DBI::dbGetQuery(con, "
    SELECT
      COUNT(*) as total_records,
      COUNT(DISTINCT station_id) as n_stations,
      MIN(time) as earliest_date,
      MAX(time) as latest_date,
      COUNT(DISTINCT DATE(time)) as n_days
    FROM buoy_data
  ")

  # Per-station statistics
  by_station <- DBI::dbGetQuery(con, "
    SELECT
      station_id,
      COUNT(*) as n_records,
      MIN(time) as first_observation,
      MAX(time) as last_observation,
      AVG(CASE WHEN qc_flag = 1 THEN 1 ELSE 0 END) as pct_good_quality
    FROM buoy_data
    GROUP BY station_id
    ORDER BY station_id
  ")

  # Recent updates
  recent_updates <- DBI::dbGetQuery(con, "
    SELECT *
    FROM update_log
    ORDER BY update_time DESC
    LIMIT 10
  ")

  # Data completeness by variable
  completeness <- DBI::dbGetQuery(con, "
    SELECT
      COUNT(*) as n_total,
      SUM(CASE WHEN atmospheric_pressure IS NOT NULL THEN 1 ELSE 0 END) / CAST(COUNT(*) AS REAL) as pct_pressure,
      SUM(CASE WHEN air_temperature IS NOT NULL THEN 1 ELSE 0 END) / CAST(COUNT(*) AS REAL) as pct_temperature,
      SUM(CASE WHEN wind_speed IS NOT NULL THEN 1 ELSE 0 END) / CAST(COUNT(*) AS REAL) as pct_wind,
      SUM(CASE WHEN wave_height IS NOT NULL THEN 1 ELSE 0 END) / CAST(COUNT(*) AS REAL) as pct_wave
    FROM buoy_data
  ")

  stats <- list(
    overall = overall,
    by_station = by_station,
    recent_updates = recent_updates,
    completeness = completeness,
    db_size_mb = file.info(db_path)$size / 1024^2
  )

  cli::cli_h2("Database Statistics")
  cli::cli_alert_info("Total records: {format(overall$total_records, big.mark = ',')}")
  cli::cli_alert_info("Date range: {overall$earliest_date} to {overall$latest_date}")
  cli::cli_alert_info("Stations: {paste(by_station$station_id, collapse = ', ')}")
  cli::cli_alert_info("Database size: {round(stats$db_size_mb, 2)} MB")

  return(stats)
}