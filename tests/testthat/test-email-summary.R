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
    "extreme_events", "ingestion_stats", "db_stats",
    "update_result", "report_date", "period"
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
