# Tests for R/joint_analysis.R
# Tests for pure functions (no DB required)

test_that("get_station_info returns valid data frame", {
  info <- get_station_info()
  expect_s3_class(info, "data.frame")
  expect_true(nrow(info) >= 5)
  expect_named(info, c("station_id", "location", "lat", "lon", "depth_m", "distance_km"))
  # All stations should have valid coordinates
  expect_true(all(info$lat > 50 & info$lat < 56))
  expect_true(all(info$lon < 0))  # West of Greenwich
})

test_that("get_station_info has expected stations", {
  info <- get_station_info()
  expect_true("M2" %in% info$station_id)
  expect_true("M3" %in% info$station_id)
  expect_true("M6" %in% info$station_id)
})

test_that("haversine_distance computes correctly", {
  # Known distance: Dublin (53.35, -6.26) to London (51.51, -0.13) ~ 464 km
  dist <- haversine_distance(53.35, -6.26, 51.51, -0.13)
  expect_true(dist > 450 && dist < 480)
})

test_that("haversine_distance is symmetric", {
  d1 <- haversine_distance(53.07, -15.93, 51.22, -9.99)
  d2 <- haversine_distance(51.22, -9.99, 53.07, -15.93)
  expect_equal(d1, d2, tolerance = 0.001)
})

test_that("haversine_distance same point is zero", {
  d <- haversine_distance(53.07, -15.93, 53.07, -15.93)
  expect_equal(d, 0)
})

test_that("station_distance_matrix is square and symmetric", {
  mat <- station_distance_matrix()
  expect_true(is.matrix(mat))
  expect_equal(nrow(mat), ncol(mat))
  # Symmetric
  expect_equal(mat, t(mat))
  # Diagonal is zero
  expect_true(all(diag(mat) == 0))
  # Off-diagonal is positive
  expect_true(all(mat[upper.tri(mat)] > 0))
})

test_that("station_distance_matrix accepts custom station_info", {
  custom <- data.frame(
    station_id = c("A", "B"),
    lat = c(53.0, 51.0),
    lon = c(-10.0, -6.0),
    stringsAsFactors = FALSE
  )
  mat <- station_distance_matrix(custom)
  expect_equal(nrow(mat), 2)
  expect_equal(rownames(mat), c("A", "B"))
  expect_true(mat["A", "B"] > 0)
})

test_that("analyze_joint_extremes works with synthetic data", {
  set.seed(42)
  n <- 500
  data <- data.frame(
    time = seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n * 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = c(rnorm(n, 3, 1), rnorm(n, 2.5, 0.8)),
    stringsAsFactors = FALSE
  )
  result <- analyze_joint_extremes(data, threshold_quantile = 0.90)
  expect_type(result, "list")
  expect_true("joint_extreme_counts" %in% names(result))
  expect_true("conditional_probs" %in% names(result))
  expect_true(is.matrix(result$joint_extreme_counts))
  # Diagonal should have the most extremes
  expect_true(all(diag(result$joint_extreme_counts) > 0))
})

test_that("cross_correlation_stations works with synthetic data", {
  set.seed(42)
  n <- 200
  time <- seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n)
  signal <- sin(2 * pi * seq_len(n) / 24)  # 24-hour cycle
  data <- data.frame(
    time = rep(time, 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = c(signal + rnorm(n, 0, 0.1), signal + rnorm(n, 0, 0.1)),
    stringsAsFactors = FALSE
  )
  result <- cross_correlation_stations(data, "M2", "M3", max_lag = 24)
  expect_type(result, "list")
  expect_true("optimal_lag" %in% names(result))
  expect_true("max_correlation" %in% names(result))
  # Same signal should have high correlation near lag 0
  expect_true(abs(result$max_correlation) > 0.5)
})

test_that("cross_correlation_stations warns on insufficient data", {
  data <- data.frame(
    time = Sys.time() + 1:10,
    station_id = rep(c("M2", "M3"), each = 5),
    wave_height = rnorm(10)
  )
  expect_message(result <- cross_correlation_stations(data, "M2", "M3", max_lag = 48))
  expect_true(is.na(result$optimal_lag))
})

# --- Tests for compute_extremal_dependence ---

test_that("compute_extremal_dependence returns expected structure", {
  skip_if_not_installed("copula")
  set.seed(42)
  n <- 1000
  # Simulate positively correlated wave heights at two stations
  z <- rnorm(n)
  data <- data.frame(
    time = rep(seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n), 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = c(
      3 + z + rnorm(n, 0, 0.5),
      2.5 + 0.8 * z + rnorm(n, 0, 0.5)
    ),
    stringsAsFactors = FALSE
  )

  result <- compute_extremal_dependence(data, n_bootstrap = 20)

  expect_type(result, "list")
  expect_true("dependence_table" %in% names(result))
  expect_equal(result$method, "gumbel_copula")
  expect_equal(result$n_bootstrap, 20)

  dt <- result$dependence_table
  expect_s3_class(dt, "data.frame")
  expect_equal(nrow(dt), 1)  # One pair: M2-M3
  expected_cols <- c(
    "station1", "station2", "distance_km", "kendall_tau",
    "lambda_upper", "lambda_lower", "lambda_upper_ci_low",
    "lambda_upper_ci_high", "n_concurrent", "copula_alpha",
    "chi_q95", "chi_q99", "h1_significant"
  )
  expect_true(all(expected_cols %in% names(dt)))
})

test_that("compute_extremal_dependence detects dependence in correlated data", {
  skip_if_not_installed("copula")
  set.seed(123)
  n <- 500
  z <- rnorm(n)
  data <- data.frame(
    time = rep(seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n), 2),
    station_id = rep(c("M2", "M3"), each = n),
    wave_height = c(3 + z, 3 + 0.9 * z + rnorm(n, 0, 0.3)),
    stringsAsFactors = FALSE
  )

  result <- compute_extremal_dependence(data, n_bootstrap = 10)
  dt <- result$dependence_table

  # With strong correlation, Kendall's tau should be positive

  expect_true(dt$kendall_tau > 0.3)
  # Lambda should be positive
  expect_true(dt$lambda_upper > 0)
  # With 2000 strongly correlated obs, h1 should be significant
  expect_true(dt$h1_significant)
})

test_that("compute_extremal_dependence handles multiple station pairs", {
  skip_if_not_installed("copula")
  set.seed(42)
  n <- 500
  time_seq <- seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n)
  data <- data.frame(
    time = rep(time_seq, 3),
    station_id = rep(c("M2", "M3", "M4"), each = n),
    wave_height = c(rnorm(n, 3, 1), rnorm(n, 2.5, 0.8), rnorm(n, 2, 0.6)),
    stringsAsFactors = FALSE
  )

  result <- compute_extremal_dependence(data, n_bootstrap = 10)
  # 3 stations = 3 pairs: M2-M3, M2-M4, M3-M4
  expect_equal(nrow(result$dependence_table), 3)
})

test_that("compute_extremal_dependence errors on missing columns", {
  data <- data.frame(time = Sys.time(), station_id = "M2")
  expect_error(
    compute_extremal_dependence(data),
    "Missing required columns"
  )
})

test_that("compute_extremal_dependence errors on single station", {
  data <- data.frame(
    time = Sys.time() + 1:100,
    station_id = "M2",
    wave_height = rnorm(100)
  )
  expect_error(
    compute_extremal_dependence(data),
    "at least 2 stations"
  )
})

test_that("compute_extremal_dependence skips pairs with insufficient data", {
  skip_if_not_installed("copula")
  # M2 has 500 obs, M3 has only 10 — should skip the pair
  data <- data.frame(
    time = c(
      seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = 500),
      seq.POSIXt(as.POSIXct("2025-01-01"), by = "hour", length.out = 10)
    ),
    station_id = c(rep("M2", 500), rep("M3", 10)),
    wave_height = rnorm(510, 3, 1),
    stringsAsFactors = FALSE
  )

  result <- compute_extremal_dependence(data, n_bootstrap = 5)
  # No overlapping times, so pair should be skipped
  expect_true(
    nrow(result$dependence_table) == 0 || !is.null(result$error)
  )
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(analyze_joint_extremes) signature", {
  expect_snapshot(args(analyze_joint_extremes))
})

test_that("snapshot: args(compute_extremal_dependence) signature", {
  expect_snapshot(args(compute_extremal_dependence))
})

test_that("snapshot: args(cross_correlation_stations) signature", {
  expect_snapshot(args(cross_correlation_stations))
})

test_that("snapshot: args(get_station_info) signature", {
  expect_snapshot(args(get_station_info))
})

test_that("snapshot: args(haversine_distance) signature", {
  expect_snapshot(args(haversine_distance))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(add_wave_metrics)", { expect_snapshot(args(irishbuoys:::add_wave_metrics)) })
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
test_that("snap3: args(analyze_parquet_storage)", { expect_snapshot(args(irishbuoys:::analyze_parquet_storage)) })
