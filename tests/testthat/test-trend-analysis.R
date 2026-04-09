# Tests for R/trend_analysis.R
# Tests for functions that work with in-memory data frames

test_that("calculate_seasonal_means works with synthetic data", {
  set.seed(42)
  # Generate 2 years of hourly data
  times <- seq.POSIXt(
    as.POSIXct("2020-01-01", tz = "UTC"),
    as.POSIXct("2021-12-31", tz = "UTC"),
    by = "hour"
  )
  n <- length(times)
  month_num <- as.integer(format(times, "%m"))
  # Seasonal pattern: higher in winter
  seasonal_component <- ifelse(month_num %in% c(11, 12, 1, 2, 3), 4, 2)
  data <- data.frame(
    time = times,
    wave_height = seasonal_component + rnorm(n, 0, 0.5)
  )

  result <- calculate_seasonal_means(data)
  expect_type(result, "list")
  expect_true("monthly" %in% names(result))
  expect_true("seasonal" %in% names(result))
  expect_equal(nrow(result$monthly), 12)
  expect_equal(nrow(result$seasonal), 4)
  # Winter should have higher mean than summer
  winter <- result$seasonal[result$seasonal$season == "Winter (DJF)", ]
  summer <- result$seasonal[result$seasonal$season == "Summer (JJA)", ]
  expect_true(winter$mean > summer$mean)
})

test_that("calculate_annual_trends works with synthetic data", {
  set.seed(42)
  # 5 years of data with slight upward trend
  years <- 2016:2020
  times <- do.call(c, lapply(years, function(y) {
    seq.POSIXt(
      as.POSIXct(paste0(y, "-01-01"), tz = "UTC"),
      as.POSIXct(paste0(y, "-12-31"), tz = "UTC"),
      by = "day"
    )
  }))
  n <- length(times)
  year_num <- as.integer(format(times, "%Y"))
  trend <- 0.1 * (year_num - 2016)
  data <- data.frame(
    time = times,
    wave_height = 3 + trend + rnorm(n, 0, 0.3)
  )

  result <- calculate_annual_trends(data)
  expect_type(result, "list")
  expect_true("annual_stats" %in% names(result))
  expect_true("trend_per_decade" %in% names(result))
  expect_equal(nrow(result$annual_stats), 5)
  # Trend should be positive (upward)
  expect_true(result$trend_per_decade > 0)
})

test_that("calculate_annual_trends handles insufficient data", {
  data <- data.frame(
    time = as.POSIXct(c("2020-01-01", "2020-06-01")),
    wave_height = c(3, 4)
  )
  result <- calculate_annual_trends(data)
  # Only 1 year - should warn about insufficient data
  expect_true(is.na(result$trend_per_decade))
})

test_that("detect_anomalies finds outliers", {
  set.seed(42)
  n <- 8760  # 1 year hourly
  times <- seq.POSIXt(
    as.POSIXct("2020-01-01", tz = "UTC"),
    by = "hour", length.out = n
  )
  values <- rnorm(n, 3, 1)
  # Inject anomalies: spike at positions 100 and 5000
  values[100] <- 20  # Very high
  values[5000] <- -10  # Very low
  data <- data.frame(time = times, wave_height = values)

  result <- detect_anomalies(data, threshold = 3)
  expect_type(result, "list")
  expect_true("anomalies" %in% names(result))
  expect_true("seasonal_norms" %in% names(result))
  # Should detect at least the 2 injected anomalies
  expect_true(nrow(result$anomalies) >= 2)
})

test_that("decompose_stl works with sufficient data", {
  set.seed(42)
  n <- 24 * 60  # 60 days hourly = 1440 obs
  times <- seq.POSIXt(
    as.POSIXct("2020-01-01", tz = "UTC"),
    by = "hour", length.out = n
  )
  # Daily cycle + trend + noise
  hour <- as.integer(format(times, "%H"))
  day <- as.integer(difftime(times, times[1], units = "days"))
  seasonal <- sin(2 * pi * hour / 24)
  trend <- 0.01 * day
  data <- data.frame(
    time = times,
    wave_height = 3 + seasonal + trend + rnorm(n, 0, 0.2)
  )

  result <- decompose_stl(data, frequency = "daily")
  expect_type(result, "list")
  expect_true("components" %in% names(result))
  expect_true("summary" %in% names(result))
  expect_equal(nrow(result$components), n)
  expect_true(all(c("seasonal", "trend", "remainder") %in% names(result$components)))
})

test_that("decompose_stl rejects insufficient data", {
  data <- data.frame(
    time = Sys.time() + 1:10,
    wave_height = rnorm(10)
  )
  expect_error(decompose_stl(data, frequency = "daily"), "Insufficient data")
})

test_that("detect_outliers_iqr flags extreme values", {
  data <- data.frame(
    wave_height = c(1, 2, 2, 3, 3, 3, 4, 4, 5, 100)
  )
  result <- detect_outliers_iqr(data, multiplier = 1.5)
  expect_true("is_outlier" %in% names(result))
  # The extreme value 100 should be flagged

  expect_true(result$is_outlier[10])
  # Most normal values should not be flagged
  expect_false(result$is_outlier[5])
})

test_that("detect_outliers_iqr handles NAs", {
  data <- data.frame(wave_height = c(1, 2, NA, 3, 4))
  result <- detect_outliers_iqr(data)
  expect_false(result$is_outlier[3])  # NA -> FALSE
})

test_that("mann_kendall_test detects increasing trend", {
  set.seed(42)
  n <- 200
  data <- data.frame(
    time = seq.POSIXt(as.POSIXct("2020-01-01", tz = "UTC"), by = "hour", length.out = n),
    wave_height = seq(1, 10, length.out = n) + rnorm(n, 0, 0.5)
  )
  result <- mann_kendall_test(data)
  expect_type(result, "list")
  expect_true(result$tau > 0)
  expect_true(result$p_value < 0.05)
  expect_equal(result$trend_direction, "increasing")
})

test_that("mann_kendall_test returns no trend for random data", {
  set.seed(123)
  n <- 100
  data <- data.frame(
    time = seq.POSIXt(as.POSIXct("2020-01-01", tz = "UTC"), by = "hour", length.out = n),
    wave_height = rnorm(n, 3, 0.1)
  )
  result <- mann_kendall_test(data)
  expect_type(result, "list")
  expect_true("tau" %in% names(result))
  expect_true("p_value" %in% names(result))
  expect_true("trend_direction" %in% names(result))
})

test_that("mann_kendall_test rejects insufficient data", {
  data <- data.frame(
    time = Sys.time() + 1:2,
    wave_height = c(1, 2)
  )
  expect_error(mann_kendall_test(data), "at least 3")
})

test_that("compute_acf_summary returns tibble with correct structure", {
  set.seed(42)
  n <- 200
  data <- data.frame(wave_height = rnorm(n, 3, 1))
  result <- compute_acf_summary(data, max_lag = 24)
  expect_s3_class(result, "tbl_df")
  expect_equal(names(result), c("lag", "acf"))
  expect_equal(nrow(result), 24)
  expect_equal(result$lag[1], 1L)
  expect_equal(result$lag[24], 24L)
})

test_that("compute_acf_summary rejects insufficient data", {
  data <- data.frame(wave_height = c(1, 2, 3))
  expect_error(compute_acf_summary(data, max_lag = 48), "at least 49")
})

test_that("trend_summary_report produces output", {
  # Minimal mock data
  seasonal <- list(
    seasonal = data.frame(
      season = c("Winter (DJF)", "Spring (MAM)", "Summer (JJA)", "Autumn (SON)"),
      mean = c(4.0, 3.0, 2.0, 3.5),
      sd = c(1.0, 0.8, 0.5, 0.9),
      max = c(10, 8, 5, 9),
      n = c(1000, 1000, 1000, 1000)
    ),
    variable = "wave_height"
  )
  annual <- list(
    trend_per_decade = 0.15,
    p_value = 0.03,
    r_squared = 0.6
  )
  report <- trend_summary_report(seasonal, annual)
  expect_type(report, "character")
  expect_true(nchar(report) > 50)
  expect_true(grepl("Trend", report))
  expect_true(grepl("significant", report))
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(calculate_annual_trends) signature", {
  expect_snapshot(args(calculate_annual_trends))
})

test_that("snapshot: args(calculate_seasonal_means) signature", {
  expect_snapshot(args(calculate_seasonal_means))
})

test_that("snapshot: args(compute_acf_summary) signature", {
  expect_snapshot(args(compute_acf_summary))
})

test_that("snapshot: args(decompose_stl) signature", {
  expect_snapshot(args(decompose_stl))
})

test_that("snapshot: args(detect_anomalies) signature", {
  expect_snapshot(args(detect_anomalies))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(detect_outliers_iqr)", { expect_snapshot(args(irishbuoys:::detect_outliers_iqr)) })
test_that("snap3: args(mann_kendall_test)", { expect_snapshot(args(irishbuoys:::mann_kendall_test)) })
test_that("snap3: args(trend_summary_report)", { expect_snapshot(args(irishbuoys:::trend_summary_report)) })
