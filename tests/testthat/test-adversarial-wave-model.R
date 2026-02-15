# Adversarial QA Tests for wave_model.R
#
# Attack categories beyond test-defensive-programming.R:
# - Boundary attacks: Inf, -Inf, NaN, extreme values
# - NA attacks: NA, NA_real_, embedded NAs in data
# - Structure attacks: tibble vs data.frame, single-row, minimal columns
# - Idempotency: double-application of prepare_wave_features
# - Determinism: same inputs produce same outputs

# --- Helper: minimal valid data for wave_model functions ---
make_wave_data <- function(n = 50) {
  set.seed(42)
  data.frame(
    station_id = rep("M2", n),
    time = seq(
      as.POSIXct("2024-01-01", tz = "UTC"),
      by = "hour", length.out = n
    ),
    wave_height = abs(rnorm(n, 2, 0.5)),
    wave_period = abs(rnorm(n, 8, 1)),
    wind_speed = abs(rnorm(n, 10, 3)),
    wind_direction = runif(n, 0, 360),
    gust = abs(rnorm(n, 15, 4)),
    atmospheric_pressure = rnorm(n, 1013, 5),
    stringsAsFactors = FALSE
  )
}

# ============================================================
# BOUNDARY ATTACKS
# ============================================================

test_that("prepare_wave_features handles Inf wave_height", {
  d <- make_wave_data(20)
  d$wave_height[5] <- Inf
  # Should not error - Inf is numeric, function should process it
  # (wave_steepness and gust_factor already handle non-finite)
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  expect_true(any(is.infinite(result$wave_height)))
})

test_that("prepare_wave_features handles -Inf wave_height", {
  d <- make_wave_data(20)
  d$wave_height[5] <- -Inf
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
})

test_that("prepare_wave_features handles NaN wave_height", {
  d <- make_wave_data(20)
  d$wave_height[5] <- NaN
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
})

test_that("prepare_wave_features handles extreme values (1e10)", {
  d <- make_wave_data(20)
  d$wave_height[5] <- 1e10
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  expect_equal(result$wave_height[result$wave_height == 1e10], 1e10)
})

test_that("prepare_wave_features handles lags = Inf", {
  d <- make_wave_data(20)
  expect_error(prepare_wave_features(d, lags = Inf))
})

test_that("prepare_wave_features handles lags = 0", {
  d <- make_wave_data(20)
  expect_error(
    prepare_wave_features(d, lags = 0),
    class = "rlang_error"
  )
})

test_that("prepare_wave_features handles lags = -1", {
  d <- make_wave_data(20)
  expect_error(
    prepare_wave_features(d, lags = -1),
    class = "rlang_error"
  )
})

test_that("prepare_wave_features handles lags = NaN", {
  d <- make_wave_data(20)
  expect_error(prepare_wave_features(d, lags = NaN))
})

test_that("train_wave_model handles train_fraction = Inf", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, train_fraction = Inf),
    class = "rlang_error"
  )
})

test_that("train_wave_model handles train_fraction = -Inf", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, train_fraction = -Inf),
    class = "rlang_error"
  )
})

test_that("train_wave_model handles train_fraction = NaN", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, train_fraction = NaN),
    class = "rlang_error"
  )
})

test_that("train_wave_model handles train_fraction = 0", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, train_fraction = 0),
    class = "rlang_error"
  )
})

test_that("train_wave_model handles train_fraction = 1", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, train_fraction = 1),
    class = "rlang_error"
  )
})

# ============================================================
# NA ATTACKS
# ============================================================

test_that("prepare_wave_features handles NA in wave_height", {
  d <- make_wave_data(20)
  d$wave_height[c(3, 7, 12)] <- NA
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  expect_equal(sum(is.na(result$wave_height)), 3)
})

test_that("prepare_wave_features handles NA_real_ in wave_height", {
  d <- make_wave_data(20)
  d$wave_height[1:5] <- NA_real_
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
})

test_that("prepare_wave_features handles all-NA wave_height", {
  d <- make_wave_data(20)
  d$wave_height <- NA_real_
  # Function should still run; all derived features will be NA
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  expect_true(all(is.na(result$wave_height)))
})

test_that("prepare_wave_features handles NA in wind_speed", {
  d <- make_wave_data(20)
  d$wind_speed <- NA_real_
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  # gust_factor should be NA when wind_speed is NA
  expect_true(all(is.na(result$gust_factor)))
})

test_that("prepare_wave_features handles NA in time column", {
  d <- make_wave_data(20)
  d$time[5] <- NA
  # time is used for hour/month extraction, NA should propagate
  # Note: data is re-sorted by station_id + time, so NA row moves

  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  # At least one NA hour should exist (from the NA time)
  expect_true(any(is.na(result$hour)))
})

test_that("prepare_wave_features handles NA lags", {
  d <- make_wave_data(20)
  expect_error(prepare_wave_features(d, lags = NA))
})

test_that("train_wave_model handles NA train_fraction", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, train_fraction = NA),
    class = "rlang_error"
  )
})

test_that("train_wave_model handles NA target", {
  d <- make_wave_data(20)
  expect_error(
    train_wave_model(d, target = NA),
    class = "rlang_error"
  )
})

# ============================================================
# STRUCTURE ATTACKS
# ============================================================

test_that("prepare_wave_features works with tibble input", {
  d <- tibble::as_tibble(make_wave_data(20))
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  expect_true(nrow(result) > 0)
})

test_that("prepare_wave_features works with single-station data", {
  d <- make_wave_data(20)
  # Already single station (M2), verify it works
  result <- prepare_wave_features(d)
  expect_equal(length(unique(result$station_id)), 1)
})

test_that("prepare_wave_features works with multi-station data", {
  d1 <- make_wave_data(20)
  d2 <- make_wave_data(20)
  d2$station_id <- "M3"
  d2$time <- d2$time + 1  # slight offset to avoid duplicates
  d <- rbind(d1, d2)
  result <- prepare_wave_features(d)
  expect_equal(length(unique(result$station_id)), 2)
  expect_equal(nrow(result), 40)
})

test_that("prepare_wave_features handles minimal columns (no optional)", {
  # Only required columns: station_id, time, wave_height
  set.seed(99)
  d <- data.frame(
    station_id = rep("M2", 20),
    time = seq(
      as.POSIXct("2024-01-01", tz = "UTC"),
      by = "hour", length.out = 20
    ),
    wave_height = abs(rnorm(20, 2, 0.5))
  )
  result <- prepare_wave_features(d)
  expect_s3_class(result, "data.frame")
  # Should have lagged wave height but no wind_dir_sin (no wind_direction)
  expect_true("wave_height_lag1" %in% names(result))
  expect_false("wind_dir_sin" %in% names(result))
  # Should not have pressure_change or wind_speed_lag1 (columns absent)
  expect_false("pressure_change" %in% names(result))
  expect_false("wind_speed_lag1" %in% names(result))
})

test_that("predict_wave_height rejects matrix input", {
  fake_model <- list(model = "not_real", predictors = c("x"))
  expect_error(
    predict_wave_height(fake_model, matrix(1:4, 2)),
    class = "rlang_error"
  )
})

test_that("evaluate_wave_model rejects vector input for data", {
  fake_model <- list(model = "not_real")
  expect_error(
    evaluate_wave_model(fake_model, 1:10),
    class = "rlang_error"
  )
})

test_that("evaluate_wave_model rejects model without $model element", {
  expect_error(
    evaluate_wave_model(list(a = 1), make_wave_data(20)),
    class = "rlang_error"
  )
})

test_that("predict_wave_height rejects model without $model element", {
  expect_error(
    predict_wave_height(list(a = 1), make_wave_data(20)),
    class = "rlang_error"
  )
})

# ============================================================
# IDEMPOTENCY ATTACKS
# ============================================================

test_that("prepare_wave_features is idempotent on core columns", {
  d <- make_wave_data(30)
  result1 <- prepare_wave_features(d)
  # Apply again - lagged features will be re-created (overwritten)
  # Required cols still present, so should not error
  result2 <- prepare_wave_features(result1)
  expect_s3_class(result2, "data.frame")
  # Original wave_height should be unchanged
  expect_equal(result1$wave_height, result2$wave_height)
  # station_id unchanged
  expect_equal(result1$station_id, result2$station_id)
})

test_that("prepare_wave_features double application does not error", {
  d <- make_wave_data(20)
  result <- prepare_wave_features(d)
  # Second pass should succeed without error
  expect_no_error(prepare_wave_features(result))
})

# ============================================================
# DETERMINISM ATTACKS
# ============================================================

test_that("prepare_wave_features is deterministic", {
  d <- make_wave_data(30)
  result1 <- prepare_wave_features(d)
  result2 <- prepare_wave_features(d)
  # Results should be identical (no randomness in feature prep)
  expect_equal(result1$wave_height_lag1, result2$wave_height_lag1)
  expect_equal(result1$hour, result2$hour)
  expect_equal(result1$month, result2$month)
})

test_that("train_wave_model is deterministic with same seed", {
  skip_if_not_installed("ranger")
  d <- make_wave_data(200)
  features <- prepare_wave_features(d)

  suppressMessages({
    m1 <- train_wave_model(features, seed = 123)
    m2 <- train_wave_model(features, seed = 123)
  })

  # Same seed should produce same R-squared
  expect_equal(m1$train_r_squared, m2$train_r_squared)
  expect_equal(m1$oob_rmse, m2$oob_rmse)
})

test_that("train_wave_model differs with different seeds", {
  skip_if_not_installed("ranger")
  d <- make_wave_data(200)
  features <- prepare_wave_features(d)

  suppressMessages({
    m1 <- train_wave_model(features, seed = 1)
    m2 <- train_wave_model(features, seed = 999)
  })

  # Different seeds should (almost certainly) produce different results

  # OOB RMSE may differ slightly
  expect_true(m1$train_r_squared != m2$train_r_squared ||
                m1$oob_rmse != m2$oob_rmse)
})

# ============================================================
# EDGE CASE ATTACKS
# ============================================================

test_that("prepare_wave_features handles single-row data frame", {
  d <- make_wave_data(1)
  # Single row should error (0 lags possible with 1 row)
  # But function only checks nrow > 0, so it should run
  result <- prepare_wave_features(d, lags = 1)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 1)
  # Lagged values should be NA for single-row data
  expect_true(is.na(result$wave_height_lag1))
})

test_that("prepare_wave_features handles 2-row data frame", {
  d <- make_wave_data(2)
  result <- prepare_wave_features(d, lags = 1:3)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
})

test_that("prepare_wave_features handles large lags with small data", {
  d <- make_wave_data(5)
  # lags = 1:10 but only 5 rows - should not error, just produce NAs
  result <- prepare_wave_features(d, lags = 1:10)
  expect_s3_class(result, "data.frame")
  # Lags > 5 should be all NA
  expect_true(all(is.na(result$wave_height_lag6)))
})

test_that("wave_model_report handles minimal eval_result", {
  fake_model <- list(
    train_r_squared = 0.9,
    oob_rmse = 0.5,
    importance = data.frame(
      variable = c("a", "b", "c", "d", "e"),
      importance = 5:1
    )
  )
  fake_eval <- list(
    overall = data.frame(
      metric = c("RMSE", "MAE", "R_squared", "Bias", "N_test"),
      value = c(0.5, 0.3, 0.85, 0.01, 100)
    ),
    by_category = data.frame(
      category = c("Low (0-2m)", "Moderate (2-4m)"),
      n = c(80, 20),
      rmse = c(0.3, 0.7),
      mae = c(0.2, 0.5)
    )
  )
  report <- wave_model_report(fake_model, fake_eval)
  expect_type(report, "character")
  expect_true(nchar(report) > 0)
  expect_true(grepl("R\\^2", report))
  expect_true(grepl("RMSE", report))
})

test_that("predict_wave_height errors on missing predictors", {
  fake_model <- list(
    model = structure(list(), class = "ranger"),
    predictors = c("wind_speed", "nonexistent_var")
  )
  d <- data.frame(wind_speed = 1:5)
  expect_error(
    predict_wave_height(fake_model, d),
    regexp = "nonexistent_var"
  )
})
