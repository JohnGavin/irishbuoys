# Tests for API backward compatibility (#74)
# Snapshot tests that catch schema drift in API outputs and Parquet export

test_that("API JSON endpoints have stable schema", {
  api_dir <- testthat::test_path("..", "..", "docs", "api", "v1")
  skip_if_not(dir.exists(api_dir), "No API directory")

  # Core endpoints that users depend on
  endpoints <- c("stations", "stats", "latest", "trends", "seasonal")

  for (ep in endpoints) {
    path <- file.path(api_dir, paste0(ep, ".json"))
    skip_if_not(file.exists(path), paste("Missing:", ep))
    data <- jsonlite::fromJSON(path)
    expect_snapshot(sort(names(data)), variant = ep)
  }
})

test_that("stations.json has all 5 canonical stations", {
  path <- testthat::test_path("..", "..", "docs", "api", "v1", "stations.json")
  skip_if_not(file.exists(path))

  stations <- jsonlite::fromJSON(path)
  station_ids <- sort(stations$station_id %||% names(stations))
  expect_snapshot(station_ids)
})

test_that("Parquet schema is stable", {
  parquet_path <- testthat::test_path(
    "..", "..", "docs", "vignettes", "data", "buoy_data.parquet"
  )
  skip_if_not(file.exists(parquet_path), "No local Parquet")

  schema <- arrow::read_parquet(parquet_path, as_data_frame = FALSE)$schema
  col_names <- sort(names(schema))
  expect_snapshot(col_names)
})

test_that("Parquet has expected row count range", {
  parquet_path <- testthat::test_path(
    "..", "..", "docs", "vignettes", "data", "buoy_data.parquet"
  )
  skip_if_not(file.exists(parquet_path), "No local Parquet")

  n <- nrow(arrow::read_parquet(parquet_path))
  # Should have at least 200K rows (7+ years of hourly data from 5 stations)
  expect_gt(n, 200000)
  # Should not exceed 1M (sanity check against accidental duplication)
  expect_lt(n, 1000000)
})

test_that("get_station_info returns canonical station list", {
  info <- get_station_info()
  expect_s3_class(info, "data.frame")
  expect_true("station_id" %in% names(info))
  # Canonical 5 stations
  expect_equal(nrow(info), 5L)
  expect_snapshot(sort(info$station_id))
})

test_that("HuggingFace Parquet schema matches local Parquet", {
  skip_if_not(ib_hf_online(), "HuggingFace not reachable")
  skip_on_cran()

  local_path <- testthat::test_path(
    "..", "..", "docs", "vignettes", "data", "buoy_data.parquet"
  )
  skip_if_not(file.exists(local_path), "No local Parquet")

  local_schema <- sort(names(
    arrow::read_parquet(local_path, as_data_frame = FALSE)$schema
  ))

  con <- ib_hf_connect()
  on.exit(DBI::dbDisconnect(con))

  hf_cols <- sort(DBI::dbGetQuery(
    con,
    paste0("SELECT * FROM read_parquet('", ib_hf_url(), "') LIMIT 0")
  ) |> names())

  expect_equal(hf_cols, local_schema)
})
