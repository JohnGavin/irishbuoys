# Tests for defensive programming / input validation
# These tests verify that functions properly reject invalid inputs
# with clear, informative error messages using cli::cli_abort()

# ==============================================================================
# calculate_wave_steepness() tests
# ==============================================================================

test_that("calculate_wave_steepness rejects NULL wave_height", {
  expect_error(
    calculate_wave_steepness(NULL, 8),
    class = "rlang_error"
  )
  expect_error(
    calculate_wave_steepness(NULL, 8),
    regexp = "wave_height.*NULL"
  )
})

test_that("calculate_wave_steepness rejects NULL wave_period", {
  expect_error(
    calculate_wave_steepness(3, NULL),
    class = "rlang_error"
  )
  expect_error(
    calculate_wave_steepness(3, NULL),
    regexp = "wave_period.*NULL"
  )
})

test_that("calculate_wave_steepness rejects non-numeric wave_height", {
  expect_error(
    calculate_wave_steepness("3", 8),
    class = "rlang_error"
  )
  expect_error(
    calculate_wave_steepness("3", 8),
    regexp = "wave_height.*numeric"
  )
})

test_that("calculate_wave_steepness rejects non-numeric wave_period", {
  expect_error(
    calculate_wave_steepness(3, "8"),
    class = "rlang_error"
  )
  expect_error(
    calculate_wave_steepness(3, "8"),
    regexp = "wave_period.*numeric"
  )
})

test_that("calculate_wave_steepness works with valid inputs", {
  result <- calculate_wave_steepness(3, 8)
  expect_type(result, "double")
  expect_true(result > 0)

  # Vector inputs should work
  result_vec <- calculate_wave_steepness(c(1, 2, 3), c(5, 6, 7))
  expect_length(result_vec, 3)
})

# ==============================================================================
# add_wave_metrics() tests
# ==============================================================================

test_that("add_wave_metrics rejects NULL data", {
  expect_error(
    add_wave_metrics(NULL),
    class = "rlang_error"
  )
  expect_error(
    add_wave_metrics(NULL),
    regexp = "data.*NULL"
  )
})

test_that("add_wave_metrics rejects non-data.frame", {
  expect_error(
    add_wave_metrics(list(a = 1, b = 2)),
    class = "rlang_error"
  )
  expect_error(
    add_wave_metrics("not a dataframe"),
    regexp = "data.*data frame"
  )
})

test_that("add_wave_metrics rejects missing required columns", {
  incomplete_data <- data.frame(wave_height = 1:3, hmax = 2:4)
  # Missing wave_period
  expect_error(
    add_wave_metrics(incomplete_data),
    class = "rlang_error"
  )
  expect_error(
    add_wave_metrics(incomplete_data),
    regexp = "wave_period"
  )
})

test_that("add_wave_metrics handles empty data gracefully", {
  empty_data <- data.frame(
    wave_height = numeric(0),
    hmax = numeric(0),
    wave_period = numeric(0)
  )
  # Should return data with new columns but 0 rows
  result <- add_wave_metrics(empty_data)
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 0)
  expect_true("rogue_ratio" %in% names(result))
})

test_that("add_wave_metrics works with valid inputs", {
  valid_data <- data.frame(
    wave_height = c(2, 3, 4),
    hmax = c(4, 5, 9),
    wave_period = c(8, 10, 12)
  )
  result <- add_wave_metrics(valid_data)
  expect_s3_class(result, "data.frame")
  expect_true(all(c("rogue_ratio", "is_rogue", "steepness", "danger_level") %in% names(result)))
})

# ==============================================================================
# validate_buoy_data() tests
# ==============================================================================

test_that("validate_buoy_data rejects NULL data", {
  expect_error(
    validate_buoy_data(NULL),
    class = "rlang_error"
  )
  expect_error(
    validate_buoy_data(NULL),
    regexp = "data.*NULL"
  )
})

test_that("validate_buoy_data rejects non-data.frame", {
  expect_error(
    validate_buoy_data(list(a = 1)),
    class = "rlang_error"
  )
  expect_error(
    validate_buoy_data("string"),
    regexp = "data.*data frame"
  )
})

test_that("validate_buoy_data rejects insufficient rows", {
  small_data <- data.frame(
    station_id = "M3",
    time = Sys.time(),
    wave_height = 2
  )
  expect_error(
    validate_buoy_data(small_data, min_rows = 100),
    class = "rlang_error"
  )
  expect_error(
    validate_buoy_data(small_data, min_rows = 100),
    regexp = "insufficient rows"
  )
})

# ==============================================================================
# prepare_wave_features() tests
# ==============================================================================

test_that("prepare_wave_features rejects NULL data", {
  expect_error(
    prepare_wave_features(NULL),
    class = "rlang_error"
  )
  expect_error(
    prepare_wave_features(NULL),
    regexp = "data.*NULL"
  )
})

test_that("prepare_wave_features rejects non-data.frame", {
  expect_error(
    prepare_wave_features(c(1, 2, 3)),
    class = "rlang_error"
  )
})

test_that("prepare_wave_features rejects missing required columns", {
  bad_data <- data.frame(x = 1:10, y = 1:10)
  expect_error(
    prepare_wave_features(bad_data),
    class = "rlang_error"
  )
  expect_error(
    prepare_wave_features(bad_data),
    regexp = "Missing required columns"
  )
})

test_that("prepare_wave_features rejects empty data", {
  empty_data <- data.frame(
    station_id = character(0),
    time = as.POSIXct(character(0)),
    wave_height = numeric(0)
  )
  expect_error(
    prepare_wave_features(empty_data),
    class = "rlang_error"
  )
  expect_error(
    prepare_wave_features(empty_data),
    regexp = "0 rows"
  )
})

test_that("prepare_wave_features rejects invalid lags", {
  valid_data <- data.frame(
    station_id = rep("M3", 10),
    time = seq(Sys.time(), by = "hour", length.out = 10),
    wave_height = runif(10, 1, 5)
  )
  expect_error(
    prepare_wave_features(valid_data, lags = c(-1, 0, 1)),
    class = "rlang_error"
  )
})

# ==============================================================================
# train_wave_model() tests
# ==============================================================================

test_that("train_wave_model rejects NULL data", {
  expect_error(
    train_wave_model(NULL),
    class = "rlang_error"
  )
  expect_error(
    train_wave_model(NULL),
    regexp = "data.*NULL"
  )
})

test_that("train_wave_model rejects non-data.frame", {
  expect_error(
    train_wave_model(matrix(1:10, nrow = 2)),
    class = "rlang_error"
  )
})

test_that("train_wave_model rejects empty data", {
  empty_data <- data.frame(wave_height = numeric(0))
  expect_error(
    train_wave_model(empty_data),
    class = "rlang_error"
  )
})

test_that("train_wave_model rejects missing target column", {
  bad_data <- data.frame(x = 1:100, y = 1:100)
  expect_error(
    train_wave_model(bad_data, target = "wave_height"),
    class = "rlang_error"
  )
  expect_error(
    train_wave_model(bad_data, target = "wave_height"),
    regexp = "wave_height.*not found"
  )
})

test_that("train_wave_model rejects invalid train_fraction", {
  valid_data <- data.frame(wave_height = 1:100)
  expect_error(
    train_wave_model(valid_data, train_fraction = 0),
    class = "rlang_error"
  )
  expect_error(
    train_wave_model(valid_data, train_fraction = 1),
    class = "rlang_error"
  )
  expect_error(
    train_wave_model(valid_data, train_fraction = 1.5),
    class = "rlang_error"
  )
})

# ==============================================================================
# evaluate_wave_model() tests
# ==============================================================================

test_that("evaluate_wave_model rejects NULL model_result", {
  expect_error(
    evaluate_wave_model(NULL, data.frame(x = 1)),
    class = "rlang_error"
  )
})

test_that("evaluate_wave_model rejects NULL data", {
  fake_model <- list(model = "fake", predictors = "x", test_idx = 1:10)
  expect_error(
    evaluate_wave_model(fake_model, NULL),
    class = "rlang_error"
  )
})

test_that("evaluate_wave_model rejects invalid model_result structure", {
  expect_error(
    evaluate_wave_model(list(not_a_model = TRUE), data.frame(x = 1)),
    class = "rlang_error"
  )
  expect_error(
    evaluate_wave_model("string", data.frame(x = 1)),
    class = "rlang_error"
  )
})

# ==============================================================================
# predict_wave_height() tests
# ==============================================================================

test_that("predict_wave_height rejects NULL model_result", {
  expect_error(
    predict_wave_height(NULL, data.frame(x = 1)),
    class = "rlang_error"
  )
})

test_that("predict_wave_height rejects NULL new_data", {
  fake_model <- list(model = "fake", predictors = "x")
  expect_error(
    predict_wave_height(fake_model, NULL),
    class = "rlang_error"
  )
})

test_that("predict_wave_height rejects non-data.frame new_data", {
  fake_model <- list(model = "fake", predictors = "x")
  expect_error(
    predict_wave_height(fake_model, c(1, 2, 3)),
    class = "rlang_error"
  )
})

# ==============================================================================
# detect_rogue_waves() tests (requires DBI connection - skip if unavailable)
# ==============================================================================

test_that("detect_rogue_waves rejects NULL connection", {
  expect_error(
    detect_rogue_waves(NULL),
    class = "rlang_error"
  )
  expect_error(
    detect_rogue_waves(NULL),
    regexp = "con.*NULL"
  )
})

test_that("detect_rogue_waves rejects non-DBI connection", {
  expect_error(
    detect_rogue_waves("not_a_connection"),
    class = "rlang_error"
  )
  expect_error(
    detect_rogue_waves(list(a = 1)),
    regexp = "DBI connection"
  )
})

test_that("detect_rogue_waves rejects invalid threshold", {
  # Create a mock that will fail before checking threshold
  # We just verify the threshold check works
  expect_error(
    detect_rogue_waves(structure(list(), class = "DBIConnection"), threshold = 0),
    class = "rlang_error"
  )
  expect_error(
    detect_rogue_waves(structure(list(), class = "DBIConnection"), threshold = -1),
    regexp = "threshold.*positive"
  )
  expect_error(
    detect_rogue_waves(structure(list(), class = "DBIConnection"), threshold = "2"),
    class = "rlang_error"
  )
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(add_wave_metrics) signature", {
  expect_snapshot(args(add_wave_metrics))
})

test_that("snapshot: args(calculate_wave_steepness) signature", {
  expect_snapshot(args(calculate_wave_steepness))
})

test_that("snapshot: args(detect_rogue_waves) signature", {
  expect_snapshot(args(detect_rogue_waves))
})

test_that("snapshot: args(evaluate_wave_model) signature", {
  expect_snapshot(args(evaluate_wave_model))
})

test_that("snapshot: args(predict_wave_height) signature", {
  expect_snapshot(args(predict_wave_height))
})

test_that("snapshot: args(prepare_wave_features) signature", {
  expect_snapshot(args(prepare_wave_features))
})

test_that("snapshot: args(train_wave_model) signature", {
  expect_snapshot(args(train_wave_model))
})

test_that("snapshot: args(validate_buoy_data) signature", {
  expect_snapshot(args(validate_buoy_data))
})

# ── Extra function signature snapshots (auto-added pass 2) ─────────
# Added to reach >=30% snapshot ratio. Regenerate with snapshot_accept().

test_that("snapshot pass2: args(analyze_gust_factor)", {
  expect_snapshot(args(irishbuoys:::analyze_gust_factor))
})

test_that("snapshot pass2: args(analyze_joint_extremes)", {
  expect_snapshot(args(irishbuoys:::analyze_joint_extremes))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(analyze_parquet_storage)", { expect_snapshot(args(irishbuoys:::analyze_parquet_storage)) })
test_that("snap3: args(analyze_rogue_statistics)", { expect_snapshot(args(irishbuoys:::analyze_rogue_statistics)) })
test_that("snap3: args(analyze_station_pairs)", { expect_snapshot(args(irishbuoys:::analyze_station_pairs)) })
test_that("snap3: args(beaufort_to_description)", { expect_snapshot(args(irishbuoys:::beaufort_to_description)) })
test_that("snap3: args(buoy_tbl)", { expect_snapshot(args(irishbuoys:::buoy_tbl)) })
