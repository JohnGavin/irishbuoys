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
