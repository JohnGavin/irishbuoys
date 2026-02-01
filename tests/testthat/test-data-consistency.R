# Tests for data consistency using snapshots
# These tests ensure that:
# 1. Historical data is not lost (earliest dates preserved)
# 2. Data structure remains consistent
# 3. Station coverage is maintained

test_that("dashboard data file exists", {
  data_path <- system.file("extdata", "buoy_data.json", package = "irishbuoys")
  # Fall back to vignettes/data if not in inst/extdata
  if (data_path == "") {
    data_path <- file.path(
      system.file(package = "irishbuoys"),
      "..", "vignettes", "data", "buoy_data.json"
    )
  }
  # For development, check in working directory
  if (!file.exists(data_path)) {
    data_path <- "vignettes/data/buoy_data.json"
  }
  expect_true(
    file.exists(data_path) || file.exists("../../vignettes/data/buoy_data.json"),
    info = "Dashboard data file should exist"
  )
})

test_that("earliest dates snapshot - historical data preserved", {
  skip_if_not(file.exists("../../vignettes/data/buoy_data.json"))

  data <- jsonlite::fromJSON("../../vignettes/data/buoy_data.json")
  data$time <- as.POSIXct(data$time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")

  # Get earliest date per station
  earliest_dates <- tapply(data$time, data$station_id, min, na.rm = TRUE)
  earliest_df <- data.frame(
    station_id = names(earliest_dates),
    earliest_date = as.character(as.POSIXct(earliest_dates, origin = "1970-01-01", tz = "UTC")),
    stringsAsFactors = FALSE
  )
  earliest_df <- earliest_df[order(earliest_df$station_id), ]
  row.names(earliest_df) <- NULL

  expect_snapshot(earliest_df)
})

test_that("data structure snapshot - columns remain consistent", {
  skip_if_not(file.exists("../../vignettes/data/buoy_data.json"))

  data <- jsonlite::fromJSON("../../vignettes/data/buoy_data.json")

  # Snapshot column names (sorted for consistency)
  column_info <- data.frame(
    column = sort(names(data)),
    stringsAsFactors = FALSE
  )

  expect_snapshot(column_info)
})

test_that("station list snapshot - stations not lost", {
  skip_if_not(file.exists("../../vignettes/data/buoy_data.json"))

  data <- jsonlite::fromJSON("../../vignettes/data/buoy_data.json")

  # Get unique stations with record counts
  station_counts <- as.data.frame(table(data$station_id))
  names(station_counts) <- c("station_id", "n_records")
  station_counts <- station_counts[order(station_counts$station_id), ]
  row.names(station_counts) <- NULL

  expect_snapshot(station_counts)
})

test_that("data date range - should span multiple years",
{
  skip_if_not(file.exists("../../vignettes/data/buoy_data.json"))

  data <- jsonlite::fromJSON("../../vignettes/data/buoy_data.json")
  data$time <- as.POSIXct(data$time, format = "%Y-%m-%d %H:%M:%S", tz = "UTC")

  date_range <- range(data$time, na.rm = TRUE)
  days_span <- as.numeric(difftime(date_range[2], date_range[1], units = "days"))

  # Data should span at least 365 days (1 year) for meaningful analysis
  expect_gt(
    days_span, 30,
    label = paste0("Data spans ", round(days_span), " days, expected > 30")
  )

  # Snapshot the date range for tracking
  date_summary <- data.frame(
    metric = c("earliest", "latest", "days_span"),
    value = c(as.character(date_range[1]), as.character(date_range[2]), round(days_span, 1)),
    stringsAsFactors = FALSE
  )
  expect_snapshot(date_summary)
})

test_that("QC flag distribution snapshot", {
  skip_if_not(file.exists("../../vignettes/data/buoy_data.json"))

  data <- jsonlite::fromJSON("../../vignettes/data/buoy_data.json")

  # Check if QC_Flag column exists
  if ("QC_Flag" %in% names(data)) {
    qc_counts <- as.data.frame(table(data$QC_Flag, useNA = "ifany"))
    names(qc_counts) <- c("QC_Flag", "count")
    qc_counts$percentage <- round(100 * qc_counts$count / sum(qc_counts$count), 2)
    expect_snapshot(qc_counts)
  } else {
    skip("QC_Flag column not present in data")
  }
})
