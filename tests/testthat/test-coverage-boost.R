# Coverage boost tests — targeting specific uncovered branches
# to push from 82.3% → 83.2%+ (Gold quality gate)

# ============================================================================
# email_summary.R — create_email_summary with synthetic summary objects
# ============================================================================

test_that("create_email_summary renders week_over_week table with color", {
  summary_obj <- list(
    extreme_events = data.frame(
      station_id = character(0), time = as.POSIXct(character(0)),
      event_type = character(0), value = numeric(0)
    ),
    current_week = data.frame(
      station_id = "M2", n_observations = 100L,
      max_wave_height = 5.2, avg_wave_height = 2.1,
      avg_wind_speed = 12.3, avg_air_temp = 10.1, avg_sea_temp = 11.5,
      stringsAsFactors = FALSE
    ),
    data_coverage = NULL,
    ingestion_stats = NULL,
    db_stats = NULL,
    update_result = NULL,
    report_date = Sys.Date(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = data.frame(
      station_id = "M2",
      wave_change_pct = 10.5,
      wind_change_pct = -5.2,
      stringsAsFactors = FALSE
    )
  )
  email <- create_email_summary(summary_obj)
  expect_s3_class(email, "email_message")
  html <- paste(as.character(email), collapse = "\n")
  expect_match(html, "red")
  expect_match(html, "green")
  expect_match(html, "Week-over-Week")
  expect_match(html, "10.5%")
})

test_that("create_email_summary renders staleness alert in red", {
  now <- Sys.time()
  summary_obj <- list(
    extreme_events = data.frame(
      station_id = character(0), time = as.POSIXct(character(0)),
      event_type = character(0), value = numeric(0)
    ),
    current_week = data.frame(
      station_id = character(0), n_observations = integer(0),
      max_wave_height = numeric(0), avg_wave_height = numeric(0),
      avg_wind_speed = numeric(0), avg_air_temp = numeric(0),
      avg_sea_temp = numeric(0), stringsAsFactors = FALSE
    ),
    data_coverage = NULL,
    ingestion_stats = data.frame(
      station_id = "M2", new_records = 5L,
      earliest = now - 48 * 3600, latest = now - 25 * 3600,
      report_composed = now, staleness_hours = 25, staleness_alert = TRUE,
      stringsAsFactors = FALSE
    ),
    db_stats = list(total_records = 1000, db_size_mb = 5.0),
    update_result = NULL,
    report_date = Sys.Date(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL
  )
  email <- create_email_summary(summary_obj)
  html <- paste(as.character(email), collapse = "\n")
  expect_match(html, "#dc3545")
  expect_match(html, "STALE")
  expect_match(html, "Data Ingestion")
})

test_that("create_email_summary renders coverage section with gaps", {
  now <- Sys.time()
  summary_obj <- list(
    extreme_events = data.frame(
      station_id = character(0), time = as.POSIXct(character(0)),
      event_type = character(0), value = numeric(0)
    ),
    current_week = data.frame(
      station_id = character(0), n_observations = integer(0),
      max_wave_height = numeric(0), avg_wave_height = numeric(0),
      avg_wind_speed = numeric(0), avg_air_temp = numeric(0),
      avg_sea_temp = numeric(0), stringsAsFactors = FALSE
    ),
    data_coverage = list(
      coverage = data.frame(
        station_id = c("M2", "M3"),
        expected_hours = c(168L, 168L),
        actual_hours = c(160L, 100L),
        coverage_pct = c(95.2, 59.5),
        missing_hours = c(8L, 68L),
        stringsAsFactors = FALSE
      ),
      gaps = data.frame(
        station_id = "M3",
        gap_start = now - 48 * 3600,
        gap_end = now - 24 * 3600,
        gap_hours = 24,
        stringsAsFactors = FALSE
      )
    ),
    ingestion_stats = NULL,
    db_stats = NULL,
    update_result = NULL,
    report_date = Sys.Date(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL
  )
  email <- create_email_summary(summary_obj)
  html <- paste(as.character(email), collapse = "\n")
  expect_match(html, "Data Coverage")
  expect_match(html, "#dc3545")
  expect_match(html, "Significant Gaps")
})

test_that("create_email_summary renders extreme events table", {
  summary_obj <- list(
    extreme_events = data.frame(
      station_id = "M2",
      time = as.character(Sys.time()),
      event_type = "wave_height",
      value = 12.5,
      stringsAsFactors = FALSE
    ),
    current_week = data.frame(
      station_id = "M2", n_observations = 100L,
      max_wave_height = 12.5, avg_wave_height = 3.1,
      avg_wind_speed = 25.0, avg_air_temp = 8.0, avg_sea_temp = 10.0,
      stringsAsFactors = FALSE
    ),
    data_coverage = NULL,
    ingestion_stats = NULL,
    db_stats = NULL,
    update_result = NULL,
    report_date = Sys.Date(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL
  )
  email <- create_email_summary(summary_obj)
  html <- paste(as.character(email), collapse = "\n")
  expect_match(html, "Extreme Events")
  expect_match(html, "12.5")
})

test_that("create_email_summary renders station stats with missing_hours", {
  summary_obj <- list(
    extreme_events = data.frame(
      station_id = character(0), time = as.POSIXct(character(0)),
      event_type = character(0), value = numeric(0)
    ),
    current_week = data.frame(
      station_id = c("M2", "M3"), n_observations = c(100L, 80L),
      max_wave_height = c(5.2, 4.1), avg_wave_height = c(2.1, 1.8),
      avg_wind_speed = c(12.3, 10.5), avg_air_temp = c(10.1, 9.8),
      avg_sea_temp = c(11.5, 11.0),
      stringsAsFactors = FALSE
    ),
    data_coverage = list(
      coverage = data.frame(
        station_id = c("M2", "M3"),
        expected_hours = c(168L, 168L),
        actual_hours = c(160L, 140L),
        coverage_pct = c(95.2, 83.3),
        missing_hours = c(8L, 28L),
        stringsAsFactors = FALSE
      ),
      gaps = data.frame(
        station_id = character(0), gap_start = as.POSIXct(character(0)),
        gap_end = as.POSIXct(character(0)), gap_hours = numeric(0)
      )
    ),
    ingestion_stats = NULL,
    db_stats = NULL,
    update_result = NULL,
    report_date = Sys.Date(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL
  )
  email <- create_email_summary(summary_obj)
  html <- paste(as.character(email), collapse = "\n")
  expect_match(html, "Missing Hours")
  expect_match(html, "Station M")
})

# ============================================================================
# extreme_values.R — calculate_gpd_return_levels lambda paths
# ============================================================================

test_that("calculate_gpd_return_levels uses explicit exceedance_rate", {
  fit <- list(u = 5.0, scale = 1.2, shape = 0.1, n_exceed = 500)
  result <- calculate_gpd_return_levels(
    fit, return_periods = c(10, 50),
    exceedance_rate = 0.05
  )
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true(all(is.finite(result$return_level)))
  expect_true(all(diff(result$return_level) > 0))
})

test_that("calculate_gpd_return_levels uses n_total for lambda", {
  fit <- list(u = 5.0, scale = 1.2, shape = 0.1, n_exceed = 500)
  result <- calculate_gpd_return_levels(
    fit, return_periods = c(10, 50),
    n_total = 10000
  )
  expect_s3_class(result, "data.frame")
  expect_equal(nrow(result), 2)
  expect_true(all(is.finite(result$return_level)))
})

test_that("calculate_return_levels handles single return period", {
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
  levels <- calculate_return_levels(gev, return_periods = 100)
  expect_s3_class(levels, "data.frame")
  expect_equal(nrow(levels), 1)
  expect_true(is.finite(levels$return_level))
})

test_that("fit_gpd_threshold with decluster=TRUE reduces exceedances", {
  skip_if_not_installed("extRemes")
  set.seed(42)
  n <- 5000
  times <- seq.POSIXt(
    as.POSIXct("2015-01-01", tz = "UTC"),
    by = "hour", length.out = n
  )
  data <- data.frame(
    time = times,
    wave_height = rgamma(n, shape = 3, rate = 1) + 1
  )
  result_decluster <- fit_gpd_threshold(
    data, threshold = 5, decluster = TRUE, decluster_hours = 48
  )
  result_nodecluster <- fit_gpd_threshold(
    data, threshold = 5, decluster = FALSE
  )
  expect_type(result_decluster, "list")
  expect_false(is.null(result_decluster$fit))
  expect_true(
    result_decluster$n_exceedances <= result_nodecluster$n_exceedances
  )
})

# ============================================================================
# validation.R — create_validation_summary and generate_validation_reports
# ============================================================================

test_that("create_validation_summary returns tibble from interrogated agent", {
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
  agent <- pointblank::create_agent(tbl = data) |>
    pointblank::col_exists(columns = "station_id") |>
    pointblank::interrogate()

  result <- create_validation_summary(analysis = agent)
  expect_s3_class(result, "data.frame")
  expect_true("target" %in% names(result))
  expect_true("status" %in% names(result))
  expect_true("checks_passed" %in% names(result))
  expect_true("checks_total" %in% names(result))
  expect_equal(nrow(result), 1)
  expect_equal(result$target, "analysis")
  expect_equal(result$status, "PASSED")
})

test_that("create_validation_summary handles multiple agents", {
  skip_if_not_installed("pointblank")
  data1 <- data.frame(x = 1:5)
  data2 <- data.frame(y = c(1, 2, NA, 4, 5))

  agent1 <- pointblank::create_agent(tbl = data1) |>
    pointblank::col_exists(columns = "x") |>
    pointblank::interrogate()

  agent2 <- pointblank::create_agent(tbl = data2) |>
    pointblank::col_exists(columns = "y") |>
    pointblank::interrogate()

  result <- create_validation_summary(first = agent1, second = agent2)
  expect_equal(nrow(result), 2)
  expect_equal(result$target, c("first", "second"))
})

test_that("generate_validation_reports creates HTML files", {
  skip_if_not_installed("pointblank")
  set.seed(42)
  n <- 200
  analysis_data <- data.frame(
    station_id = sample(c("M2", "M3", "M4"), n, replace = TRUE),
    time = seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = n),
    wave_height = runif(n, 0.5, 10),
    hmax = runif(n, 1, 20),
    wind_speed = runif(n, 0, 40),
    gust = runif(n, 0, 60),
    atmospheric_pressure = runif(n, 980, 1040)
  )
  rogue_events <- data.frame(
    station_id = c("M2", "M3"),
    time = Sys.time() + 1:2,
    wave_height = c(5, 6),
    hmax = c(11, 13),
    rogue_ratio = c(2.2, 2.17)
  )
  tmp_dir <- file.path(tempdir(), "val_report_test")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  result <- generate_validation_reports(
    analysis_data, rogue_events, output_dir = tmp_dir
  )
  expect_type(result, "list")
  expect_true("analysis_data" %in% names(result))
  expect_true("rogue_events" %in% names(result))
  expect_true("generated_time" %in% names(result))
})

# ============================================================================
# database_parquet.R — incremental_update_parquet dedup branch
# ============================================================================

test_that("incremental_update_parquet deduplicates on second call", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_inc_dedup_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(file.path(tmp, "by_year_month"), recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-05-15", "2024-05-16")),
    station_id = c("M2", "M3"),
    wave_height = c(2.5, 3.1),
    stringsAsFactors = FALSE
  )

  # First call creates partition
  rows1 <- incremental_update_parquet(data, data_path = tmp)
  expect_equal(rows1, 2)

  # Second call with same data: 0 new rows (dedup)
  rows2 <- incremental_update_parquet(data, data_path = tmp)
  expect_equal(rows2, 0)

  # Call with one new + one duplicate: only 1 new row
  data2 <- data.frame(
    time = as.POSIXct(c("2024-05-15", "2024-05-17")),
    station_id = c("M2", "M4"),
    wave_height = c(2.5, 4.0),
    stringsAsFactors = FALSE
  )
  rows3 <- incremental_update_parquet(data2, data_path = tmp)
  expect_equal(rows3, 1)
})

# ============================================================================
# database.R — load_to_duckdb with update_metadata=TRUE, log_update notes
# ============================================================================

test_that("load_to_duckdb with update_metadata=TRUE populates stations", {
  tmp_db <- file.path(tempdir(), "test_meta_update.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-01 00:00", "2024-01-01 01:00")),
    station_id = c("M2", "M2"),
    wave_height = c(2.5, 3.0),
    longitude = c(-13.0, -13.0),
    latitude = c(53.0, 53.0),
    call_sign = c("M2", "M2"),
    qc_flag = c(1L, 1L),
    stringsAsFactors = FALSE
  )
  rows <- load_to_duckdb(data, con, update_metadata = TRUE)
  expect_equal(rows, 2)

  stations <- DBI::dbGetQuery(con, "SELECT * FROM stations")
  expect_true("M2" %in% stations$station_id)
})

test_that("log_update records notes field correctly", {
  tmp_db <- file.path(tempdir(), "test_log_notes.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  irishbuoys:::log_update(
    con,
    start_date = as.POSIXct("2024-01-01"),
    end_date = as.POSIXct("2024-01-07"),
    records_added = 42,
    stations = "M2,M3",
    notes = "test run note"
  )
  log <- DBI::dbGetQuery(con, "SELECT * FROM update_log")
  expect_equal(nrow(log), 1)
  expect_equal(log$notes, "test run note")
})
