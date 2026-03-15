# Prediction Calibration Tracking
#
# Functions for reading prediction JSONL files, computing calibration metrics
# (Brier score, reliability diagrams), and storing to DuckDB.
#
# JSONL files live in ~/.claude/predictions/{project_slug}.jsonl and are
# the source of truth. DuckDB tables are derived materialised copies.

# NSE global variables
utils::globalVariables(c(
  "prediction_id", "recorded_at", "project_slug", "project_name",
  "task_type", "task_description", "approach_summary", "p_success",
  "confidence_bucket", "outcome", "outcome_recorded_at", "outcome_notes",
  "outcome_binary", "sq_error", "cumulative_brier", "predicted_success"
))

# ============================================================================
# HELPERS
# ============================================================================

#' Resolve JSONL path for a project slug
#' @param project_slug Character slug (directory name under ~/.claude/projects/)
#' @return Expanded file path
#' @noRd
prediction_jsonl_path <- function(project_slug) {
  path.expand(file.path("~/.claude/predictions", paste0(project_slug, ".jsonl")))
}

#' Empty predictions tibble with correct schema
#' @return Zero-row tibble
#' @noRd
empty_predictions_tibble <- function() {
 tibble::tibble(
    prediction_id = character(),
    recorded_at = character(),
    project_slug = character(),
    project_name = character(),
    task_type = character(),
    task_description = character(),
    approach_summary = character(),
    p_success = double(),
    confidence_bucket = character(),
    outcome = logical(),
    outcome_recorded_at = character(),
    outcome_notes = character()
  )
}

# ============================================================================
# READING
# ============================================================================

#' Read and reconcile predictions from JSONL
#'
#' Reads a project's prediction JSONL file and reconciles outcomes.
#' When multiple records share the same `prediction_id`, the latest
#' non-null outcome wins (allows appending outcome updates).
#'
#' @param project_slug Character project slug. If NULL, reads all files
#'   in `~/.claude/predictions/`.
#' @return Tibble of predictions with one row per unique prediction_id
#' @export
read_predictions <- function(project_slug = NULL) {
  if (is.null(project_slug)) {
    # Read all JSONL files
    pred_dir <- path.expand("~/.claude/predictions")
    if (!dir.exists(pred_dir)) return(empty_predictions_tibble())
    files <- list.files(pred_dir, pattern = "\\.jsonl$", full.names = TRUE)
    if (length(files) == 0) return(empty_predictions_tibble())
    preds <- lapply(files, read_single_jsonl)
    return(dplyr::bind_rows(preds))
  }

  jsonl_path <- prediction_jsonl_path(project_slug)
  read_single_jsonl(jsonl_path)
}

#' Read a single JSONL file and reconcile duplicates
#' @param path Path to JSONL file
#' @return Tibble
#' @noRd
read_single_jsonl <- function(path) {
  if (!file.exists(path)) return(empty_predictions_tibble())

  lines <- readLines(path, warn = FALSE)
  lines <- lines[nzchar(trimws(lines))]
  if (length(lines) == 0) return(empty_predictions_tibble())

  parsed <- lapply(lines, function(line) {
    tryCatch(jsonlite::fromJSON(line), error = function(e) NULL)
  })
  parsed <- Filter(Negate(is.null), parsed)
  if (length(parsed) == 0) return(empty_predictions_tibble())

  raw <- dplyr::bind_rows(parsed)

  # Ensure all expected columns exist
  expected <- names(empty_predictions_tibble())
  for (col in expected) {
    if (!col %in% names(raw)) {
      raw[[col]] <- NA
    }
  }

  # Reconcile: for duplicate prediction_ids, latest non-null outcome wins
  raw |>
    dplyr::arrange(recorded_at) |>
    dplyr::group_by(prediction_id) |>
    dplyr::summarise(
      recorded_at = dplyr::first(recorded_at),
      project_slug = dplyr::first(project_slug),
      project_name = dplyr::first(project_name),
      task_type = dplyr::first(task_type),
      task_description = dplyr::first(task_description),
      approach_summary = dplyr::first(approach_summary),
      p_success = dplyr::first(p_success),
      confidence_bucket = dplyr::first(confidence_bucket),
      outcome = dplyr::last(stats::na.omit(outcome)),
      outcome_recorded_at = dplyr::last(stats::na.omit(outcome_recorded_at)),
      outcome_notes = dplyr::last(stats::na.omit(outcome_notes)),
      .groups = "drop"
    )
}

# ============================================================================
# CALIBRATION
# ============================================================================

#' Compute calibration metrics for predictions
#'
#' @param predictions Tibble from `read_predictions()`
#' @return List with: brier_score, accuracy, calibration_by_bucket,
#'   rolling_brier, n_total, n_resolved
#' @export
compute_calibration <- function(predictions) {
  empty_result <- list(
    brier_score = NA_real_,
    accuracy = NA_real_,
    calibration_by_bucket = tibble::tibble(
      confidence_bucket = character(),
      n = integer(),
      mean_predicted = double(),
      mean_observed = double(),
      gap = double()
    ),
    rolling_brier = tibble::tibble(
      prediction_id = character(),
      recorded_at = character(),
      cumulative_brier = double()
    ),
    n_total = 0L,
    n_resolved = 0L
  )

  if (is.null(predictions) || nrow(predictions) == 0) return(empty_result)

  n_total <- nrow(predictions)

  # Only resolved predictions (outcome is TRUE/FALSE, not NA)
  resolved <- predictions |>
    dplyr::filter(!is.na(outcome))

  n_resolved <- nrow(resolved)
  if (n_resolved == 0) {
    empty_result$n_total <- n_total
    return(empty_result)
  }

  # Convert outcome: TRUE/partial -> 1, FALSE -> 0
  resolved <- resolved |>
    dplyr::mutate(
      outcome_binary = dplyr::case_when(
        outcome == TRUE ~ 1,
        outcome == "partial" ~ 1,
        TRUE ~ 0
      )
    )

  # Brier score: mean((p_i - o_i)^2)
  brier_score <- mean((resolved$p_success - resolved$outcome_binary)^2)

  # Accuracy at 0.5 threshold
  resolved <- resolved |>
    dplyr::mutate(predicted_success = p_success >= 0.5)
  accuracy <- mean(resolved$predicted_success == (resolved$outcome_binary == 1))

  # Calibration by confidence bucket
  calibration_by_bucket <- resolved |>
    dplyr::mutate(
      confidence_bucket = dplyr::case_when(
        p_success < 0.40 ~ "low",
        p_success <= 0.70 ~ "medium",
        TRUE ~ "high"
      )
    ) |>
    dplyr::group_by(confidence_bucket) |>
    dplyr::summarise(
      n = dplyr::n(),
      mean_predicted = mean(p_success),
      mean_observed = mean(outcome_binary),
      gap = mean(p_success) - mean(outcome_binary),
      .groups = "drop"
    )

  # Rolling Brier: cumulative Brier score over time
  rolling_brier <- resolved |>
    dplyr::arrange(recorded_at) |>
    dplyr::mutate(
      sq_error = (p_success - outcome_binary)^2,
      cumulative_brier = cumsum(sq_error) / dplyr::row_number()
    ) |>
    dplyr::select(prediction_id, recorded_at, cumulative_brier)

  list(
    brier_score = brier_score,
    accuracy = accuracy,
    calibration_by_bucket = calibration_by_bucket,
    rolling_brier = rolling_brier,
    n_total = n_total,
    n_resolved = n_resolved
  )
}

# ============================================================================
# DUCKDB STORAGE
# ============================================================================

#' Upsert predictions to DuckDB
#'
#' @param predictions Tibble from `read_predictions()`
#' @param db_path Path to DuckDB database file
#' @return Invisible number of rows stored
#' @noRd
store_predictions_duckdb <- function(predictions, db_path) {
  if (is.null(predictions) || nrow(predictions) == 0) return(invisible(0L))

  con <- DBI::dbConnect(duckdb::duckdb(), dbdir = db_path)
  on.exit(DBI::dbDisconnect(con, shutdown = TRUE))

  # Full replace strategy (JSONL is source of truth)
  if (DBI::dbExistsTable(con, "predictions")) {
    DBI::dbRemoveTable(con, "predictions")
  }
  DBI::dbWriteTable(con, "predictions", predictions)

  invisible(nrow(predictions))
}
