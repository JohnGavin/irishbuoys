# Tests for R/wave_model.R
# Wave height prediction model functions

# ===========================================================================
# prepare_wave_features
# ===========================================================================

# Helper: minimal valid buoy data
make_buoy_data <- function(n = 20) {
  tibble::tibble(
    station_id = rep("M2", n),
    time = seq(
      as.POSIXct("2026-01-01", tz = "UTC"),
      by = "hour",
      length.out = n
    ),
    wave_height = runif(n, 0.5, 5),
    wind_speed = runif(n, 2, 25),
    gust = runif(n, 5, 35),
    wind_direction = runif(n, 0, 360),
    atmospheric_pressure = rnorm(n, 1013, 10),
    wave_period = runif(n, 4, 12)
  )
}

test_that("prepare_wave_features creates lagged columns", {
  data <- make_buoy_data(20)
  result <- prepare_wave_features(data, lags = 1:3)

  expect_true("wave_height_lag1" %in% names(result))
  expect_true("wave_height_lag2" %in% names(result))
  expect_true("wave_height_lag3" %in% names(result))

  # First row should be NA (no lag available)
  expect_true(is.na(result$wave_height_lag1[1]))
})

test_that("prepare_wave_features creates temporal features", {
  data <- make_buoy_data(10)
  result <- prepare_wave_features(data)

  expect_true("hour" %in% names(result))
  expect_true("month" %in% names(result))
  expect_true(all(result$hour %in% 0:23))
  expect_true(all(result$month %in% 1:12))
})

test_that("prepare_wave_features creates wind direction components", {
  data <- make_buoy_data(10)
  result <- prepare_wave_features(data)

  expect_true("wind_dir_sin" %in% names(result))
  expect_true("wind_dir_cos" %in% names(result))
  expect_true(all(result$wind_dir_sin >= -1 & result$wind_dir_sin <= 1))
  expect_true(all(result$wind_dir_cos >= -1 & result$wind_dir_cos <= 1))
})

test_that("prepare_wave_features creates wave steepness", {
  data <- make_buoy_data(10)
  result <- prepare_wave_features(data)

  expect_true("wave_steepness" %in% names(result))
})

test_that("prepare_wave_features creates gust factor", {
  data <- make_buoy_data(10)
  result <- prepare_wave_features(data)

  expect_true("gust_factor" %in% names(result))
  # Gust factor should be >= 1 in most cases
  valid <- !is.na(result$gust_factor)
  expect_true(any(valid))
})

test_that("prepare_wave_features creates wind speed lag", {
  data <- make_buoy_data(10)
  result <- prepare_wave_features(data)

  expect_true("wind_speed_lag1" %in% names(result))
})

test_that("prepare_wave_features creates pressure change", {
  data <- make_buoy_data(10)
  result <- prepare_wave_features(data)

  expect_true("pressure_change" %in% names(result))
})

test_that("prepare_wave_features handles multi-station data", {
  data1 <- make_buoy_data(10)
  data2 <- make_buoy_data(10)
  data2$station_id <- "M3"
  data <- dplyr::bind_rows(data1, data2)

  result <- prepare_wave_features(data)
  expect_equal(nrow(result), 20)

  # Lag1 should be NA for first row of EACH station
  m2_first <- which(result$station_id == "M2")[1]
  m3_first <- which(result$station_id == "M3")[1]
  expect_true(is.na(result$wave_height_lag1[m2_first]))
  expect_true(is.na(result$wave_height_lag1[m3_first]))
})

test_that("prepare_wave_features works with minimal columns", {
  data <- tibble::tibble(
    station_id = rep("M2", 5),
    time = seq(as.POSIXct("2026-01-01", tz = "UTC"), by = "hour", length.out = 5),
    wave_height = c(1, 2, 3, 2.5, 1.5)
  )

  result <- prepare_wave_features(data)
  expect_true("wave_height_lag1" %in% names(result))
  expect_true("hour" %in% names(result))
  # No wind_speed → no wind_speed_lag1
  expect_false("wind_speed_lag1" %in% names(result))
})

# ===========================================================================
# Defensive checks
# ===========================================================================

test_that("prepare_wave_features rejects NULL", {
  expect_error(prepare_wave_features(NULL), "cannot be NULL")
})

test_that("prepare_wave_features rejects non-data.frame", {
  expect_error(prepare_wave_features("not a df"), "must be a data frame")
})

test_that("prepare_wave_features rejects missing columns", {
  data <- tibble::tibble(x = 1, y = 2)
  expect_error(prepare_wave_features(data), "Missing required columns")
})

test_that("prepare_wave_features rejects empty data", {
  data <- tibble::tibble(
    station_id = character(),
    time = as.POSIXct(character()),
    wave_height = double()
  )
  expect_error(prepare_wave_features(data), "has 0 rows")
})

test_that("prepare_wave_features rejects invalid lags", {
  data <- make_buoy_data(5)
  expect_error(prepare_wave_features(data, lags = -1), "positive integers")
  expect_error(prepare_wave_features(data, lags = "a"), "positive integers")
})
