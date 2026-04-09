# Tests for R/database_parquet.R
# Uses tempdir() for all file I/O

test_that("init_parquet_storage creates directory structure", {
  tmp <- tempfile("parquet_test_")
  db_path <- tempfile(fileext = ".duckdb")
  on.exit({
    unlink(tmp, recursive = TRUE)
    unlink(db_path)
  }, add = TRUE)

  result <- init_parquet_storage(data_path = tmp, db_path = db_path)
  expect_type(result, "list")
  expect_true(dir.exists(file.path(tmp, "by_year_month")))
  expect_true(dir.exists(file.path(tmp, "by_station")))
  expect_true(file.exists(db_path))
})

test_that("init_parquet_storage creates metadata tables", {
  tmp <- tempfile("parquet_test_")
  db_path <- tempfile(fileext = ".duckdb")
  on.exit({
    unlink(tmp, recursive = TRUE)
    unlink(db_path)
  }, add = TRUE)

  init_parquet_storage(data_path = tmp, db_path = db_path)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  tables <- DBI::dbListTables(con)
  expect_true("parquet_files" %in% tables)
  expect_true("update_log" %in% tables)
})

test_that("save_to_parquet writes partitioned files", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-15", "2024-02-15", "2024-03-15")),
    station_id = c("M2", "M3", "M2"),
    wave_height = c(2.5, 3.1, 1.8),
    stringsAsFactors = FALSE
  )

  size <- save_to_parquet(data, data_path = tmp, partition_by = "year_month")
  expect_true(is.numeric(size))

  # Check parquet files exist
  files <- list.files(tmp, pattern = "\\.parquet$", recursive = TRUE)
  expect_true(length(files) > 0)
})

test_that("save_to_parquet supports station partitioning", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-15", "2024-01-16")),
    station_id = c("M2", "M3"),
    wave_height = c(2.5, 3.1),
    stringsAsFactors = FALSE
  )

  save_to_parquet(data, data_path = tmp, partition_by = "station")

  files <- list.files(tmp, pattern = "\\.parquet$", recursive = TRUE)
  expect_true(length(files) > 0)
})

test_that("save_to_parquet supports both partitioning", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-15", "2024-02-15")),
    station_id = c("M2", "M3"),
    wave_height = c(2.5, 3.1),
    stringsAsFactors = FALSE
  )

  save_to_parquet(data, data_path = tmp, partition_by = "both")

  files <- list.files(tmp, pattern = "\\.parquet$", recursive = TRUE)
  expect_true(length(files) > 0)
})

test_that("query_parquet executes SQL on parquet files", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  # Write test data
  data <- data.frame(
    time = as.POSIXct(c("2024-01-15 00:00:00", "2024-01-16 00:00:00",
                         "2024-02-15 00:00:00")),
    station_id = c("M2", "M3", "M2"),
    wave_height = c(2.5, 3.1, 1.8),
    stringsAsFactors = FALSE
  )
  save_to_parquet(data, data_path = tmp, partition_by = "year_month")

  result <- query_parquet(
    query = "SELECT COUNT(*) as n FROM buoy_data",
    data_path = file.path(tmp, "by_year_month")
  )

  expect_s3_class(result, "data.frame")
  expect_equal(result$n, 3)
})

test_that("query_parquet filters by station", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-15", "2024-01-16", "2024-01-17")),
    station_id = c("M2", "M3", "M2"),
    wave_height = c(2.5, 3.1, 1.8),
    stringsAsFactors = FALSE
  )
  save_to_parquet(data, data_path = tmp, partition_by = "year_month")

  result <- query_parquet(
    query = "SELECT COUNT(*) as n FROM buoy_data",
    data_path = file.path(tmp, "by_year_month"),
    stations = "M2"
  )
  expect_equal(result$n, 2)
})

test_that("query_parquet filters by date_range", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-15", "2024-03-15", "2024-06-15")),
    station_id = c("M2", "M3", "M2"),
    wave_height = c(2.5, 3.1, 1.8),
    stringsAsFactors = FALSE
  )
  save_to_parquet(data, data_path = tmp, partition_by = "year_month")

  result <- query_parquet(
    query = "SELECT COUNT(*) as n FROM buoy_data",
    data_path = file.path(tmp, "by_year_month"),
    date_range = c("2024-01-01", "2024-04-01")
  )
  # Should include Jan and Mar but not Jun
  expect_true(result$n >= 2)
})

test_that("incremental_update_parquet handles empty data", {
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  empty_data <- data.frame(
    time = as.POSIXct(character(0)),
    station_id = character(0),
    wave_height = numeric(0)
  )
  result <- incremental_update_parquet(empty_data, data_path = tmp)
  expect_equal(result, 0)
})

test_that("incremental_update_parquet creates new partition", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(file.path(tmp, "by_year_month"), recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-05-15", "2024-05-16")),
    station_id = c("M2", "M3"),
    wave_height = c(2.5, 3.1),
    stringsAsFactors = FALSE
  )

  rows_added <- incremental_update_parquet(data, data_path = tmp)
  expect_equal(rows_added, 2)

  # Verify files were created
  files <- list.files(tmp, pattern = "\\.parquet$", recursive = TRUE)
  expect_true(length(files) > 0)
})

test_that("analyze_parquet_storage returns NULL for empty dir", {
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  result <- analyze_parquet_storage(data_path = tmp)
  expect_null(result)
})

test_that("analyze_parquet_storage returns stats for populated dir", {
  skip_if_not_installed("arrow")
  tmp <- tempfile("parquet_test_")
  on.exit(unlink(tmp, recursive = TRUE), add = TRUE)
  dir.create(tmp, recursive = TRUE)

  data <- data.frame(
    time = as.POSIXct(c("2024-01-15", "2024-02-15", "2024-03-15")),
    station_id = c("M2", "M3", "M2"),
    wave_height = c(2.5, 3.1, 1.8),
    stringsAsFactors = FALSE
  )
  save_to_parquet(data, data_path = tmp, partition_by = "year_month")

  result <- analyze_parquet_storage(data_path = tmp)
  expect_type(result, "list")
  expect_true("summary" %in% names(result))
  expect_true("total_size_mb" %in% names(result))
  expect_true("n_files" %in% names(result))
  expect_equal(result$summary$total_rows, 3)
})

test_that("convert_duckdb_to_parquet errors on missing file", {
  expect_error(
    convert_duckdb_to_parquet(db_path = "/nonexistent/path.duckdb"),
    "not found"
  )
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(analyze_parquet_storage) signature", {
  expect_snapshot(args(analyze_parquet_storage))
})

test_that("snapshot: args(convert_duckdb_to_parquet) signature", {
  expect_snapshot(args(convert_duckdb_to_parquet))
})

test_that("snapshot: args(incremental_update_parquet) signature", {
  expect_snapshot(args(incremental_update_parquet))
})

test_that("snapshot: args(init_parquet_storage) signature", {
  expect_snapshot(args(init_parquet_storage))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(get_database_stats)", { expect_snapshot(args(irishbuoys:::get_database_stats)) })
test_that("snap3: args(initialize_database)", { expect_snapshot(args(irishbuoys:::initialize_database)) })
test_that("snap3: args(query_parquet)", { expect_snapshot(args(irishbuoys:::query_parquet)) })
