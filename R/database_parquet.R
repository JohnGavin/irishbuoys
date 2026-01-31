#' Parquet-based Storage Backend for Irish Buoys Data
#'
#' @description
#' Uses Parquet files as storage backend with DuckDB as query engine.
#' This provides excellent compression (5-10x) while maintaining query performance.
#'
#' The architecture:
#' - Raw data stored in partitioned Parquet files (by year/month)
#' - DuckDB used as query engine (reads Parquet directly)
#' - Optional: DuckDB database for metadata and indexes only

#' Initialize Parquet Storage Structure
#'
#' @param data_path Base path for Parquet files
#' @param db_path Optional path for metadata database
#'
#' @export
init_parquet_storage <- function(
    data_path = "inst/extdata/parquet",
    db_path = "inst/extdata/metadata.duckdb"
) {

  # Create directory structure
  dir.create(file.path(data_path, "by_year_month"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(data_path, "by_station"), recursive = TRUE, showWarnings = FALSE)

  # Create metadata database (small, <1 MB)
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con))

  # Metadata tables only
  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS parquet_files (
      file_id INTEGER PRIMARY KEY,
      file_path VARCHAR,
      partition_year INTEGER,
      partition_month INTEGER,
      station_id VARCHAR,
      min_time TIMESTAMP,
      max_time TIMESTAMP,
      row_count INTEGER,
      file_size_kb DOUBLE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    )
  ")

  DBI::dbExecute(con, "
    CREATE TABLE IF NOT EXISTS update_log (
      update_id INTEGER PRIMARY KEY,
      update_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
      files_added INTEGER,
      total_rows_added INTEGER,
      notes VARCHAR
    )
  ")

  cli::cli_alert_success("Initialized Parquet storage structure")

  return(list(data_path = data_path, db_path = db_path))
}

#' Save Data to Parquet with Optimal Compression
#'
#' @param data Data frame to save
#' @param data_path Base path for Parquet files
#' @param partition_by How to partition: "year_month", "station", or "both"
#' @param compression Compression algorithm: "snappy", "gzip", "zstd", "lz4"
#'
#' @export
save_to_parquet <- function(
    data,
    data_path = "inst/extdata/parquet",
    partition_by = "year_month",
    compression = "zstd"
) {

  cli::cli_progress_step("Saving data to Parquet format...")

  # Ensure arrow is available
  if (!requireNamespace("arrow", quietly = TRUE)) {
    stop("Package 'arrow' required for Parquet operations")
  }

  # Add partition columns if needed
  if (partition_by %in% c("year_month", "both")) {
    data$year <- lubridate::year(data$time)
    data$month <- lubridate::month(data$time)
  }

  # Set compression level
  compression_level <- if(compression == "zstd") 9L else NULL

  if (partition_by == "year_month") {
    # Partition by year and month
    arrow::write_dataset(
      data,
      path = file.path(data_path, "by_year_month"),
      format = "parquet",
      partitioning = c("year", "month"),
      existing_data_behavior = "overwrite"
    )

  } else if (partition_by == "station") {
    # Partition by station
    arrow::write_dataset(
      data,
      path = file.path(data_path, "by_station"),
      format = "parquet",
      partitioning = "station_id",
      existing_data_behavior = "overwrite"
    )

  } else if (partition_by == "both") {
    # Dual partitioning (year_month and station)
    arrow::write_dataset(
      data,
      path = file.path(data_path, "by_year_month_station"),
      format = "parquet",
      partitioning = c("year", "month", "station_id"),
      existing_data_behavior = "overwrite"
    )
  }

  # Calculate and report compression ratio
  parquet_size <- sum(file.info(
    list.files(data_path, pattern = "\\.parquet$", recursive = TRUE, full.names = TRUE)
  )$size, na.rm = TRUE) / 1024^2

  # Estimate uncompressed size (rough)
  csv_size_estimate <- utils::object.size(data) / 1024^2 * 2  # CSV is ~2x object size

  cli::cli_alert_success(
    "Saved to Parquet: {round(parquet_size, 2)} MB (compression ratio ~{round(csv_size_estimate/parquet_size, 1)}:1)"
  )

  return(invisible(parquet_size))
}

#' Query Parquet Files with DuckDB
#'
#' @description
#' DuckDB can query Parquet files directly without importing.
#' This provides excellent performance with minimal memory usage.
#'
#' @param query SQL query or NULL for interactive connection
#' @param data_path Path to Parquet files
#' @param stations Filter for specific stations
#' @param date_range Date range as c(start_date, end_date)
#'
#' @export
#' @examples
#' \dontrun{
#' # Query recent data
#' df <- query_parquet(
#'   "SELECT * FROM buoy_data WHERE wave_height > 5",
#'   date_range = c(Sys.Date() - 30, Sys.Date())
#' )
#' }
query_parquet <- function(
    query = NULL,
    data_path = "inst/extdata/parquet/by_year_month",
    stations = NULL,
    date_range = NULL
) {

  # Connect to DuckDB (in-memory for queries)
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))

  # Create view of Parquet files
  parquet_glob <- file.path(data_path, "**/*.parquet")

  # Build WHERE clause for partition pruning
  where_clauses <- c()

  if (!is.null(date_range)) {
    start_date <- as.Date(date_range[1])
    end_date <- as.Date(date_range[2])

    # Partition pruning for year/month
    start_year <- lubridate::year(start_date)
    start_month <- lubridate::month(start_date)
    end_year <- lubridate::year(end_date)
    end_month <- lubridate::month(end_date)

    where_clauses <- c(where_clauses,
      glue::glue("(year > {start_year} OR (year = {start_year} AND month >= {start_month}))"),
      glue::glue("(year < {end_year} OR (year = {end_year} AND month <= {end_month}))")
    )
  }

  if (!is.null(stations)) {
    station_list <- paste0("'", stations, "'", collapse = ",")
    where_clauses <- c(where_clauses, glue::glue("station_id IN ({station_list})"))
  }

  # Create the view with filters
  if (length(where_clauses) > 0) {
    where_clause <- paste("WHERE", paste(where_clauses, collapse = " AND "))
  } else {
    where_clause <- ""
  }

  view_query <- glue::glue("
    CREATE VIEW buoy_data AS
    SELECT * FROM read_parquet('{parquet_glob}')
    {where_clause}
  ")

  DBI::dbExecute(con, view_query)

  # If no query provided, return connection for interactive use
  if (is.null(query)) {
    cli::cli_alert_info("Connected to Parquet files. Use DBI::dbGetQuery() to run queries.")
    cli::cli_alert_info("View 'buoy_data' available for querying")
    return(con)
  }

  # Execute query
  cli::cli_progress_step("Executing query on Parquet files...")
  result <- DBI::dbGetQuery(con, query)

  cli::cli_alert_success("Retrieved {nrow(result)} rows")

  return(result)
}

#' Incremental Update with Parquet Storage
#'
#' @description
#' Efficiently append new data to Parquet files.
#' Only writes new partitions or updates existing ones.
#'
#' @param new_data New data to append
#' @param data_path Base path for Parquet files
#'
#' @export
incremental_update_parquet <- function(
    new_data,
    data_path = "inst/extdata/parquet"
) {

  if (nrow(new_data) == 0) {
    cli::cli_alert_info("No new data to add")
    return(invisible(0))
  }

  cli::cli_progress_step("Performing incremental update to Parquet storage...")

  # Add partition columns
  new_data$year <- lubridate::year(new_data$time)
  new_data$month <- lubridate::month(new_data$time)

  # Group by partition
  partitions <- unique(new_data[, c("year", "month")])

  rows_added <- 0

  for (i in 1:nrow(partitions)) {
    year <- partitions$year[i]
    month <- partitions$month[i]

    partition_path <- file.path(
      data_path, "by_year_month",
      paste0("year=", year),
      paste0("month=", month)
    )

    partition_data <- new_data[
      new_data$year == year & new_data$month == month,
    ]

    # Check if partition exists
    if (dir.exists(partition_path)) {
      # Read existing partition
      existing <- arrow::read_parquet(
        list.files(partition_path, full.names = TRUE, pattern = "\\.parquet$")[1]
      )

      # Combine and deduplicate
      combined <- dplyr::distinct(
        dplyr::bind_rows(existing, partition_data),
        time, station_id, .keep_all = TRUE
      )

      new_rows <- nrow(combined) - nrow(existing)

      if (new_rows > 0) {
        # Rewrite partition with new data
        arrow::write_parquet(
          combined,
          file.path(partition_path, "data.parquet"),
          compression = "zstd",
          compression_level = 9
        )
        rows_added <- rows_added + new_rows
        cli::cli_alert_info("Updated partition {year}-{month}: {new_rows} new rows")
      }

    } else {
      # Create new partition
      dir.create(partition_path, recursive = TRUE, showWarnings = FALSE)

      arrow::write_parquet(
        partition_data,
        file.path(partition_path, "data.parquet"),
        compression = "zstd",
        compression_level = 9
      )

      rows_added <- rows_added + nrow(partition_data)
      cli::cli_alert_success("Created partition {year}-{month}: {nrow(partition_data)} rows")
    }
  }

  # Report final size
  total_size <- sum(file.info(
    list.files(data_path, pattern = "\\.parquet$", recursive = TRUE, full.names = TRUE)
  )$size, na.rm = TRUE) / 1024^2

  cli::cli_alert_success("Update complete: {rows_added} rows added")
  cli::cli_alert_info("Total Parquet storage: {round(total_size, 2)} MB")

  return(invisible(rows_added))
}

#' Analyze Parquet Storage
#'
#' @description
#' Get statistics about Parquet file storage.
#'
#' @param data_path Base path for Parquet files
#'
#' @export
analyze_parquet_storage <- function(data_path = "inst/extdata/parquet") {

  parquet_files <- list.files(
    data_path,
    pattern = "\\.parquet$",
    recursive = TRUE,
    full.names = TRUE
  )

  if (length(parquet_files) == 0) {
    cli::cli_alert_warning("No Parquet files found")
    return(NULL)
  }

  # Get file information
  file_info <- data.frame(
    file = basename(parquet_files),
    path = parquet_files,
    size_mb = file.info(parquet_files)$size / 1024^2,
    stringsAsFactors = FALSE
  )

  # Read schema from first file
  schema <- arrow::schema(arrow::read_parquet(parquet_files[1], as_data_frame = FALSE))

  # Connect to DuckDB for statistics
  con <- DBI::dbConnect(duckdb::duckdb())
  on.exit(DBI::dbDisconnect(con))

  # Get row counts and date ranges
  stats_query <- glue::glue("
    SELECT
      COUNT(*) as total_rows,
      COUNT(DISTINCT station_id) as stations,
      MIN(time) as min_date,
      MAX(time) as max_date,
      COUNT(DISTINCT DATE(time)) as unique_days
    FROM read_parquet('{file.path(data_path, '**/*.parquet')}')
  ")

  stats <- DBI::dbGetQuery(con, stats_query)

  # Calculate compression metrics
  result <- list(
    summary = stats,
    total_size_mb = sum(file_info$size_mb),
    n_files = nrow(file_info),
    avg_file_size_mb = mean(file_info$size_mb),
    estimated_compression_ratio = stats$total_rows * 200 / (1024^2 * sum(file_info$size_mb)),
    file_details = file_info,
    schema = schema
  )

  cli::cli_h2("Parquet Storage Analysis")
  cli::cli_alert_info("Total files: {result$n_files}")
  cli::cli_alert_info("Total size: {round(result$total_size_mb, 2)} MB")
  cli::cli_alert_info("Total rows: {format(result$summary$total_rows, big.mark = ',')}")
  cli::cli_alert_info("Compression ratio: ~{round(result$estimated_compression_ratio, 1)}:1")
  cli::cli_alert_info("Date range: {result$summary$min_date} to {result$summary$max_date}")

  return(result)
}

#' Convert Existing DuckDB to Parquet
#'
#' @description
#' One-time conversion from DuckDB database to Parquet files.
#'
#' @param db_path Path to existing DuckDB database
#' @param data_path Output path for Parquet files
#'
#' @export
convert_duckdb_to_parquet <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    data_path = "inst/extdata/parquet"
) {

  if (!file.exists(db_path)) {
    stop("Database file not found: ", db_path)
  }

  cli::cli_h1("Converting DuckDB to Parquet Format")

  # Connect to existing database
  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con))

  # Read all data
  cli::cli_progress_step("Reading data from DuckDB...")
  data <- DBI::dbGetQuery(con, "SELECT * FROM buoy_data ORDER BY time")

  cli::cli_alert_info("Read {nrow(data)} rows from DuckDB")

  # Get original size
  db_size_mb <- file.info(db_path)$size / 1024^2
  cli::cli_alert_info("Original DuckDB size: {round(db_size_mb, 2)} MB")

  # Save to Parquet
  parquet_size <- save_to_parquet(
    data,
    data_path = data_path,
    partition_by = "year_month",
    compression = "zstd"
  )

  # Report compression
  cli::cli_alert_success(
    "Conversion complete: {round(db_size_mb, 2)} MB → {round(parquet_size, 2)} MB (
    {round(100 * (1 - parquet_size/db_size_mb), 1)}% reduction)"
  )

  return(invisible(list(
    original_size_mb = db_size_mb,
    parquet_size_mb = parquet_size,
    compression_ratio = db_size_mb / parquet_size
  )))
}