# Tests for R/validation.R
# Tests for validate_buoy_data and related functions

test_that("validate_buoy_data rejects NULL", {
  expect_error(validate_buoy_data(NULL), "cannot be NULL")
})

test_that("validate_buoy_data rejects non-data.frame", {
  expect_error(validate_buoy_data("string"), "must be a data frame")
  expect_error(validate_buoy_data(list(a = 1)), "must be a data frame")
})

test_that("validate_buoy_data rejects insufficient rows", {
  data <- data.frame(station_id = "M2", time = Sys.time(), wave_height = 3)
  expect_error(validate_buoy_data(data, min_rows = 100), "insufficient rows")
})

test_that("validate_buoy_data passes with valid data", {
  skip_if_not_installed("pointblank")
  set.seed(42)
  n <- 200
  data <- data.frame(
    station_id = sample(c("M2", "M3", "M4"), n, replace = TRUE),
    time = seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n),
    wave_height = runif(n, 0.5, 10),
    hmax = runif(n, 1, 20),
    wind_speed = runif(n, 0, 40),
    gust = runif(n, 0, 60),
    atmospheric_pressure = runif(n, 980, 1040)
  )
  result <- validate_buoy_data(data, min_rows = 100)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), n)
})

test_that("validate_rogue_events rejects insufficient rows", {
  skip_if_not_installed("pointblank")
  data <- data.frame(
    station_id = character(0), time = as.POSIXct(character(0)),
    wave_height = numeric(0), hmax = numeric(0), rogue_ratio = numeric(0)
  )
  expect_error(validate_rogue_events(data, min_rows = 1), "insufficient rows")
})

test_that("validate_rogue_events passes with valid data", {
  skip_if_not_installed("pointblank")
  data <- data.frame(
    station_id = c("M2", "M3"),
    time = Sys.time() + 1:2,
    wave_height = c(5, 6),
    hmax = c(11, 13),
    rogue_ratio = c(2.2, 2.17)
  )
  result <- validate_rogue_events(data, min_rows = 1)
  expect_s3_class(result, "data.frame")
})
