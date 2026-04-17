# Tests for R/huggingface.R

test_that("ib_hf_url returns correct hf:// URL", {
  url <- ib_hf_url()
  expect_match(url, "^hf://datasets/")
  expect_match(url, "buoy_data\\.parquet$")
  expect_equal(url, "hf://datasets/dsfefvx/irish-buoy-network/buoy_data.parquet")
})

test_that("ib_hf_url accepts custom filename", {
  url <- ib_hf_url("stations.json")
  expect_match(url, "stations\\.json$")
})

test_that("ib_hf_url respects IB_HF_REPO env var", {
  withr::local_envvar(IB_HF_REPO = "testuser/test-repo")
  expect_equal(
    ib_hf_url(),
    "hf://datasets/testuser/test-repo/buoy_data.parquet"
  )
})

test_that("ib_hf_online returns logical", {
  result <- ib_hf_online()
  expect_type(result, "logical")
  expect_length(result, 1L)
})

test_that("ib_hf_online returns FALSE for nonexistent repo", {
  withr::local_envvar(IB_HF_REPO = "nonexistent-user-99999/nonexistent-repo-99999")
  expect_false(ib_hf_online())
})

test_that("ib_hf_connect returns valid DBI connection", {
  con <- ib_hf_connect()
  on.exit(DBI::dbDisconnect(con))
  expect_true(DBI::dbIsValid(con))
})

test_that("ib_hf_url snapshot", {
  expect_snapshot(ib_hf_url())
  expect_snapshot(ib_hf_url("stations.json"))
})

test_that("local Parquet schema snapshot", {
  parquet_path <- system.file(
    "extdata", "buoy_data_sample.parquet",
    package = "irishbuoys"
  )
  # Fall back to docs/ export if sample not bundled

  if (!nzchar(parquet_path)) {
    parquet_path <- file.path(
      testthat::test_path("..", "..", "docs", "vignettes", "data", "buoy_data.parquet")
    )
  }
  skip_if_not(file.exists(parquet_path), "No local Parquet file available")

  schema <- arrow::read_parquet(parquet_path, as_data_frame = FALSE)$schema
  expect_snapshot(schema)
})
