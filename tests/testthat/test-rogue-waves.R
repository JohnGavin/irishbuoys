# Tests for R/rogue_waves.R
# Tests for functions that don't require DB connections

test_that("calculate_wave_steepness computes correctly", {
  # Known case: 3m wave, 8s period
  # Wavelength = 1.56 * 8^2 = 99.84m
  # Steepness = 3 / 99.84 = 0.03
  steepness <- calculate_wave_steepness(3, 8)
  expect_equal(steepness, 3 / (1.56 * 64), tolerance = 0.001)
})

test_that("calculate_wave_steepness vectorized", {
  heights <- c(1, 2, 3)
  periods <- c(5, 8, 10)
  steepness <- calculate_wave_steepness(heights, periods)
  expect_length(steepness, 3)
  expected <- heights / (1.56 * periods^2)
  expect_equal(steepness, expected)
})

test_that("calculate_wave_steepness rejects NULL", {
  expect_error(calculate_wave_steepness(NULL, 8), "cannot be NULL")
  expect_error(calculate_wave_steepness(3, NULL), "cannot be NULL")
})

test_that("calculate_wave_steepness rejects non-numeric", {
  expect_error(calculate_wave_steepness("3", 8), "must be numeric")
  expect_error(calculate_wave_steepness(3, "8"), "must be numeric")
})

test_that("add_wave_metrics adds expected columns", {
  data <- data.frame(
    wave_height = c(2, 3, 5, 2.5),
    hmax = c(3, 4, 12, 4),
    wave_period = c(8, 10, 12, 7)
  )
  result <- add_wave_metrics(data)
  expect_true("rogue_ratio" %in% names(result))
  expect_true("is_rogue" %in% names(result))
  expect_true("steepness" %in% names(result))
  expect_true("danger_level" %in% names(result))
})

test_that("add_wave_metrics detects rogue waves correctly", {
  data <- data.frame(
    wave_height = c(3, 3, 1),
    hmax = c(7, 5, 3),  # ratio: 2.33, 1.67, 3.0
    wave_period = c(10, 10, 10)
  )
  result <- add_wave_metrics(data, rogue_threshold = 2.0)
  # Row 1: ratio 2.33 and wave_height >= 2 -> rogue
  expect_true(result$is_rogue[1])
  # Row 2: ratio 1.67 -> not rogue
  expect_false(result$is_rogue[2])
  # Row 3: ratio 3.0 but wave_height < 2 -> not rogue
  expect_false(result$is_rogue[3])
})

test_that("add_wave_metrics classifies danger levels", {
  data <- data.frame(
    wave_height = c(1, 3, 5),
    hmax = c(2, 4, 8),
    wave_period = c(10, 8, 5)
  )
  result <- add_wave_metrics(data)
  # Steepness: 1/(1.56*100)=0.0064 (safe), 3/(1.56*64)=0.03 (safe), 5/(1.56*25)=0.128 (dangerous)
  expect_equal(result$danger_level[1], "safe")
  expect_equal(result$danger_level[3], "dangerous")
})

test_that("add_wave_metrics rejects NULL", {
  expect_error(add_wave_metrics(NULL), "cannot be NULL")
})

test_that("add_wave_metrics rejects non-data.frame", {
  expect_error(add_wave_metrics("not a df"), "must be a data frame")
})

test_that("add_wave_metrics rejects missing columns", {
  data <- data.frame(wave_height = 1, hmax = 2)  # missing wave_period
  expect_error(add_wave_metrics(data), "Missing required columns")
})

test_that("add_wave_metrics handles empty data", {
  data <- data.frame(wave_height = numeric(0), hmax = numeric(0), wave_period = numeric(0))
  # cli::cli_alert_warning doesn't trigger expect_warning, so just check output
  result <- add_wave_metrics(data)
  expect_equal(nrow(result), 0)
  expect_true("rogue_ratio" %in% names(result))
})

test_that("detect_rogue_waves rejects NULL connection", {
  expect_error(detect_rogue_waves(NULL), "cannot be NULL")
})

test_that("detect_rogue_waves rejects non-DBI connection", {
  expect_error(detect_rogue_waves("not_a_connection"), "must be a DBI connection")
})

test_that("detect_rogue_waves rejects bad threshold", {
  skip("Requires DBI connection mock")
})

test_that("compare_rogue_wave_gust handles valid data", {
  data <- data.frame(
    wave_height = c(3, 4, 2, 5, NA),
    hmax = c(5, 9, 3, 8, 6),
    wind_speed = c(10, 15, 3, 20, 12),
    gust = c(15, 45, 5, 30, 18)
  )
  result <- compare_rogue_wave_gust(data)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true("Rogue Wave" %in% result$phenomenon)
  expect_true("Rogue Gust" %in% result$phenomenon)
})

test_that("compare_rogue_wave_gust handles all-NA wave data", {
  data <- data.frame(
    wave_height = rep(NA, 5),
    hmax = rep(NA, 5),
    wind_speed = c(10, 15, 20, 25, 30),
    gust = c(15, 20, 30, 35, 45)
  )
  result <- compare_rogue_wave_gust(data)
  expect_equal(result$n_events[1], 0)  # No rogue waves
})
