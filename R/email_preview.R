#' Dev helpers for previewing the weekly email locally
#'
#' These helpers back `inst/scripts/preview_weekly_email.R`. They render the
#' weekly email to a local HTML file and never send anything. They reuse
#' [validate_email_freshness()] unchanged: there is deliberately no bypass.
#'
#' Why they exist: `inst/extdata/irish_buoys.duckdb` is git-ignored, so a
#' `git pull` never refreshes it and a local copy silently goes stale. The
#' committed `dashboard_buoy_data.rds` is fresh but has no `qc_flag` column,
#' which `generate_weekly_summary()` filters on, so it cannot stand in for the
#' database. The honest source is the public ERDDAP (Environmental Research
#' Division's Data Access Program) service, fetched with the project's own
#' `incremental_update()` into a temporary database.
#'
#' @name email_preview
#' @keywords internal
#' @noRd
NULL

# Path of the real (git-ignored) project database; previews must never write it.
email_preview_real_db <- function() "inst/extdata/irish_buoys.duckdb"

#' Latest observation timestamp per canonical station
#'
#' @param db_path Path to an existing DuckDB database.
#' @return Tibble with `station_id`, `latest` (POSIXct UTC or NA) and `age_hours`.
#' @noRd
email_preview_latest <- function(db_path) {
  if (!is.character(db_path) || length(db_path) != 1L || is.na(db_path) ||
      !nzchar(db_path) || !file.exists(db_path)) {
    cli::cli_abort(c(
      "x" = "Database not found: {.file {db_path}}",
      "i" = "Pass an existing DuckDB file, or let the script fetch a temporary one."
    ))
  }
  con <- connect_duckdb(db_path = db_path)
  on.exit(DBI::dbDisconnect(con), add = TRUE)

  per_station <- buoy_tbl(con) |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(latest = max(.data$time, na.rm = TRUE), .groups = "drop") |>
    dplyr::collect()

  out <- tibble::as_tibble(get_station_info()["station_id"]) |>
    dplyr::left_join(per_station, by = "station_id")
  out$latest <- as.POSIXct(out$latest, tz = "UTC")
  out$age_hours <- round(
    as.numeric(difftime(Sys.time(), out$latest, units = "hours")), 1
  )
  out
}

#' Refuse to preview stale data
#'
#' Calls the unmodified [validate_email_freshness()] with its own default
#' threshold (read from its signature, so there is one home for the number).
#' Stations with no observations at all are dropped before the call because
#' the guard ignores `NA` ages; if that leaves nothing, that is refused here.
#'
#' @param stats Output of [email_preview_latest()].
#' @return `stats` invisibly; aborts if the data is too old.
#' @noRd
email_preview_check_fresh <- function(stats) {
  threshold <- formals(validate_email_freshness)$max_stale_hours
  reporting <- stats[!is.na(stats$latest), c("station_id", "latest")]
  if (nrow(reporting) == 0L) {
    cli::cli_abort(c(
      "x" = "Refusing to render: no station has any observation.",
      "i" = "The database is empty."
    ))
  }
  validate_email_freshness(reporting, max_stale_hours = threshold)
  invisible(stats)
}

#' Fetch the last few days from ERDDAP into a temporary database
#'
#' Uses the project's `incremental_update()` (read-only HTTP GETs) against a
#' fresh database under the session temp dir. Refuses to touch the real
#' project database.
#'
#' @param days Number of days to fetch (default 21: current week, previous
#'   week and a margin).
#' @param db_path Where to build the database (default: a temp file).
#' @return The path of the temporary database.
#' @noRd
email_preview_fetch_recent <- function(
    days = 21,
    db_path = file.path(tempfile("irishbuoys_preview_"), "preview.duckdb")
) {
  same <- identical(
    normalizePath(db_path, mustWork = FALSE),
    normalizePath(email_preview_real_db(), mustWork = FALSE)
  )
  if (same) {
    cli::cli_abort("Refusing to write the real project database {.file {db_path}}.")
  }
  con <- connect_duckdb(db_path = db_path, create_new = TRUE)
  DBI::dbDisconnect(con)

  res <- incremental_update(db_path = db_path, lookback_hours = days * 24)
  if (identical(res$status, "error")) {
    cli::cli_abort(c(
      "x" = "ERDDAP fetch failed: {res$error}",
      "i" = "No preview was rendered."
    ))
  }
  db_path
}

#' Render the weekly email to a local HTML file
#'
#' Prints the latest timestamp per station and its age, refuses when the data
#' is stale, otherwise writes the HTML and prints its path. Never sends email.
#'
#' @param db_path Existing DuckDB database to read.
#' @param out_file Output HTML path.
#' @return `out_file` invisibly.
#' @noRd
render_weekly_email_preview <- function(
    db_path,
    out_file = file.path(
      dirname(tempdir()),
      paste0("irishbuoys_weekly_email_preview_", format(Sys.Date()), ".html")
    )
) {
  stats <- email_preview_latest(db_path)

  cat("Latest observation per station (UTC) and age:\n")
  for (i in seq_len(nrow(stats))) {
    if (is.na(stats$latest[i])) {
      cat(sprintf("  %-3s latest: none (no observations)\n", stats$station_id[i]))
    } else {
      cat(sprintf(
        "  %-3s latest: %s  age: %.1f h\n",
        stats$station_id[i],
        format(stats$latest[i], "%Y-%m-%d %H:%M", tz = "UTC"),
        stats$age_hours[i]
      ))
    }
  }

  email_preview_check_fresh(stats)

  summary <- generate_weekly_summary(db_path = db_path)
  email <- create_email_summary(summary)
  writeLines(as.character(email), out_file)

  cat("Preview written to: ", out_file, "\n", sep = "")
  invisible(out_file)
}
