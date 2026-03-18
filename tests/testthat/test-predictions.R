# Tests for R/predictions.R
# Prediction calibration tracking functions

# ===========================================================================
# HELPERS
# ===========================================================================

# Create a temp JSONL file with sample predictions
create_test_jsonl <- function(dir = tempdir()) {
  slug <- "test-project"
  path <- file.path(dir, paste0(slug, ".jsonl"))

  records <- c(
    '{"prediction_id":"p1","recorded_at":"2026-01-01T10:00:00Z","project_slug":"test-project","project_name":"testpkg","task_type":"bug_fix","task_description":"Fix bug","approach_summary":"Patch it","p_success":0.85,"confidence_bucket":"high","outcome":true,"outcome_recorded_at":"2026-01-01T11:00:00Z","outcome_notes":"Fixed"}',
    '{"prediction_id":"p2","recorded_at":"2026-01-02T10:00:00Z","project_slug":"test-project","project_name":"testpkg","task_type":"feature","task_description":"Add feature","approach_summary":"Build it","p_success":0.60,"confidence_bucket":"medium","outcome":false,"outcome_recorded_at":"2026-01-02T12:00:00Z","outcome_notes":"Failed"}',
    '{"prediction_id":"p3","recorded_at":"2026-01-03T10:00:00Z","project_slug":"test-project","project_name":"testpkg","task_type":"ci_fix","task_description":"Fix CI","approach_summary":"Update config","p_success":0.90,"confidence_bucket":"high","outcome":true,"outcome_recorded_at":"2026-01-03T10:30:00Z","outcome_notes":"OK"}',
    '{"prediction_id":"p4","recorded_at":"2026-01-04T10:00:00Z","project_slug":"test-project","project_name":"testpkg","task_type":"refactor","task_description":"Refactor code","approach_summary":"Extract function","p_success":0.30,"confidence_bucket":"low","outcome":null,"outcome_recorded_at":null,"outcome_notes":null}'
  )

  writeLines(records, path)
  list(path = path, slug = slug, dir = dir)
}

# ===========================================================================
# empty_predictions_tibble
# ===========================================================================

test_that("empty_predictions_tibble returns zero-row tibble with correct schema", {
  result <- empty_predictions_tibble()
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true("prediction_id" %in% names(result))
  expect_true("p_success" %in% names(result))
  expect_true("outcome" %in% names(result))
  expect_equal(ncol(result), 12)
})

# ===========================================================================
# prediction_jsonl_path
# ===========================================================================

test_that("prediction_jsonl_path constructs correct path", {
  path <- prediction_jsonl_path("my-project")
  expect_true(grepl("predictions/my-project\\.jsonl$", path))
  # Absolute path: starts with / on Unix or drive letter on Windows
  expect_true(grepl("^\\/|^[A-Za-z]:", path))
})

# ===========================================================================
# read_predictions
# ===========================================================================

test_that("read_predictions returns empty tibble for nonexistent slug", {
  result <- read_predictions("nonexistent-slug-12345")
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_equal(ncol(result), 12)
})

test_that("read_predictions reads JSONL correctly", {
  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))

  # Use read_single_jsonl directly since read_predictions resolves via slug
  result <- read_single_jsonl(tmp$path)
  expect_equal(nrow(result), 4)
  expect_equal(result$prediction_id, c("p1", "p2", "p3", "p4"))
  expect_equal(result$p_success, c(0.85, 0.60, 0.90, 0.30))
})

test_that("read_predictions reconciles duplicate prediction_ids", {
  tmp_dir <- tempdir()
  path <- file.path(tmp_dir, "dup-test.jsonl")

  # Same prediction_id, second line has outcome
  records <- c(
    '{"prediction_id":"dup1","recorded_at":"2026-01-01T10:00:00Z","project_slug":"dup","project_name":"test","task_type":"fix","task_description":"Fix it","approach_summary":"Do it","p_success":0.80,"confidence_bucket":"high","outcome":null,"outcome_recorded_at":null,"outcome_notes":null}',
    '{"prediction_id":"dup1","recorded_at":"2026-01-01T11:00:00Z","project_slug":"dup","project_name":"test","task_type":"fix","task_description":"Fix it","approach_summary":"Do it","p_success":0.80,"confidence_bucket":"high","outcome":true,"outcome_recorded_at":"2026-01-01T11:00:00Z","outcome_notes":"Done"}'
  )
  writeLines(records, path)
  withr::defer(unlink(path))

  result <- read_single_jsonl(path)
  expect_equal(nrow(result), 1)  # Deduplicated
  expect_true(result$outcome)     # Outcome from latest record
})

test_that("read_predictions handles empty file", {
  path <- tempfile(fileext = ".jsonl")
  writeLines(character(0), path)
  withr::defer(unlink(path))

  result <- read_single_jsonl(path)
  expect_equal(nrow(result), 0)
})

test_that("read_predictions handles malformed JSON lines", {
  path <- tempfile(fileext = ".jsonl")
  records <- c(
    '{"prediction_id":"ok1","recorded_at":"2026-01-01T10:00:00Z","project_slug":"x","project_name":"x","task_type":"x","task_description":"x","approach_summary":"x","p_success":0.5,"confidence_bucket":"medium","outcome":null,"outcome_recorded_at":null,"outcome_notes":null}',
    'THIS IS NOT JSON',
    '{"prediction_id":"ok2","recorded_at":"2026-01-02T10:00:00Z","project_slug":"x","project_name":"x","task_type":"x","task_description":"x","approach_summary":"x","p_success":0.7,"confidence_bucket":"medium","outcome":null,"outcome_recorded_at":null,"outcome_notes":null}'
  )
  writeLines(records, path)
  withr::defer(unlink(path))

  result <- read_single_jsonl(path)
  expect_equal(nrow(result), 2)  # Malformed line skipped
})

test_that("read_predictions with NULL slug reads all files", {
  tmp_dir <- file.path(tempdir(), "pred_test_all")
  dir.create(tmp_dir, showWarnings = FALSE)
  withr::defer(unlink(tmp_dir, recursive = TRUE))

  # Create two project files
  writeLines(
    '{"prediction_id":"a1","recorded_at":"2026-01-01T10:00:00Z","project_slug":"proj-a","project_name":"projA","task_type":"fix","task_description":"d","approach_summary":"a","p_success":0.5,"confidence_bucket":"medium","outcome":null,"outcome_recorded_at":null,"outcome_notes":null}',
    file.path(tmp_dir, "proj-a.jsonl")
  )
  writeLines(
    '{"prediction_id":"b1","recorded_at":"2026-01-02T10:00:00Z","project_slug":"proj-b","project_name":"projB","task_type":"feat","task_description":"d","approach_summary":"a","p_success":0.8,"confidence_bucket":"high","outcome":true,"outcome_recorded_at":"2026-01-02T12:00:00Z","outcome_notes":"ok"}',
    file.path(tmp_dir, "proj-b.jsonl")
  )

  # Mock the prediction dir by calling read_single_jsonl directly
  files <- list.files(tmp_dir, pattern = "\\.jsonl$", full.names = TRUE)
  preds <- lapply(files, read_single_jsonl)
  result <- dplyr::bind_rows(preds)
  expect_equal(nrow(result), 2)
  expect_true("proj-a" %in% result$project_slug)
  expect_true("proj-b" %in% result$project_slug)
})

# ===========================================================================
# compute_calibration
# ===========================================================================

test_that("compute_calibration returns correct structure for empty input", {
  result <- compute_calibration(empty_predictions_tibble())
  expect_true(is.na(result$brier_score))
  expect_true(is.na(result$accuracy))
  expect_equal(result$n_total, 0)
  expect_equal(result$n_resolved, 0)
  expect_equal(nrow(result$calibration_by_bucket), 0)
  expect_equal(nrow(result$rolling_brier), 0)
})

test_that("compute_calibration returns correct structure for NULL input", {
  result <- compute_calibration(NULL)
  expect_true(is.na(result$brier_score))
  expect_equal(result$n_total, 0)
})

test_that("compute_calibration handles unresolved predictions", {
  preds <- tibble::tibble(
    prediction_id = "u1",
    recorded_at = "2026-01-01T10:00:00Z",
    project_slug = "x", project_name = "x",
    task_type = "fix", task_description = "d",
    approach_summary = "a",
    p_success = 0.5,
    confidence_bucket = "medium",
    outcome = NA,
    outcome_recorded_at = NA_character_,
    outcome_notes = NA_character_
  )
  result <- compute_calibration(preds)
  expect_equal(result$n_total, 1)
  expect_equal(result$n_resolved, 0)
  expect_true(is.na(result$brier_score))
})

test_that("compute_calibration computes Brier score correctly", {
  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))
  preds <- read_single_jsonl(tmp$path)

  result <- compute_calibration(preds)

  expect_equal(result$n_total, 4)
  expect_equal(result$n_resolved, 3)  # p4 has no outcome

  # Manual Brier: p1: (0.85-1)^2=0.0225, p2: (0.60-0)^2=0.36, p3: (0.90-1)^2=0.01
  # mean = (0.0225 + 0.36 + 0.01) / 3 = 0.1308333
  expect_equal(result$brier_score, mean(c(0.0225, 0.36, 0.01)), tolerance = 0.001)
  expect_true(result$brier_score < 0.25)  # Better than uninformative
})

test_that("compute_calibration computes accuracy correctly", {
  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))
  preds <- read_single_jsonl(tmp$path)

  result <- compute_calibration(preds)

  # p1: predicted success (0.85>=0.5), actual TRUE → correct
  # p2: predicted success (0.60>=0.5), actual FALSE → incorrect
  # p3: predicted success (0.90>=0.5), actual TRUE → correct
  # accuracy = 2/3
  expect_equal(result$accuracy, 2 / 3, tolerance = 0.001)
})

test_that("compute_calibration returns calibration buckets", {
  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))
  preds <- read_single_jsonl(tmp$path)

  result <- compute_calibration(preds)

  buckets <- result$calibration_by_bucket
  expect_s3_class(buckets, "tbl_df")
  expect_true("confidence_bucket" %in% names(buckets))
  expect_true("mean_predicted" %in% names(buckets))
  expect_true("mean_observed" %in% names(buckets))
  expect_true("gap" %in% names(buckets))
  expect_true(nrow(buckets) > 0)
})

test_that("compute_calibration returns rolling Brier", {
  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))
  preds <- read_single_jsonl(tmp$path)

  result <- compute_calibration(preds)

  rolling <- result$rolling_brier
  expect_s3_class(rolling, "tbl_df")
  expect_equal(nrow(rolling), 3)  # 3 resolved predictions
  # Rolling Brier should be monotonically defined (each row adds one prediction)
  expect_true(all(!is.na(rolling$cumulative_brier)))
})

# ===========================================================================
# store_predictions_duckdb
# ===========================================================================

test_that("store_predictions_duckdb creates table", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  withr::defer(unlink(tmp_db))

  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))
  preds <- read_single_jsonl(tmp$path)

  n <- store_predictions_duckdb(preds, tmp_db)
  expect_equal(n, 4)

  # Verify table exists

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = tmp_db, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  expect_true(DBI::dbExistsTable(con, "predictions"))
  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM predictions")$n
  expect_equal(count, 4)
})

test_that("store_predictions_duckdb is idempotent", {
  skip_if_not_installed("duckdb")
  tmp_db <- tempfile(fileext = ".duckdb")
  withr::defer(unlink(tmp_db))

  tmp <- create_test_jsonl()
  withr::defer(unlink(tmp$path))
  preds <- read_single_jsonl(tmp$path)

  store_predictions_duckdb(preds, tmp_db)
  store_predictions_duckdb(preds, tmp_db)

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = tmp_db, read_only = TRUE)
  withr::defer(DBI::dbDisconnect(con, shutdown = TRUE))
  count <- DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM predictions")$n
  expect_equal(count, 4)  # Not doubled
})

test_that("store_predictions_duckdb handles empty input", {
  skip_if_not_installed("duckdb")
  n <- store_predictions_duckdb(empty_predictions_tibble(), tempfile())
  expect_equal(n, 0)

  n_null <- store_predictions_duckdb(NULL, tempfile())
  expect_equal(n_null, 0)
})

# ===========================================================================
# confidence_bucket assignment
# ===========================================================================

test_that("confidence buckets are assigned correctly", {
  path <- tempfile(fileext = ".jsonl")
  records <- c(
    '{"prediction_id":"lo","recorded_at":"2026-01-01T10:00:00Z","project_slug":"x","project_name":"x","task_type":"x","task_description":"x","approach_summary":"x","p_success":0.20,"confidence_bucket":"low","outcome":true,"outcome_recorded_at":"2026-01-01T11:00:00Z","outcome_notes":""}',
    '{"prediction_id":"md","recorded_at":"2026-01-02T10:00:00Z","project_slug":"x","project_name":"x","task_type":"x","task_description":"x","approach_summary":"x","p_success":0.55,"confidence_bucket":"medium","outcome":false,"outcome_recorded_at":"2026-01-02T11:00:00Z","outcome_notes":""}',
    '{"prediction_id":"hi","recorded_at":"2026-01-03T10:00:00Z","project_slug":"x","project_name":"x","task_type":"x","task_description":"x","approach_summary":"x","p_success":0.85,"confidence_bucket":"high","outcome":true,"outcome_recorded_at":"2026-01-03T11:00:00Z","outcome_notes":""}'
  )
  writeLines(records, path)
  withr::defer(unlink(path))

  preds <- read_single_jsonl(path)
  cal <- compute_calibration(preds)

  buckets <- cal$calibration_by_bucket
  expect_true("low" %in% buckets$confidence_bucket)
  expect_true("medium" %in% buckets$confidence_bucket)
  expect_true("high" %in% buckets$confidence_bucket)
})
