#' Create or Connect to Irish Buoys DuckDB Database
#'
#' @description
#' Creates a new DuckDB database or connects to an existing one for storing
#' Irish Weather Buoy Network data. Sets up the schema if creating new.
#'
#' @param db_path Character, path to database file (default: "inst/extdata/irish_buoys.duckdb")
#' @param create_new Logical, whether to create new database (default: FALSE)
#'
#' @return DBI connection object to the DuckDB database
#'
#' @export
#' @examples
#' # Connect to existing database
#' con <- connect_duckdb()
#'
#' # Create new database
#' con <- connect_duckdb(create_new = TRUE)
#'
#' # Don't forget to disconnect when done
#' DBI::dbDisconnect(con)
connect_duckdb <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    create_new = FALSE
) {

  # Create directory if it doesn't exist
  dir.create(dirname(db_path), showWarnings = FALSE, recursive = TRUE)

  # Remove existing database if creating new
  if (create_new && file.exists(db_path)) {
    cli::cli_alert_warning("Removing existing database at {db_path}")
    file.remove(db_path)
  }

  # Connect to DuckDB
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)

  cli::cli_alert_success("Connected to DuckDB at {db_path}")

  # Create schema if new database
  if (create_new || !DBI::dbExistsTable(con, "buoy_data")) {
    create_buoy_schema(con)
  }

  return(con)
}

#' Get Lazy Reference to Buoy Data Table
#'
#' @description
#' Returns a lazy dplyr tibble reference to the buoy_data table.
#' All dplyr operations are translated to SQL and executed in DuckDB.
#' Call collect() to retrieve results as a data frame.
#'
#' @param con DBI connection to DuckDB database
#' @param table_name Name of the table (default: "buoy_data")
#'
#' @return A lazy tibble (tbl_dbi) for use with dplyr verbs
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' buoy_tbl(con) |>
#'   dplyr::filter(station_id == "M3", wave_height > 5) |>
#'   dplyr::select(time, wave_height, hmax) |>
#'   dplyr::collect()
#' DBI::dbDisconnect(con)
#' }
buoy_tbl <- function(con, table_name = "buoy_data") {
  dplyr::tbl(con, table_name)
}

#' Create Database Schema for Buoy Data
#'
#' @description
#' Creates the necessary tables and indexes for efficient storage and
#' querying of buoy data.
#'
#' @param con DBI connection object
#'
#' @return Invisible NULL
#'
#' @export
create_buoy_schema <- function(con) {

  cli::cli_progress_step("Creating database schema...")

  # Main buoy data table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS buoy_data (
      time TIMESTAMP NOT NULL,
      station_id VARCHAR NOT NULL,
      call_sign VARCHAR,
      longitude DOUBLE,
      latitude DOUBLE,
      atmospheric_pressure DOUBLE,
      air_temperature DOUBLE,
      dew_point DOUBLE,
      wind_direction DOUBLE,
      wind_speed DOUBLE,
      gust DOUBLE,
      relative_humidity DOUBLE,
      sea_temperature DOUBLE,
      salinity DOUBLE,
      wave_height DOUBLE,
      wave_period DOUBLE,
      mean_wave_direction DOUBLE,
      hmax DOUBLE,
      tp DOUBLE,
      thtp DOUBLE,
      sprtp DOUBLE,
      qc_flag INTEGER,
      PRIMARY KEY (time, station_id)
    )
  ")

  # Create indexes for efficient querying
  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_station_time
    ON buoy_data(station_id, time)
  ")

  DBI::dbExecute(con, "
    CREATE INDEX IF NOT EXISTS idx_time
    ON buoy_data(time)
  ")

  # Station metadata table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS stations (
      station_id VARCHAR PRIMARY KEY,
      call_sign VARCHAR,
      longitude DOUBLE,
      latitude DOUBLE,
      active BOOLEAN DEFAULT TRUE,
      first_observation TIMESTAMP,
      last_observation TIMESTAMP
    )
  ")

  # Data update log table
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS update_log (
      update_id INTEGER PRIMARY KEY,
      update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      start_date TIMESTAMP,
      end_date TIMESTAMP,
      records_added INTEGER,
      stations_updated VARCHAR,
      notes VARCHAR
    )
  ")

  cli::cli_alert_success("Database schema created successfully")

  invisible(NULL)
}

#' Load Data into DuckDB Database
#'
#' @description
#' Loads buoy data from a data frame into the DuckDB database.
#' Handles duplicates by using ON CONFLICT DO NOTHING.
#'
#' @param data Data frame containing buoy data
#' @param con DBI connection object
#' @param update_metadata Logical, whether to update station metadata (default: TRUE)
#'
#' @return Number of rows inserted
#'
#' @export
#' @examples
#' \dontrun{
#' # Download and load data
#' data <- download_buoy_data(start_date = "2024-01-01")
#' con <- connect_duckdb()
#' rows_added <- load_to_duckdb(data, con)
#' DBI::dbDisconnect(con)
#' }
load_to_duckdb <- function(data, con, update_metadata = TRUE) {

  cli::cli_progress_step("Preparing data for database insertion...")

  # Standardize column names
  names(data) <- tolower(names(data))
  names(data) <- gsub("callsign", "call_sign", names(data))
  names(data) <- gsub("atmosphericpressure", "atmospheric_pressure", names(data))
  names(data) <- gsub("airtemperature", "air_temperature", names(data))
  names(data) <- gsub("dewpoint", "dew_point", names(data))
  names(data) <- gsub("winddirection", "wind_direction", names(data))
  names(data) <- gsub("windspeed", "wind_speed", names(data))
  names(data) <- gsub("relativehumidity", "relative_humidity", names(data))
  names(data) <- gsub("seatemperature", "sea_temperature", names(data))
  names(data) <- gsub("waveheight", "wave_height", names(data))
  names(data) <- gsub("waveperiod", "wave_period", names(data))
  names(data) <- gsub("meanwavedirection", "mean_wave_direction", names(data))
  names(data) <- gsub("qc_flag", "qc_flag", names(data))

  # Convert NaN to NA (ERDDAP returns "NaN" for missing values)
  numeric_cols <- names(data)[vapply(data, is.numeric, logical(1))]
  for (col in numeric_cols) {
    data[[col]][is.nan(data[[col]])] <- NA
  }

  # Get count before insertion (using dplyr)
  count_before <- buoy_tbl(con) |>
    dplyr::summarise(n = dplyr::n()) |>
    dplyr::collect() |>
    dplyr::pull(n)

  # Write to staging table, then INSERT ... ON CONFLICT DO NOTHING
  # This handles duplicate records at chunk boundaries gracefully
  staging_name <- paste0("staging_", format(Sys.time(), "%H%M%S"))
  DBI::dbWriteTable(con, staging_name, data, temporary = TRUE, overwrite = TRUE)

  # Get column names that exist in both staging and buoy_data
  staging_cols <- DBI::dbListFields(con, staging_name)
  target_cols <- DBI::dbListFields(con, "buoy_data")
  common_cols <- intersect(staging_cols, target_cols)

  cols_sql <- paste(common_cols, collapse = ", ")
  DBI::dbExecute(con, paste0(
    "INSERT INTO buoy_data (", cols_sql, ") ",
    "SELECT ", cols_sql, " FROM ", staging_name,
    " ON CONFLICT DO NOTHING"
  ))

  # Clean up staging table
  DBI::dbExecute(con, paste0("DROP TABLE IF EXISTS ", staging_name))

  # Get count after insertion (using dplyr)
  count_after <- buoy_tbl(con) |>
    dplyr::summarise(n = dplyr::n()) |>
    dplyr::collect() |>
    dplyr::pull(n)
  rows_added <- count_after - count_before

  cli::cli_alert_success("Added {rows_added} new records to database")

  # Update station metadata
  if (update_metadata && "station_id" %in% names(data)) {
    update_station_metadata(con, unique(data$station_id))
  }

  # Log the update
  if (rows_added > 0) {
    log_update(
      con,
      start_date = min(data$time, na.rm = TRUE),
      end_date = max(data$time, na.rm = TRUE),
      records_added = rows_added,
      stations = paste(unique(data$station_id), collapse = ",")
    )
  }

  return(rows_added)
}

#' Update Station Metadata
#'
#' @description
#' Updates the station metadata table with latest observation times.
#' Uses dplyr for the SELECT query, DBI for the INSERT.
#'
#' @param con DBI connection object
#' @param station_ids Character vector of station IDs to update
#'
#' @return Invisible NULL
#'
#' @keywords internal
update_station_metadata <- function(con, station_ids) {

  for (station in station_ids) {
    # Get station statistics using dplyr
    stats <- buoy_tbl(con) |>
      dplyr::filter(.data$station_id == !!station) |>
      dplyr::summarise(
        station_id = dplyr::first(.data$station_id),
        longitude = min(.data$longitude, na.rm = TRUE),
        latitude = min(.data$latitude, na.rm = TRUE),
        call_sign = min(.data$call_sign, na.rm = TRUE),
        first_obs = min(.data$time, na.rm = TRUE),
        last_obs = max(.data$time, na.rm = TRUE)
      ) |>
      dplyr::collect()

    if (nrow(stats) > 0) {
      # Update or insert station info (DBI for INSERT)
      DBI::dbExecute(con, glue::glue("
        INSERT OR REPLACE INTO stations
        (station_id, call_sign, longitude, latitude, first_observation, last_observation)
        VALUES
        ('{stats$station_id}', '{stats$call_sign}', {stats$longitude},
         {stats$latitude}, '{stats$first_obs}', '{stats$last_obs}')
      "))
    }
  }

  invisible(NULL)
}

#' Log Data Update
#'
#' @description
#' Records information about data updates to the update_log table.
#'
#' @param con DBI connection object
#' @param start_date Start date of updated data
#' @param end_date End date of updated data
#' @param records_added Number of records added
#' @param stations Comma-separated list of updated stations
#' @param notes Optional notes about the update
#'
#' @return Invisible NULL
#'
#' @keywords internal
log_update <- function(con, start_date, end_date, records_added, stations, notes = NULL) {

  if (is.null(notes)) {
    notes <- ""
  }

  # Generate next update_id (DuckDB doesn't auto-increment like SQLite)
  DBI::dbExecute(con, glue::glue("
    INSERT INTO update_log
    (update_id, start_date, end_date, records_added, stations_updated, notes)
    VALUES
    ((SELECT COALESCE(MAX(update_id), 0) + 1 FROM update_log),
     '{start_date}', '{end_date}', {records_added}, '{stations}', '{notes}')
  "))

  invisible(NULL)
}

#' Query Buoy Data from Database
#'
#' @description
#' Flexible querying of buoy data with various filtering options.
#' Uses dplyr verbs translated to SQL for efficient DuckDB execution.
#'
#' @param con DBI connection object
#' @param stations Character vector of station IDs (default: all)
#' @param start_date Start date for query
#' @param end_date End date for query
#' @param variables Character vector of variables to return
#' @param qc_filter Logical, filter for good quality data only (default: TRUE)
#' @param sql_query Optional custom SQL query (bypasses dplyr)
#'
#' @return Data frame with query results
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' # Get recent M3 wave data
#' waves <- query_buoy_data(
#'   con,
#'   stations = "M3",
#'   variables = c("time", "wave_height", "wave_period"),
#'   start_date = Sys.Date() - 7
#' )
#' }
query_buoy_data <- function(
    con,
    stations = NULL,
    start_date = NULL,
    end_date = NULL,
    variables = NULL,
    qc_filter = TRUE,
    sql_query = NULL
) {

  # Use custom SQL if provided (fallback for complex queries)
  if (!is.null(sql_query)) {
    result <- DBI::dbGetQuery(con, sql_query)
    cli::cli_alert_success("Retrieved {nrow(result)} records (custom SQL)")
    return(result)
  }

  # Start with lazy table reference
tbl_ref <- buoy_tbl(con)

  # Apply filters using dplyr verbs (translated to SQL)
  if (!is.null(stations)) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$station_id %in% !!stations)
  }

  if (!is.null(start_date)) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$time >= !!start_date)
  }

  if (!is.null(end_date)) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$time <= !!end_date)
  }

  if (qc_filter) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$qc_flag == 1L)
  }

  # Select specific variables if requested
  if (!is.null(variables)) {
    tbl_ref <- tbl_ref |> dplyr::select(dplyr::all_of(variables))
  }

  # Order by time and collect
  result <- tbl_ref |>
    dplyr::arrange(.data$time) |>
    dplyr::collect()

  cli::cli_alert_success("Retrieved {nrow(result)} records")

  return(result)
}