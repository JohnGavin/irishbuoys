# Tests for R/database.R
# Basic coverage tests for connect_duckdb, buoy_tbl, create_buoy_schema,
# load_to_duckdb, query_buoy_data, get_database_stats

test_that("connect_duckdb creates new database", {
  tmp_db <- file.path(tempdir(), "test_new.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  expect_true(DBI::dbIsValid(con))
  expect_true(DBI::dbExistsTable(con, "buoy_data"))
  expect_true(DBI::dbExistsTable(con, "stations"))
  expect_true(DBI::dbExistsTable(con, "update_log"))
  DBI::dbDisconnect(con)
})

test_that("connect_duckdb connects to existing database", {
  con <- connect_duckdb(db_path = "inst/extdata/irish_buoys.duckdb")
  expect_true(DBI::dbIsValid(con))
  DBI::dbDisconnect(con)
})

test_that("connect_duckdb creates directory if missing", {
  tmp_dir <- file.path(tempdir(), "test_subdir_db")
  tmp_db <- file.path(tmp_dir, "test.duckdb")
  on.exit(unlink(tmp_dir, recursive = TRUE), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  expect_true(dir.exists(tmp_dir))
  expect_true(DBI::dbIsValid(con))
  DBI::dbDisconnect(con)
})

test_that("buoy_tbl returns lazy tbl", {
  con <- connect_duckdb(db_path = "inst/extdata/irish_buoys.duckdb")
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  tbl <- buoy_tbl(con)
  expect_s3_class(tbl, "tbl_dbi")
})

test_that("create_buoy_schema is idempotent", {
  tmp_db <- file.path(tempdir(), "test_schema.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = tmp_db)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  # Call twice - should not error
  create_buoy_schema(con)
  create_buoy_schema(con)

  expect_true(DBI::dbExistsTable(con, "buoy_data"))
  expect_true(DBI::dbExistsTable(con, "stations"))
})

test_that("get_database_stats returns expected structure", {
  stats <- get_database_stats(db_path = "inst/extdata/irish_buoys.duckdb")
  expect_type(stats, "list")
  expect_true("overall" %in% names(stats))
  expect_true("by_station" %in% names(stats))
  expect_true("db_size_mb" %in% names(stats))
  expect_true(stats$overall$total_records >= 0)
})

test_that("query_buoy_data returns data frame", {
  con <- connect_duckdb(db_path = "inst/extdata/irish_buoys.duckdb")
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- query_buoy_data(con,
    start_date = as.POSIXct("2024-01-01"),
    end_date = as.POSIXct("2024-01-02"))
  expect_s3_class(result, "data.frame")
})

test_that("query_buoy_data filters by station", {
  con <- connect_duckdb(db_path = "inst/extdata/irish_buoys.duckdb")
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  result <- query_buoy_data(con, stations = "M3",
    start_date = as.POSIXct("2024-01-01"),
    end_date = as.POSIXct("2024-01-02"))
  if (nrow(result) > 0) {
    expect_true(all(result$station_id == "M3"))
  }
})

test_that("connect_duckdb with create_new replaces existing", {
  tmp_db <- file.path(tempdir(), "test_replace.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  # Create first

  con1 <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  DBI::dbExecute(con1, "INSERT INTO stations (station_id) VALUES ('TEST')")
  DBI::dbDisconnect(con1)

  # Create new replaces
  con2 <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  count <- DBI::dbGetQuery(con2, "SELECT COUNT(*) as n FROM stations")$n
  expect_equal(count, 0)
  DBI::dbDisconnect(con2)
})

# --- Tests for load_to_duckdb ---

test_that("load_to_duckdb inserts data and returns row count", {
  tmp_db <- file.path(tempdir(), "test_load.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-01 00:00", "2024-01-01 01:00")),
    station_id = c("M2", "M2"),
    wave_height = c(2.5, 3.0),
    hmax = c(4.0, 5.5),
    wave_period = c(8.0, 9.0),
    wind_speed = c(15, 20),
    qc_flag = c(1L, 1L),
    stringsAsFactors = FALSE
  )

  rows <- load_to_duckdb(data, con, update_metadata = FALSE)
  expect_equal(rows, 2)

  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM buoy_data")$n

  expect_equal(count, 2)
})

test_that("load_to_duckdb handles duplicates via ON CONFLICT", {
  tmp_db <- file.path(tempdir(), "test_load_dup.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct("2024-01-01 00:00"),
    station_id = "M2",
    wave_height = 2.5,
    qc_flag = 1L,
    stringsAsFactors = FALSE
  )

  # Insert once
  rows1 <- load_to_duckdb(data, con, update_metadata = FALSE)
  expect_equal(rows1, 1)

  # Insert same row again - should be 0 new
  rows2 <- load_to_duckdb(data, con, update_metadata = FALSE)
  expect_equal(rows2, 0)
})

test_that("load_to_duckdb standardizes column names", {
  tmp_db <- file.path(tempdir(), "test_load_names.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  # ERDDAP-style column names
  data <- data.frame(
    time = as.POSIXct("2024-01-01 00:00"),
    station_id = "M3",
    WaveHeight = 3.0,
    WindSpeed = 15,
    AirTemperature = 12.5,
    SeaTemperature = 10.0,
    qc_flag = 1L,
    stringsAsFactors = FALSE
  )

  rows <- load_to_duckdb(data, con, update_metadata = FALSE)
  expect_equal(rows, 1)

  result <- DBI::dbGetQuery(con, "SELECT wave_height, wind_speed FROM buoy_data")
  expect_equal(result$wave_height, 3.0)
  expect_equal(result$wind_speed, 15)
})

test_that("load_to_duckdb converts NaN to NA", {
  tmp_db <- file.path(tempdir(), "test_load_nan.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct("2024-01-01 00:00"),
    station_id = "M2",
    wave_height = NaN,
    wind_speed = 15,
    qc_flag = 1L,
    stringsAsFactors = FALSE
  )

  rows <- load_to_duckdb(data, con, update_metadata = FALSE)
  expect_equal(rows, 1)

  result <- DBI::dbGetQuery(con, "SELECT wave_height FROM buoy_data")
  expect_true(is.na(result$wave_height))
})

test_that("load_to_duckdb logs update when rows added", {
  tmp_db <- file.path(tempdir(), "test_load_log.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-01 00:00", "2024-01-01 01:00")),
    station_id = c("M2", "M3"),
    wave_height = c(2.5, 3.0),
    qc_flag = c(1L, 1L),
    stringsAsFactors = FALSE
  )

  load_to_duckdb(data, con, update_metadata = FALSE)

  log <- DBI::dbGetQuery(con, "SELECT * FROM update_log")
  expect_equal(nrow(log), 1)
  expect_equal(log$records_added, 2)
  expect_true(grepl("M2", log$stations_updated))
  expect_true(grepl("M3", log$stations_updated))
})

# --- Tests for query_buoy_data additional filters ---

test_that("query_buoy_data qc_filter=FALSE returns all records", {
  tmp_db <- file.path(tempdir(), "test_qc_filter.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-01 00:00", "2024-01-01 01:00", "2024-01-01 02:00")),
    station_id = c("M2", "M2", "M2"),
    wave_height = c(2.5, 3.0, 1.0),
    qc_flag = c(1L, 0L, 1L),
    stringsAsFactors = FALSE
  )
  load_to_duckdb(data, con, update_metadata = FALSE)

  # With qc_filter (default TRUE) - should exclude qc_flag=0
  filtered <- query_buoy_data(con, qc_filter = TRUE)
  expect_equal(nrow(filtered), 2)

  # Without qc_filter - should return all 3
  all_data <- query_buoy_data(con, qc_filter = FALSE)
  expect_equal(nrow(all_data), 3)
})

test_that("query_buoy_data selects specific variables", {
  tmp_db <- file.path(tempdir(), "test_vars.duckdb")
  on.exit(unlink(tmp_db), add = TRUE)

  con <- connect_duckdb(db_path = tmp_db, create_new = TRUE)
  on.exit(DBI::dbDisconnect(con), add = TRUE, after = FALSE)

  data <- data.frame(
    time = as.POSIXct("2024-01-01 00:00"),
    station_id = "M2",
    wave_height = 2.5,
    wind_speed = 15,
    qc_flag = 1L,
    stringsAsFactors = FALSE
  )
  load_to_duckdb(data, con, update_metadata = FALSE)

  result <- query_buoy_data(con, variables = c("time", "wave_height"))
  expect_equal(ncol(result), 2)
  expect_true(all(c("time", "wave_height") %in% names(result)))
})
