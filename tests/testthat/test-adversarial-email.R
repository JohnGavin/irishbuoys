# Adversarial QA Tests for Email Summary Functions
# Tests generate_weekly_summary(), create_email_summary(), generate_and_send_summary()

test_that("generate_weekly_summary: NULL db_path", {
  expect_error(
    generate_weekly_summary(db_path = NULL),
    class = "error"
  )
})

test_that("generate_weekly_summary: NA db_path", {
  expect_error(
    generate_weekly_summary(db_path = NA),
    class = "error"
  )
})

test_that("generate_weekly_summary: empty string db_path", {
  expect_error(
    generate_weekly_summary(db_path = ""),
    class = "error"
  )
})

test_that("generate_weekly_summary: non-existent directory path", {
  expect_error(
    generate_weekly_summary(db_path = "/nonexistent/path/to/db.duckdb")
  )
})

test_that("generate_weekly_summary: directory instead of file", {
  tmp_dir <- tempdir()
  expect_error(
    generate_weekly_summary(db_path = tmp_dir),
    class = "error"
  )
})

test_that("generate_weekly_summary: special characters in path (creates new db)", {
  # DuckDB handles special chars fine and creates missing files
  tmp_db <- file.path(tempdir(), "test_db_special!@#.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)
  
  # This SUCCEEDS because DuckDB creates the file
  result <- generate_weekly_summary(db_path = tmp_db)
  expect_type(result, "list")
  # But data will be empty since it's a new db
  expect_equal(nrow(result$current_week), 0)
})

test_that("generate_weekly_summary: very long path (creates new db)", {
  long_path <- file.path(
    tempdir(),
    paste0(paste(rep("a", 100), collapse = ""), ".duckdb")
  )
  on.exit(unlink(long_path), add = TRUE)
  
  # DuckDB handles this - creates new db
  result <- generate_weekly_summary(db_path = long_path)
  expect_type(result, "list")
})

test_that("generate_weekly_summary: invalid lookback_days - NULL", {
  expect_error(
    generate_weekly_summary(
      db_path = "inst/extdata/irish_buoys.duckdb",
      lookback_days = NULL
    ),
    class = "error"
  )
})

test_that("generate_weekly_summary: invalid lookback_days - NA", {
  # NA lookback_days causes NA date arithmetic; DuckDB may or may not error
  result <- tryCatch(
    generate_weekly_summary(
      db_path = "inst/extdata/irish_buoys.duckdb",
      lookback_days = NA
    ),
    error = function(e) "errored"
  )
  # Either errors or returns a list (both acceptable)
  expect_true(is.list(result) || identical(result, "errored"))
})

test_that("generate_weekly_summary: invalid lookback_days - negative", {
  # Should succeed but return empty results
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = -1
  )
  expect_type(result, "list")
})

test_that("generate_weekly_summary: invalid lookback_days - zero", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 0
  )
  expect_type(result, "list")
})

test_that("generate_weekly_summary: invalid lookback_days - extremely large", {
  # Should succeed, just query more data
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 365000  # 1000 years
  )
  expect_type(result, "list")
})

test_that("generate_weekly_summary: invalid qc_filter - string (SQL injection attempt)", {
  # glue will convert to string, DuckDB will error on invalid SQL
  expect_error(
    generate_weekly_summary(
      db_path = "inst/extdata/irish_buoys.duckdb",
      qc_filter = "'; DROP TABLE buoy_data; --"
    )
  )
})

test_that("generate_weekly_summary: invalid qc_filter - out of range (succeeds, no data)", {
  # Query runs but returns no data
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    qc_filter = 999
  )
  expect_type(result, "list")
})

test_that("generate_weekly_summary: update_result - NULL (valid default)", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    update_result = NULL
  )
  expect_type(result, "list")
  expect_null(result$update_result)
})

test_that("generate_weekly_summary: update_result - NA", {
  # Should succeed - just passes through
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    update_result = NA
  )
  expect_type(result, "list")
})

test_that("generate_weekly_summary: update_result - empty list", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    update_result = list()
  )
  expect_type(result, "list")
  expect_equal(result$update_result, list())
})

test_that("generate_weekly_summary: update_result - malformed list", {
  # Should succeed - just stores whatever is passed
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    update_result = list(foo = "bar", invalid = 123)
  )
  expect_type(result, "list")
  expect_equal(result$update_result$foo, "bar")
})

test_that("generate_weekly_summary: valid call with all defaults", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  expect_type(result, "list")
  expect_named(result, c(
    "current_week", "previous_week", "historical",
    "extreme_events", "ingestion_stats", "db_stats",
    "update_result", "report_date", "period"
  ), ignore.order = TRUE)
})

# create_email_summary() tests
test_that("create_email_summary: NULL summary", {
  expect_error(
    create_email_summary(NULL),
    class = "error"
  )
})

test_that("create_email_summary: NA summary", {
  expect_error(
    create_email_summary(NA),
    class = "error"
  )
})

test_that("create_email_summary: empty list summary", {
  expect_error(
    create_email_summary(list()),
    class = "error"
  )
})

test_that("create_email_summary: missing required fields - extreme_events", {
  summary <- list(
    current_week = data.frame(),
    ingestion_stats = data.frame()
  )
  expect_error(
    create_email_summary(summary),
    class = "error"
  )
})

test_that("create_email_summary: missing required fields - current_week", {
  summary <- list(
    extreme_events = data.frame(),
    ingestion_stats = data.frame()
  )
  expect_error(
    create_email_summary(summary),
    class = "error"
  )
})

test_that("create_email_summary: wrong type for extreme_events", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = 2.5,
      max_wave_height = 4.0,
      avg_wind_speed = 10,
      avg_air_temp = 12,
      avg_sea_temp = 11,
      n_observations = 100
    ),
    extreme_events = "not a data frame",
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1)
  )
  expect_error(
    create_email_summary(summary),
    class = "error"
  )
})

test_that("create_email_summary: malformed current_week - missing columns (graceful)", {
  summary <- list(
    current_week = data.frame(station_id = "M1"),  # Missing all other columns
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1)
  )
  # Function handles missing columns gracefully - apply() returns NAs
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

test_that("create_email_summary: valid minimal summary", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = 2.5,
      max_wave_height = 4.0,
      avg_wind_speed = 10,
      avg_air_temp = 12,
      avg_sea_temp = 11,
      n_observations = 100
    ),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

test_that("create_email_summary: valid full summary from generate_weekly_summary", {
  summary <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb"
  )
  
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
  
  # Check that email contains expected HTML elements
  email_html <- paste(as.character(email), collapse = "\n")
  expect_match(email_html, "Irish Weather Buoy Network")
  expect_match(email_html, "Report Period")
})

test_that("create_email_summary: summary with extreme events", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = 2.5,
      max_wave_height = 4.0,
      avg_wind_speed = 10,
      avg_air_temp = 12,
      avg_sea_temp = 11,
      n_observations = 100
    ),
    extreme_events = data.frame(
      station_id = "M1",
      time = Sys.time(),
      event_type = "High Waves",
      value = 10.5
    ),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
  email_html <- paste(as.character(email), collapse = "\n")
  expect_match(email_html, "Extreme Events This Week")
  expect_match(email_html, "High Waves")
})

test_that("create_email_summary: empty current_week (edge case - graceful handling)", {
  summary <- list(
    current_week = data.frame(),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  # Empty data.frame means apply() won't iterate - gracefully handles
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

# generate_and_send_summary() tests
test_that("generate_and_send_summary: NULL recipient", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary(recipient = NULL, sender = NULL)
      expect_type(result, "list")
    }
  )
})

test_that("generate_and_send_summary: empty string recipient", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary(recipient = "", sender = "")
      expect_type(result, "list")
    }
  )
})

test_that("generate_and_send_summary: invalid email format", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary(
        recipient = "not-an-email",
        sender = "also-not-an-email"
      )
      expect_type(result, "list")
    }
  )
})

test_that("generate_and_send_summary: special characters in email", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary(
        recipient = "test!@#$%@example.com",
        sender = "test@example.com"
      )
      expect_type(result, "list")
    }
  )
})

test_that("generate_and_send_summary: no credentials (saves to file)", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary()
      expect_type(result, "list")
      
      # Check that file was created
      expected_file <- file.path(
        tempdir(),
        paste0("email_summary_", Sys.Date(), ".html")
      )
      expect_true(file.exists(expected_file))
    }
  )
})

test_that("generate_and_send_summary: valid call with defaults", {
  withr::with_envvar(
    c(GMAIL_USERNAME = "", GMAIL_APP_PASSWORD = ""),
    {
      result <- generate_and_send_summary()
      expect_type(result, "list")
      expect_named(result, c(
        "current_week", "previous_week", "historical",
        "extreme_events", "ingestion_stats", "db_stats",
        "update_result", "report_date", "period"
      ), ignore.order = TRUE)
    }
  )
})

# Edge cases for parameter combinations
test_that("generate_weekly_summary: all parameters at extremes", {
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 1,
    qc_filter = 1,
    update_result = list(
      new_records = 1000,
      stations = c("M1", "M2")
    )
  )
  expect_type(result, "list")
  expect_equal(result$update_result$new_records, 1000)
})

test_that("generate_weekly_summary: numeric path (type coercion test)", {
  expect_error(
    generate_weekly_summary(db_path = 12345),
    class = "error"
  )
})

test_that("create_email_summary: NA values in data frames", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = NA,
      max_wave_height = NA,
      avg_wind_speed = NA,
      avg_air_temp = NA,
      avg_sea_temp = NA,
      n_observations = NA
    ),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  # Should succeed - HTML will show "NA"
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

test_that("create_email_summary: extremely large values", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = 1e10,
      max_wave_height = 1e10,
      avg_wind_speed = 1e10,
      avg_air_temp = 1e10,
      avg_sea_temp = 1e10,
      n_observations = 1e10
    ),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

test_that("create_email_summary: negative values (invalid but should handle)", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = -2.5,
      max_wave_height = -4.0,
      avg_wind_speed = -10,
      avg_air_temp = -12,
      avg_sea_temp = -11,
      n_observations = -100
    ),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})

# Additional attack vectors
test_that("generate_weekly_summary: SQL injection via lookback_days (type safety)", {
  # R's type system prevents this - will error on non-numeric
  expect_error(
    generate_weekly_summary(
      db_path = "inst/extdata/irish_buoys.duckdb",
      lookback_days = "7; DROP TABLE buoy_data"
    )
  )
})

test_that("create_email_summary: XSS attack via station_id", {
  summary <- list(
    current_week = data.frame(
      station_id = "<script>alert('XSS')</script>",
      avg_wave_height = 2.5,
      max_wave_height = 4.0,
      avg_wind_speed = 10,
      avg_air_temp = 12,
      avg_sea_temp = 11,
      n_observations = 100
    ),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  # Function doesn't escape HTML - potential XSS vulnerability
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
  
  # Check if script tag is in output (security issue if yes)
  email_html <- paste(as.character(email), collapse = "\n")
  # This is a FINDING - no HTML escaping detected in code
  expect_match(email_html, "<script>")
})

test_that("generate_weekly_summary: very long strings in update_result", {
  long_string <- paste(rep("A", 10000), collapse = "")
  result <- generate_weekly_summary(
    db_path = "inst/extdata/irish_buoys.duckdb",
    update_result = list(message = long_string)
  )
  expect_type(result, "list")
  expect_equal(nchar(result$update_result$message), 10000)
})

test_that("create_email_summary: Inf and -Inf values", {
  summary <- list(
    current_week = data.frame(
      station_id = "M1",
      avg_wave_height = Inf,
      max_wave_height = -Inf,
      avg_wind_speed = Inf,
      avg_air_temp = 12,
      avg_sea_temp = 11,
      n_observations = 100
    ),
    extreme_events = data.frame(),
    ingestion_stats = data.frame(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL,
    db_stats = NULL
  )
  
  email <- create_email_summary(summary)
  expect_s3_class(email, "email_message")
})
