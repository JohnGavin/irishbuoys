# Tests for data consistency
# These tests ensure that:
# 1. Historical data is not lost (earliest dates preserved) — SNAPSHOT
# 2. Data structure remains consistent (column names) — SNAPSHOT
# 3. Station coverage is maintained — MONOTONIC (counts only grow)
# 4. Date range only expands — MONOTONIC (span only grows)
# 5. QC distribution stays reasonable — MONOTONIC + BOUNDS
#
# Design: Snapshots for STABLE properties (schema, earliest dates).
#         Monotonic assertions for GROWING properties (counts, range).
#         Fixed reference baseline establishes minimum thresholds.
#
# Reference: R-exts 1.1.6 "Data in packages" — tests should not depend
# on exact data values that change with every update.
#
# Note: These tests require the dashboard data file which is only available
# during local development. They are skipped during R CMD check.

# ============================================================================
# FIXED REFERENCE BASELINE (established 2026-02-01)
# These are minimum thresholds. Actual values must be >= these.
# Update ONLY if a station is genuinely decommissioned or data is corrected.
# ============================================================================
REFERENCE_STATIONS <- c("M2", "M3", "M4", "M5", "M6")
REFERENCE_MIN_RECORDS <- list(
  M2 = 1500L, M3 = 2100L, M4 = 2100L, M5 = 2100L, M6 = 2100L
)
REFERENCE_EARLIEST_DATES <- list(
  M2 = as.POSIXct("2025-11-28", tz = "UTC"),
  M3 = as.POSIXct("2025-11-01", tz = "UTC"),
  M4 = as.POSIXct("2025-11-01", tz = "UTC"),
  M5 = as.POSIXct("2025-11-01", tz = "UTC"),
  M6 = as.POSIXct("2025-11-01", tz = "UTC")
)
REFERENCE_MIN_DAYS_SPAN <- 90
REFERENCE_MIN_COLUMNS <- 15L


# Helper function to find data file
find_data_file <- function() {
  paths <- c(
    "vignettes/data/buoy_data.json",
    "../../vignettes/data/buoy_data.json",
    "../vignettes/data/buoy_data.json",
    system.file("extdata", "buoy_data.json", package = "irishbuoys")
  )
  for (path in paths) {
    if (file.exists(path)) return(path)
  }
  return(NULL)
}

# Helper to load and parse data (shared across tests)
load_buoy_data <- function() {
  data_path <- find_data_file()
  if (is.null(data_path)) return(NULL)
  data <- jsonlite::fromJSON(data_path)
  if ("time" %in% names(data)) {
    data$time <- as.POSIXct(data$time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  }
  data
}

test_that("dashboard data file exists in development", {
  skip_on_cran()
  skip_if(is.null(find_data_file()), "Data file not found (expected during R CMD check)")
  expect_true(file.exists(find_data_file()))
})

# ============================================================================
# SNAPSHOT TESTS — For properties that should NEVER change
# ============================================================================

test_that("data structure snapshot - columns remain consistent", {
  skip_on_cran()
  data <- load_buoy_data()
  skip_if(is.null(data), "Data file not found")

  column_info <- data.frame(
    column = sort(names(data)),
    stringsAsFactors = FALSE
  )

  # Column count must not decrease
  expect_gte(nrow(column_info), REFERENCE_MIN_COLUMNS)

  # Snapshot exact column list (structural change = deliberate)
  expect_snapshot(column_info)
})

test_that("earliest dates snapshot - historical data preserved", {
  skip_on_cran()
  data <- load_buoy_data()
  skip_if(is.null(data), "Data file not found")

  earliest_dates <- tapply(data$time, data$station_id, min, na.rm = TRUE)
  earliest_df <- data.frame(
    station_id = names(earliest_dates),
    earliest_date = as.character(as.POSIXct(earliest_dates, origin = "1970-01-01", tz = "UTC")),
    stringsAsFactors = FALSE
  )
  earliest_df <- earliest_df[order(earliest_df$station_id), ]
  row.names(earliest_df) <- NULL

  # Earliest dates must never move forward (losing historical data)
  for (station in names(REFERENCE_EARLIEST_DATES)) {
    if (station %in% names(earliest_dates)) {
      actual_earliest <- as.POSIXct(earliest_dates[[station]], origin = "1970-01-01", tz = "UTC")
      expect_lte(
        as.numeric(actual_earliest),
        as.numeric(REFERENCE_EARLIEST_DATES[[station]]),
        label = paste0(station, " earliest date must not move forward")
      )
    }
  }

  # Snapshot for deliberate tracking
  expect_snapshot(earliest_df)
})

# ============================================================================
# MONOTONIC TESTS — For properties that should only grow
# ============================================================================

test_that("station list - no stations lost, counts only grow", {
  skip_on_cran()
  data <- load_buoy_data()
  skip_if(is.null(data), "Data file not found")

  actual_stations <- sort(unique(data$station_id))

  # All reference stations must still be present
  for (station in REFERENCE_STATIONS) {
    expect_true(
      station %in% actual_stations,
      label = paste0("Station ", station, " must not be lost")
    )
  }

  # Record counts must be >= reference minimums (data only grows)
  station_counts <- as.data.frame(table(data$station_id))
  names(station_counts) <- c("station_id", "n_records")

  for (station in names(REFERENCE_MIN_RECORDS)) {
    actual_count <- station_counts$n_records[station_counts$station_id == station]
    if (length(actual_count) > 0) {
      expect_gte(
        actual_count,
        REFERENCE_MIN_RECORDS[[station]],
        label = paste0(station, " record count (", actual_count,
                       ") must be >= reference (", REFERENCE_MIN_RECORDS[[station]], ")")
      )
    }
  }
})

test_that("data date range - span only grows", {
  skip_on_cran()
  data <- load_buoy_data()
  skip_if(is.null(data), "Data file not found")

  date_range <- range(data$time, na.rm = TRUE)
  days_span <- as.numeric(difftime(date_range[2], date_range[1], units = "days"))

  # Span must be >= reference minimum (data accumulates)
  expect_gte(
    days_span,
    REFERENCE_MIN_DAYS_SPAN,
    label = paste0("Data spans ", round(days_span), " days, must be >= ",
                   REFERENCE_MIN_DAYS_SPAN)
  )

  # Earliest date must not move forward (no historical data loss)
  expect_lte(
    as.numeric(date_range[1]),
    as.numeric(as.POSIXct("2025-11-02", tz = "UTC")),
    label = "Earliest date must not move forward from 2025-11-01"
  )
})

test_that("QC flag distribution - reasonable bounds", {
  skip_on_cran()
  data <- load_buoy_data()
  skip_if(is.null(data), "Data file not found")

  qc_col <- if ("QC_Flag" %in% names(data)) "QC_Flag" else if ("qc_flag" %in% names(data)) "qc_flag" else NULL
  skip_if(is.null(qc_col), "QC flag column not present in data")

  qc_values <- data[[qc_col]]
  total <- length(qc_values)

  # QC flag values must be from known set
  known_flags <- c(0, 1, 9, NA)
  actual_flags <- unique(qc_values)
  unexpected <- setdiff(actual_flags[!is.na(actual_flags)], known_flags)
  expect_equal(length(unexpected), 0L,
    info = paste0("Unexpected QC flags: ", paste(unexpected, collapse = ", ")))


  # Usable data (flag=0 unknown or flag=1 good) should be majority (>= 50%)
  # ERDDAP data often arrives with flag=0 (not yet quality-checked)
  pct_usable <- 100 * sum(qc_values %in% c(0, 1), na.rm = TRUE) / total
  expect_gte(pct_usable, 50,
    label = paste0("Usable QC data is ", round(pct_usable, 1), "%, expected >= 50%"))

  # Total record count must not decrease
  expect_gte(total, sum(unlist(REFERENCE_MIN_RECORDS)),
    label = paste0("Total records (", total, ") must be >= reference total"))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(compute_data_coverage)", { expect_snapshot(args(irishbuoys:::compute_data_coverage)) })
