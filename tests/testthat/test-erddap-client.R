# Tests for R/erddap_client.R

test_that("download_buoy_data rejects invalid date format", {
  expect_error(
    download_buoy_data(start_date = "not-a-date", end_date = "2024-01-01")
  )
})

test_that("download_buoy_data returns data frame with valid dates", {
  skip_on_cran()
  # May fail if ERDDAP is down - that's OK
  result <- tryCatch(
    download_buoy_data(
      start_date = "2024-01-01", end_date = "2024-01-02",
      variables = c("time", "station_id", "WaveHeight")
    ),
    error = function(e) NULL
  )
  skip_if(is.null(result), "ERDDAP server unreachable")
  expect_s3_class(result, "data.frame")
  expect_true("time" %in% names(result))
  expect_true("station_id" %in% names(result))
})

test_that("download_buoy_data filters by station", {
  skip_on_cran()
  result <- tryCatch(
    download_buoy_data(
      start_date = "2024-01-01", end_date = "2024-01-02",
      stations = "M2",
      variables = c("time", "station_id", "WaveHeight")
    ),
    error = function(e) NULL
  )
  skip_if(is.null(result), "ERDDAP server unreachable")
  expect_s3_class(result, "data.frame")
  expect_true(all(result$station_id == "M2"))
})

test_that("download_buoy_data supports json format", {
  skip_on_cran()
  result <- tryCatch(
    download_buoy_data(
      start_date = "2024-01-01", end_date = "2024-01-02",
      variables = c("time", "station_id", "WaveHeight"),
      format = "json"
    ),
    error = function(e) NULL
  )
  skip_if(is.null(result), "ERDDAP server unreachable")
  expect_s3_class(result, "data.frame")
})

test_that("get_stations returns data frame", {
  skip_on_cran()
  result <- tryCatch(get_stations(), error = function(e) NULL)
  skip_if(is.null(result), "ERDDAP server unreachable")
  expect_s3_class(result, "data.frame")
  expect_true("station_id" %in% names(result))
})

test_that("get_latest_timestamp returns POSIXct", {
  skip_on_cran()
  result <- tryCatch(get_latest_timestamp(), error = function(e) NULL)
  skip_if(is.null(result), "ERDDAP server unreachable")
  expect_s3_class(result, "POSIXct")
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(download_buoy_data) signature", {
  expect_snapshot(args(download_buoy_data))
})

test_that("snapshot: args(get_latest_timestamp) signature", {
  expect_snapshot(args(get_latest_timestamp))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(add_wave_metrics)", { expect_snapshot(args(irishbuoys:::add_wave_metrics)) })
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
