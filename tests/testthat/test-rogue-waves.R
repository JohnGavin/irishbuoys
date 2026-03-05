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

# --- Tests for test_rogue_propagation ---

test_that("test_rogue_propagation returns expected structure", {
  set.seed(42)
  n <- 2000
  time_seq <- seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n)

  # Two stations with some rogue events
  data <- data.frame(
    time = rep(time_seq, 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = c(rgamma(n, 4, 1.2), rgamma(n, 3.5, 1.2)),
    hmax = c(rgamma(n, 6, 1.0), rgamma(n, 5.5, 1.0)),
    stringsAsFactors = FALSE
  )

  result <- test_rogue_propagation(
    data,
    station_pairs = list(c("M2", "M3")),
    n_permutations = 20
  )

  expect_type(result, "list")
  expect_true("h3_table" %in% names(result))
  expect_true("rogue_events" %in% names(result))
  expect_true("n_rogue_total" %in% names(result))

  h3 <- result$h3_table
  expect_s3_class(h3, "data.frame")
  expected_cols <- c(
    "station1", "station2", "distance_km", "theoretical_lag_hrs",
    "n_rogue_s1", "n_rogue_s2", "p_value", "h3_significant", "h3_verdict"
  )
  expect_true(all(expected_cols %in% names(h3)))
})

test_that("test_rogue_propagation errors on missing columns", {
  data <- data.frame(time = Sys.time(), station_id = "M2", wave_height = 3)
  expect_error(
    test_rogue_propagation(data),
    "Missing required columns"
  )
})

test_that("test_rogue_propagation handles no rogue events", {
  set.seed(42)
  n <- 200
  # All hmax/wave_height ratios < 2 so no rogues
  data <- data.frame(
    time = rep(seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n), 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = rep(3, 2 * n),
    hmax = rep(4, 2 * n),
    stringsAsFactors = FALSE
  )

  result <- test_rogue_propagation(data, n_permutations = 10)
  expect_equal(nrow(result$h3_table), 0)
  expect_equal(result$n_rogue_total, 0)
})

test_that("test_rogue_propagation skips pairs with too few rogues", {
  set.seed(42)
  n <- 500
  time_seq <- seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n)

  # M2 gets many rogues, M3 gets only 1
  wh_m2 <- rep(3, n)
  hmax_m2 <- rep(4, n)
  hmax_m2[1:20] <- 8  # 20 rogues

  wh_m3 <- rep(3, n)
  hmax_m3 <- rep(4, n)
  hmax_m3[1] <- 8  # Only 1 rogue

  data <- data.frame(
    time = rep(time_seq, 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = c(wh_m2, wh_m3),
    hmax = c(hmax_m2, hmax_m3),
    stringsAsFactors = FALSE
  )

  result <- test_rogue_propagation(
    data,
    station_pairs = list(c("M2", "M3")),
    n_permutations = 10
  )

  h3 <- result$h3_table
  expect_equal(nrow(h3), 1)
  # Should be INCONCLUSIVE due to too few rogues at M3
  expect_true(grepl("INCONCLUSIVE", h3$h3_verdict))
  expect_true(is.na(h3$p_value))
})

test_that("test_rogue_propagation filters to valid station pairs", {
  set.seed(42)
  n <- 200
  # Only M2 data, no M3/M6 — should yield no valid pairs
  data <- data.frame(
    time = seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n),
    station_id = "M2",
    wave_height = rgamma(n, 4, 1.2),
    hmax = rgamma(n, 8, 1.0),
    stringsAsFactors = FALSE
  )

  result <- test_rogue_propagation(data, n_permutations = 10)
  expect_equal(nrow(result$h3_table), 0)
})
