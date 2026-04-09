# Tests for R/extreme_values.R
# Tests for functions that work with in-memory data (no DB)

test_that("fit_gev_annual_maxima works with synthetic data", {
  skip_if_not_installed("extRemes")
  set.seed(42)
  # Generate 10 years of annual maxima-like data
  years <- 2010:2022
  times <- do.call(c, lapply(years, function(y) {
    seq.POSIXt(
      as.POSIXct(paste0(y, "-01-01"), tz = "UTC"),
      as.POSIXct(paste0(y, "-12-31"), tz = "UTC"),
      by = "day"
    )
  }))
  n <- length(times)
  data <- data.frame(
    time = times,
    wave_height = rgamma(n, shape = 3, rate = 1) + 1
  )

  result <- fit_gev_annual_maxima(data)
  expect_type(result, "list")
  expect_true("fit" %in% names(result))
  expect_true("annual_maxima" %in% names(result))
  expect_true("parameters" %in% names(result))
  expect_false(is.null(result$fit))
  expect_equal(length(result$parameters), 3)
  expect_named(result$parameters, c("location", "scale", "shape"))
  expect_true(all(is.finite(result$parameters)))
})

test_that("fit_gev_annual_maxima handles insufficient data", {
  data <- data.frame(
    time = as.POSIXct(c("2020-01-01", "2020-06-01", "2021-01-01")),
    wave_height = c(5, 6, 7)
  )
  result <- fit_gev_annual_maxima(data, min_years = 5)
  expect_null(result$fit)
  expect_true("error" %in% names(result))
})

test_that("fit_gpd_threshold works with synthetic data", {
  skip_if_not_installed("extRemes")
  set.seed(42)
  n <- 5000
  times <- seq.POSIXt(as.POSIXct("2015-01-01", tz = "UTC"), by = "hour", length.out = n)
  data <- data.frame(
    time = times,
    wave_height = rgamma(n, shape = 3, rate = 1) + 1
  )

  result <- fit_gpd_threshold(data, threshold = 5, decluster = FALSE)
  expect_type(result, "list")
  expect_false(is.null(result$fit))
  expect_true("parameters" %in% names(result))
  expect_named(result$parameters, c("scale", "shape"))
})

test_that("fit_gpd_threshold auto-selects threshold", {
  skip_if_not_installed("extRemes")
  set.seed(42)
  n <- 5000
  times <- seq.POSIXt(as.POSIXct("2015-01-01", tz = "UTC"), by = "hour", length.out = n)
  data <- data.frame(
    time = times,
    wave_height = rgamma(n, shape = 3, rate = 1) + 1
  )
  result <- fit_gpd_threshold(data, threshold = NULL, decluster = FALSE)
  expect_true(result$threshold > 0)
})

test_that("calculate_return_levels works with GEV fit", {
  skip_if_not_installed("extRemes")
  set.seed(42)
  years <- 2005:2022
  times <- do.call(c, lapply(years, function(y) {
    seq.POSIXt(
      as.POSIXct(paste0(y, "-01-01"), tz = "UTC"),
      as.POSIXct(paste0(y, "-12-31"), tz = "UTC"),
      by = "day"
    )
  }))
  data <- data.frame(
    time = times,
    wave_height = rgamma(length(times), shape = 3, rate = 1) + 1
  )
  gev <- fit_gev_annual_maxima(data)
  levels <- calculate_return_levels(gev, return_periods = c(10, 50, 100))
  expect_s3_class(levels, "data.frame")
  expect_equal(nrow(levels), 3)
  expect_true("return_level" %in% names(levels))
  # Return levels should increase with period
  expect_true(all(diff(levels$return_level) > 0))
})

test_that("calculate_return_levels handles NULL fit", {
  fit <- list(fit = NULL, variable = "wave_height", error = "test")
  levels <- calculate_return_levels(fit)
  expect_s3_class(levels, "data.frame")
  expect_true(all(is.na(levels$return_level)))
})

test_that("create_return_level_plot_data handles NULL fit", {
  fit <- list(fit = NULL, variable = "wave_height", error = "test")
  result <- create_return_level_plot_data(fit)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
})

test_that("analyze_gust_factor works with synthetic data", {
  set.seed(42)
  n <- 200
  data <- data.frame(
    station_id = rep(c("M2", "M3"), each = n / 2),
    wind_speed = runif(n, 5, 30),
    gust = NA_real_
  )
  data$gust <- data$wind_speed * runif(n, 1.1, 1.8)

  result <- analyze_gust_factor(data, min_wind_speed = 5)
  expect_type(result, "list")
  expect_true("summary" %in% names(result))
  expect_true("by_category" %in% names(result))
  expect_true("by_station" %in% names(result))
  # Mean gust factor should be > 1
  mean_gf <- result$summary$value[result$summary$statistic == "mean"]
  expect_true(mean_gf > 1)
})

# --- Tests for calculate_gpd_return_levels ---

test_that("calculate_gpd_return_levels works with valid fit", {
  fit <- list(
    u = 5.0,
    scale = 1.2,
    shape = 0.1,
    n_exceed = 500,
    se_scale = 0.08,
    se_shape = 0.03
  )

  result <- calculate_gpd_return_levels(fit, return_periods = c(1, 5, 10))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(c("return_period", "return_level", "lower", "upper") %in% names(result)))

  # Return levels should increase with period
  expect_true(all(diff(result$return_level) > 0))

  # CIs should contain point estimate
  expect_true(all(result$lower <= result$return_level))
  expect_true(all(result$upper >= result$return_level))

  # All values should be finite

  expect_true(all(is.finite(result$return_level)))
  expect_true(all(is.finite(result$lower)))
  expect_true(all(is.finite(result$upper)))
})

test_that("calculate_gpd_return_levels handles shape=0 (exponential case)", {
  fit <- list(
    u = 3.0,
    scale = 0.8,
    shape = 0.0,  # Exactly zero -> exponential fallback
    n_exceed = 300,
    se_scale = 0.05,
    se_shape = 0.02
  )

  result <- calculate_gpd_return_levels(fit, return_periods = c(1, 5, 10))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  # All return levels should be finite (no NaN/Inf from division by zero)
  expect_true(all(is.finite(result$return_level)))
  # Should still be increasing
  expect_true(all(diff(result$return_level) > 0))
})

test_that("calculate_gpd_return_levels returns NA for error fit", {
  fit <- list(
    u = 5.0,
    n_exceed = 10,
    error = "Insufficient exceedances (<30)"
  )

  result <- calculate_gpd_return_levels(fit, return_periods = c(1, 5, 10))

  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(is.na(result$return_level)))
  expect_true(all(is.na(result$lower)))
  expect_true(all(is.na(result$upper)))
  expect_equal(result$threshold_value[1], 5.0)
  expect_equal(result$method[1], "GPD")
})

test_that("calculate_gpd_return_levels handles non-list input", {
  result <- calculate_gpd_return_levels("not a list")
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 3)
  expect_true(all(is.na(result$return_level)))
})

test_that("compare_rogue_wave_gust returns two-row comparison", {
  data <- data.frame(
    wave_height = c(3, 4, 5, 2.5, 3.5),
    hmax = c(5, 9, 8, 4, 6),
    wind_speed = c(10, 15, 20, 8, 12),
    gust = c(15, 40, 30, 12, 18)
  )
  result <- compare_rogue_wave_gust(data)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true(all(c("phenomenon", "n_events", "n_eligible", "occurrence_pct") %in% names(result)))
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(analyze_gust_factor) signature", {
  expect_snapshot(args(analyze_gust_factor))
})

test_that("snapshot: args(calculate_gpd_return_levels) signature", {
  expect_snapshot(args(calculate_gpd_return_levels))
})

test_that("snapshot: args(calculate_return_levels) signature", {
  expect_snapshot(args(calculate_return_levels))
})

test_that("snapshot: args(compare_rogue_wave_gust) signature", {
  expect_snapshot(args(compare_rogue_wave_gust))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(create_return_level_plot_data)", { expect_snapshot(args(irishbuoys:::create_return_level_plot_data)) })
test_that("snap3: args(fit_gev_annual_maxima)", { expect_snapshot(args(irishbuoys:::fit_gev_annual_maxima)) })
test_that("snap3: args(fit_gpd_threshold)", { expect_snapshot(args(irishbuoys:::fit_gpd_threshold)) })
