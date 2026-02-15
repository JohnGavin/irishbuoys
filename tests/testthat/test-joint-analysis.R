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
