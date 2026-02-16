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
