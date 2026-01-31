#' Download Data from Irish Weather Buoy Network ERDDAP Server
#'
#' @description
#' Downloads data from the Marine Institute's ERDDAP server for the Irish
#' Weather Buoy Network. Supports filtering by date range, stations, and variables.
#'
#' @param start_date Character or Date, start of date range (default: 30 days ago)
#' @param end_date Character or Date, end of date range (default: today)
#' @param stations Character vector of station IDs (default: all stations)
#' @param variables Character vector of variable names (default: all variables)
#' @param format Character, output format: "csv", "json", or "tsv" (default: "csv")
#'
#' @return Data frame containing the requested buoy data
#'
#' @export
#' @examples
#' # Get last 7 days of data for all stations
#' data <- download_buoy_data(
#'   start_date = Sys.Date() - 7,
#'   end_date = Sys.Date()
#' )
#'
#' # Get specific variables for M3 buoy
#' wave_data <- download_buoy_data(
#'   stations = "M3",
#'   variables = c("time", "WaveHeight", "WavePeriod", "Hmax")
#' )
download_buoy_data <- function(
    start_date = Sys.Date() - 30,
    end_date = Sys.Date(),
    stations = NULL,
    variables = NULL,
    format = "csv"
) {

  # Base URL for ERDDAP
  base_url <- "https://erddap.marine.ie/erddap/tabledap/IWBNetwork"

  # Convert dates to ISO format
  start_date <- format(as.Date(start_date), "%Y-%m-%dT00:00:00Z")
  end_date <- format(as.Date(end_date), "%Y-%m-%dT23:59:59Z")

  # Default to all available variables if not specified
  if (is.null(variables)) {
    variables <- c(
      "time", "station_id", "CallSign", "longitude", "latitude",
      "AtmosphericPressure", "AirTemperature", "DewPoint",
      "WindDirection", "WindSpeed", "Gust", "RelativeHumidity",
      "SeaTemperature", "salinity", "WaveHeight", "WavePeriod",
      "MeanWaveDirection", "Hmax", "Tp", "ThTp", "SprTp", "QC_Flag"
    )
  }

  # Build query URL
  query_url <- glue::glue(
    "{base_url}.{format}?{paste(variables, collapse = ',')}"
  )

  # Add time constraints with proper URL encoding
  query_url <- paste0(query_url, "&time%3E%3D", start_date)
  query_url <- paste0(query_url, "&time%3C%3D", end_date)

  # Add station filter if specified
  if (!is.null(stations)) {
    station_filter <- paste0(
      "&station_id=~%22(",
      paste(stations, collapse = "|"),
      ")%22"
    )
    query_url <- paste0(query_url, station_filter)
  }

  cli::cli_progress_step("Downloading data from ERDDAP server...")
  cli::cli_alert_info("URL: {query_url}")

  # Download data
  response <- httr2::request(query_url) |>
    httr2::req_timeout(60) |>
    httr2::req_perform()

  # Parse response based on format
  if (format == "csv") {
    # ERDDAP CSV has 2 header rows: column names (row 1) and units (row 2)
    # We read row 1 as header and skip row 2 (units)
    csv_text <- httr2::resp_body_string(response)
    csv_lines <- strsplit(csv_text, "\n")[[1]]
    # Remove the units row (row 2, index 2)
    csv_lines <- csv_lines[-2]
    data <- utils::read.csv(text = paste(csv_lines, collapse = "\n"), stringsAsFactors = FALSE)

    # Convert time column to POSIXct if present
    if ("time" %in% names(data)) {
      data$time <- as.POSIXct(data$time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    }
  } else if (format == "json") {
    data <- response |>
      httr2::resp_body_json() |>
      jsonlite::fromJSON()

    # Extract table data from JSON structure
    if ("table" %in% names(data)) {
      column_names <- sapply(data$table$columnNames, `[`, 1)
      column_data <- data$table$rows
      data <- as.data.frame(column_data, stringsAsFactors = FALSE)
      names(data) <- column_names

      # Convert time column
      if ("time" %in% names(data)) {
        data$time <- as.POSIXct(data$time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      }
    }
  }

  # Convert numeric columns
  numeric_cols <- c(
    "longitude", "latitude", "AtmosphericPressure", "AirTemperature",
    "DewPoint", "WindDirection", "WindSpeed", "Gust", "RelativeHumidity",
    "SeaTemperature", "salinity", "WaveHeight", "WavePeriod",
    "MeanWaveDirection", "Hmax", "Tp", "ThTp", "SprTp", "QC_Flag"
  )

  for (col in numeric_cols) {
    if (col %in% names(data)) {
      data[[col]] <- as.numeric(data[[col]])
    }
  }

  cli::cli_alert_success("Downloaded {nrow(data)} records")

  return(data)
}

#' Get Latest Data Timestamp from ERDDAP
#'
#' @description
#' Queries the ERDDAP server to find the most recent data timestamp
#' available for the Irish Weather Buoy Network.
#'
#' @param station Optional station ID to check specific buoy
#'
#' @return POSIXct timestamp of most recent data
#'
#' @export
#' @examples
#' latest <- get_latest_timestamp()
#' latest_m3 <- get_latest_timestamp("M3")
get_latest_timestamp <- function(station = NULL) {
  base_url <- "https://erddap.marine.ie/erddap/tabledap/IWBNetwork"

  # Query for max time
  query_url <- paste0(base_url, ".csv?time&orderByMax(%22time%22)")

  if (!is.null(station)) {
    query_url <- paste0(query_url, "&station_id=%22", station, "%22")
  }

  response <- httr2::request(query_url) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()

  data <- response |>
    httr2::resp_body_string() |>
    utils::read.csv(text = _, skip = 1, stringsAsFactors = FALSE)

  latest_time <- as.POSIXct(data$time[1], format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

  cli::cli_alert_info("Latest data available: {latest_time}")

  return(latest_time)
}

#' Get Available Stations
#'
#' @description
#' Returns a data frame with information about all available weather buoy stations.
#'
#' @return Data frame with station metadata
#'
#' @export
#' @examples
#' stations <- get_stations()
get_stations <- function() {
  base_url <- "https://erddap.marine.ie/erddap/tabledap/IWBNetwork"

  query_url <- paste0(
    base_url,
    ".csv?station_id,CallSign,longitude,latitude&distinct()"
  )

  response <- httr2::request(query_url) |>
    httr2::req_timeout(30) |>
    httr2::req_perform()

  stations <- response |>
    httr2::resp_body_string() |>
    utils::read.csv(text = _, skip = 0, stringsAsFactors = FALSE)

  stations$longitude <- as.numeric(stations$longitude)
  stations$latitude <- as.numeric(stations$latitude)

  cli::cli_alert_info("Found {nrow(stations)} stations: {paste(stations$station_id, collapse = ', ')}")

  return(stations)
}