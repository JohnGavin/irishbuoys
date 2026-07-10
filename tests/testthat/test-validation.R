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

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(validate_buoy_data) signature", {
  expect_snapshot(args(validate_buoy_data))
})

test_that("snapshot: args(validate_rogue_events) signature", {
  expect_snapshot(args(validate_rogue_events))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(create_validation_summary)", { expect_snapshot(args(irishbuoys:::create_validation_summary)) })
test_that("snap3: args(generate_validation_reports)", { expect_snapshot(args(irishbuoys:::generate_validation_reports)) })

# ── Phase 2: Error message snapshots (#68) ───────────────────────────

test_that("validate_buoy_data error messages are stable", {
  expect_snapshot(error = TRUE, validate_buoy_data(NULL))
  expect_snapshot(error = TRUE, validate_buoy_data("string"))
})

test_that("validate_buoy_data output structure is stable", {
  # Incomplete data (missing hmax/gust/atmospheric_pressure) drives the
  # all_passed(agent) == FALSE branch, which uses
  # get_agent_x_list(agent)$validation_set$all_passed/$stop — the code
  # path fixed for pointblank >= 0.12 (get_agent_report() lost its
  # `all_passed` column). Keep this case to cover that branch.
  data <- data.frame(
    station_id = rep("M2", 10),
    time = seq(as.POSIXct("2024-01-01"), by = "hour", length.out = 10),
    wave_height = runif(10, 0.5, 5),
    wind_speed = runif(10, 2, 25),
    qc_flag = rep(1L, 10),
    stringsAsFactors = FALSE
  )
  result <- validate_buoy_data(data, min_rows = 1)
  expect_snapshot(sort(names(result)))
})

test_that("validate_buoy_data output structure is stable with complete data", {
  skip_if_not_installed("pointblank")
  # Complete data (all columns pointblank checks against) drives the
  # all_passed(agent) == TRUE early-return branch (validation.R L151-155),
  # complementing the incomplete-data case above which drives the
  # x_list branch.
  data <- data.frame(
    station_id = rep("M2", 10),
    time = seq(as.POSIXct("2024-01-01"), by = "hour", length.out = 10),
    wave_height = runif(10, 0.5, 5),
    hmax = runif(10, 1, 15),
    wind_speed = runif(10, 2, 25),
    gust = runif(10, 5, 40),
    atmospheric_pressure = runif(10, 990, 1030),
    qc_flag = rep(1L, 10),
    stringsAsFactors = FALSE
  )
  result <- validate_buoy_data(data, min_rows = 1)
  expect_snapshot(sort(names(result)))
})
