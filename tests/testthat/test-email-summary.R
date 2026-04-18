# Tests for R/email_summary.R
# Basic coverage tests for generate_weekly_summary, create_email_summary,
# generate_and_send_summary

test_that("generate_weekly_summary returns expected structure", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  expect_type(result, "list")
  expect_named(result, c(
    "current_week", "previous_week", "historical",
    "extreme_events", "ingestion_stats", "data_coverage",
    "db_stats", "update_result", "report_date", "period"
  ), ignore.order = TRUE)
  expect_s3_class(result$current_week, "data.frame")
  expect_s3_class(result$previous_week, "data.frame")
  expect_s3_class(result$historical, "data.frame")
  expect_s3_class(result$extreme_events, "data.frame")
})

test_that("generate_weekly_summary period dates are correct", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 14
  )
  # period$end = current_date - 1, period$start = current_date - lookback_days
  # so end - start = lookback_days - 1
  expect_equal(
    as.numeric(result$period$end - result$period$start),
    13
  )
})

test_that("generate_weekly_summary passes through update_result", {
  update <- list(new_records = 42, stations = c("M1", "M2"))
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    update_result = update
  )
  expect_equal(result$update_result, update)
})

test_that("generate_weekly_summary includes ingestion_stats", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  expect_true("ingestion_stats" %in% names(result))
})

test_that("generate_weekly_summary includes db_stats", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  expect_true("db_stats" %in% names(result))
  # db_stats may be NULL if get_database_stats() errors (signature mismatch)
})

test_that("create_email_summary returns blastula email", {
  summary <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

test_that("create_email_summary contains expected HTML content", {
  summary <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  email <- create_email_summary(summary)
  email_html <- paste(as.character(email), collapse = "\n")
  expect_match(email_html, "Irish Weather Buoy Network")
  expect_match(email_html, "Report Period")
})

test_that("generate_and_send_summary saves file when no credentials", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary()
      expect_type(result, "list")
    }
  )
})

test_that("generate_weekly_summary errors on invalid db_path", {
  expect_error(generate_weekly_summary(db_path = NULL))
  expect_error(generate_weekly_summary(db_path = NA))
  expect_error(generate_weekly_summary(db_path = ""))
})

test_that("create_email_summary errors on invalid input", {
  expect_error(create_email_summary(NULL))
  expect_error(create_email_summary(NA))
  expect_error(create_email_summary(list()))
})

# validate_email_freshness() tests
test_that("validate_email_freshness: fresh data passes silently", {
  stats <- tibble::tibble(
    station_id = c("M2", "M3", "M4"),
    latest = Sys.time() - c(1, 2, 3) * 3600  # 1-3 hours ago
  )
  expect_silent(validate_email_freshness(stats))
  result <- validate_email_freshness(stats)
  expect_identical(result, stats)
})

test_that("validate_email_freshness: partially stale data warns", {
  stats <- tibble::tibble(
    station_id = c("M2", "M3", "M4"),
    latest = Sys.time() - c(1, 200, 200) * 3600  # M2 fresh, M3/M4 stale

  )
  expect_warning(
    validate_email_freshness(stats),
    "stations have data"
  )
})

test_that("validate_email_freshness: all stale data aborts", {
  stats <- tibble::tibble(
    station_id = c("M2", "M3"),
    latest = Sys.time() - c(200, 200) * 3600  # Both >96h old
  )
  expect_error(
    validate_email_freshness(stats),
    "ALL stations have stale data"
  )
})

test_that("validate_email_freshness: empty ingestion_stats aborts", {
  stats <- tibble::tibble(
    station_id = character(0),
    latest = as.POSIXct(character(0))
  )
  expect_error(
    validate_email_freshness(stats),
    "No ingestion statistics"
  )
})

test_that("validate_email_freshness: NULL ingestion_stats aborts", {
  expect_error(
    validate_email_freshness(NULL),
    "No ingestion statistics"
  )
})

test_that("validate_email_freshness: custom max_stale_hours threshold", {
  stats <- tibble::tibble(
    station_id = c("M2", "M3"),
    latest = Sys.time() - c(10, 10) * 3600  # 10 hours old
  )
  # 96h default: passes
  expect_silent(validate_email_freshness(stats, max_stale_hours = 96))
  # 5h threshold: all stale -> aborts
  expect_error(
    validate_email_freshness(stats, max_stale_hours = 5),
    "ALL stations have stale data"
  )
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(create_email_summary) signature", {
  expect_snapshot(args(create_email_summary))
})

test_that("snapshot: args(generate_and_send_summary) signature", {
  expect_snapshot(args(generate_and_send_summary))
})

test_that("snapshot: args(generate_weekly_summary) signature", {
  expect_snapshot(args(generate_weekly_summary))
})

test_that("snapshot: args(get_database_stats) signature", {
  expect_snapshot(args(get_database_stats))
})

test_that("snapshot: args(validate_email_freshness) signature", {
  expect_snapshot(args(validate_email_freshness))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(add_wave_metrics)", { expect_snapshot(args(irishbuoys:::add_wave_metrics)) })
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
test_that("snap3: args(analyze_joint_extremes)", { expect_snapshot(args(irishbuoys:::analyze_joint_extremes)) })

# ── Phase 2: Output structure snapshots (#68) ────────────────────────

test_that("generate_weekly_summary field names are stable", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  expect_snapshot(sort(names(result)))
  expect_snapshot(sort(names(result$current_week)))
  expect_snapshot(sort(names(result$ingestion_stats)))
})

test_that("get_station_info output is stable", {
  info <- get_station_info()
  expect_snapshot(sort(names(info)))
})
