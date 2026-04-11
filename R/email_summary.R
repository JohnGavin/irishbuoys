#' Compute Data Coverage and Gaps
#'
#' @description
#' Computes temporal coverage and gap analysis for buoy stations.
#' Uses dplyr only (no raw SQL).
#'
#' @param con DBI connection to DuckDB database
#' @param start_date Start date for analysis
#' @param end_date End date for analysis
#'
#' @return List with `coverage` tibble and `gaps` tibble
#'
#' @export
compute_data_coverage <- function(con, start_date, end_date) {
  expected_hours <- as.integer(
    difftime(as.POSIXct(end_date), as.POSIXct(start_date), units = "hours")
  )

  # Hourly coverage per station
  # Collect first, then truncate to hour in R (clock/lubridate not available on DuckDB)
  coverage <- buoy_tbl(con) |>
    dplyr::filter(
      .data$time >= !!as.POSIXct(start_date, tz = "UTC"),
      .data$time < !!as.POSIXct(end_date, tz = "UTC")
    ) |>
    dplyr::collect() |>
    dplyr::mutate(
      hour = as.POSIXct(format(.data$time, "%Y-%m-%d %H:00:00"), tz = "UTC")
    ) |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      actual_hours = dplyr::n_distinct(.data$hour),
      n_records = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      expected_hours = expected_hours,
      coverage_pct = round(100 * .data$actual_hours / expected_hours, 1),
      missing_hours = expected_hours - .data$actual_hours
    )

  # Gap detection: gaps >= 6 hours
  # Collect first, then truncate to hour in R
  all_obs <- buoy_tbl(con) |>
    dplyr::filter(
      .data$time >= !!as.POSIXct(start_date, tz = "UTC"),
      .data$time < !!as.POSIXct(end_date, tz = "UTC")
    ) |>
    dplyr::collect() |>
    dplyr::mutate(
      hour = as.POSIXct(format(.data$time, "%Y-%m-%d %H:00:00"), tz = "UTC")
    ) |>
    dplyr::distinct(.data$station_id, .data$hour) |>
    dplyr::arrange(.data$station_id, .data$hour) |>
    dplyr::group_by(.data$station_id) |>
    dplyr::mutate(
      prev_hour = dplyr::lag(.data$hour),
      gap_hours = as.numeric(difftime(.data$hour, .data$prev_hour, units = "hours"))
    ) |>
    dplyr::ungroup()

  gaps <- all_obs |>
    dplyr::filter(.data$gap_hours >= 6) |>
    dplyr::transmute(
      .data$station_id,
      gap_start = .data$prev_hour,
      gap_end = .data$hour,
      gap_hours = .data$gap_hours
    )

  list(coverage = coverage, gaps = gaps)
}

#' Validate Email Data Freshness
#'
#' Checks that the latest observation timestamps in ingestion_stats
#' are within an acceptable window of the current time.
#'
#' @param ingestion_stats Tibble with `station_id` and `latest` columns
#' @param max_stale_hours Maximum acceptable age of data in hours (default: 96)
#'
#' @return ingestion_stats (invisibly), or aborts if ALL stations are stale
#' @examples
#' stats <- tibble::tibble(
#'   station_id = c("M2", "M3"),
#'   latest = Sys.time() - c(1, 2) * 3600
#' )
#' validate_email_freshness(stats)
#' @export
validate_email_freshness <- function(ingestion_stats, max_stale_hours = 96) {
  if (is.null(ingestion_stats) || nrow(ingestion_stats) == 0) {
    cli::cli_abort(c(
      "x" = "No ingestion statistics available.",
      "i" = "The database may be empty or the lookback window too narrow."
    ))
  }

  now <- Sys.time()
  stale <- ingestion_stats |>
    dplyr::mutate(
      age_hours = as.numeric(difftime(now, .data$latest, units = "hours"))
    ) |>
    dplyr::filter(.data$age_hours > max_stale_hours)

  if (nrow(stale) == nrow(ingestion_stats)) {
    cli::cli_abort(c(
      "x" = "ALL stations have stale data (> {max_stale_hours}h old).",
      "i" = "Oldest: {round(max(stale$age_hours, na.rm = TRUE), 1)} hours.",
      "i" = "Check that data_update target ran successfully before email generation."
    ))
  }

  if (nrow(stale) > 0) {
    cli::cli_warn(c(
      "!" = "{nrow(stale)}/{nrow(ingestion_stats)} stations have data > {max_stale_hours}h old.",
      "i" = "Stale stations: {paste(stale$station_id, collapse = ', ')}"
    ))
  }

  invisible(ingestion_stats)
}

#' Generate Weekly Summary Statistics
#'
#' @description
#' Compares recent data against historical averages to identify trends
#' and anomalies. Optionally includes data ingestion statistics.
#'
#' @param db_path Path to DuckDB database
#' @param lookback_days Number of days to analyze (default: 7)
#' @param qc_filter QC flag filter: 1 = good only, 0 = include unverified, NULL = no filter
#' @param update_result Optional result from incremental_update() containing ingestion stats
#'
#' @return List containing summary statistics and comparisons
#'
#' @export
generate_weekly_summary <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 7,
    qc_filter = NULL,
    update_result = NULL
) {

  con <- connect_duckdb(db_path = db_path)

  on.exit(DBI::dbDisconnect(con))

  current_date <- Sys.Date()
  start_date <- current_date - lookback_days

  # Helper: apply QC filter to a lazy table reference
  apply_qc <- function(tbl_ref, qc = qc_filter) {
    if (!is.null(qc)) {
      tbl_ref |> dplyr::filter(.data$qc_flag == !!qc)
    } else {
      tbl_ref |> dplyr::filter(.data$qc_flag != 9L)
    }
  }

  # Base filtered reference for the current week
  base_current <- buoy_tbl(con) |>
    dplyr::filter(
      .data$time >= !!as.POSIXct(start_date, tz = "UTC"),
      .data$time < !!as.POSIXct(current_date, tz = "UTC")
    ) |>
    apply_qc()

  # Current week statistics.
  # MANDATORY: start from canonical station list, left-join data.
  # Stations with zero recent observations must appear as NA / "offline".
  # See rule: never-drop-missing-stations.
  all_stations <- get_station_info()

  current_week_data <- base_current |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      avg_wave_height = mean(.data$wave_height, na.rm = TRUE),
      max_wave_height = max(.data$wave_height, na.rm = TRUE),
      avg_wind_speed = mean(.data$wind_speed, na.rm = TRUE),
      max_wind_speed = max(.data$wind_speed, na.rm = TRUE),
      avg_air_temp = mean(.data$air_temperature, na.rm = TRUE),
      avg_sea_temp = mean(.data$sea_temperature, na.rm = TRUE),
      n_observations = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::collect()

  current_week <- all_stations |>
    dplyr::select("station_id") |>
    dplyr::left_join(current_week_data, by = "station_id") |>
    dplyr::mutate(
      n_observations = tidyr::replace_na(n_observations, 0L),
      status = dplyr::if_else(n_observations == 0L, "offline", "reporting")
    )

  # Previous week comparison
  prev_week <- buoy_tbl(con) |>
    dplyr::filter(
      .data$time >= !!as.POSIXct(start_date - 7, tz = "UTC"),
      .data$time < !!as.POSIXct(start_date, tz = "UTC")
    ) |>
    apply_qc() |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      avg_wave_height = mean(.data$wave_height, na.rm = TRUE),
      max_wave_height = max(.data$wave_height, na.rm = TRUE),
      avg_wind_speed = mean(.data$wind_speed, na.rm = TRUE),
      max_wind_speed = max(.data$wind_speed, na.rm = TRUE),
      avg_air_temp = mean(.data$air_temperature, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::collect()

  # Historical averages for this time of year
  # Collect historical data, then filter by ISO week in R
  current_week_num <- as.integer(format(current_date, "%W"))
  historical <- buoy_tbl(con) |>
    dplyr::filter(.data$time < !!as.POSIXct(start_date, tz = "UTC")) |>
    apply_qc() |>
    dplyr::collect() |>
    dplyr::mutate(week_num = as.integer(format(.data$time, "%W"))) |>
    dplyr::filter(.data$week_num == !!current_week_num) |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      hist_avg_wave_height = mean(.data$wave_height, na.rm = TRUE),
      p95_wave_height = stats::quantile(.data$wave_height, 0.95, na.rm = TRUE),
      hist_avg_wind_speed = mean(.data$wind_speed, na.rm = TRUE),
      p95_wind_speed = stats::quantile(.data$wind_speed, 0.95, na.rm = TRUE),
      hist_avg_air_temp = mean(.data$air_temperature, na.rm = TRUE),
      hist_avg_sea_temp = mean(.data$sea_temperature, na.rm = TRUE),
      .groups = "drop"
    )

  # Check for extreme events — three separate dplyr queries bound together
  high_waves <- base_current |>
    dplyr::filter(.data$wave_height > 8) |>
    dplyr::transmute(
      station_id = .data$station_id,
      time = .data$time,
      event_type = "High Waves",
      value = .data$wave_height
    ) |>
    dplyr::collect()

  storm_winds <- base_current |>
    dplyr::filter(.data$wind_speed > 48) |>
    dplyr::transmute(
      station_id = .data$station_id,
      time = .data$time,
      event_type = "Storm Winds",
      value = .data$wind_speed
    ) |>
    dplyr::collect()

  rogue_waves <- base_current |>
    dplyr::filter(
      .data$hmax > 2 * .data$wave_height,
      .data$wave_height > 2
    ) |>
    dplyr::transmute(
      station_id = .data$station_id,
      time = .data$time,
      event_type = "Rogue Wave",
      value = .data$hmax
    ) |>
    dplyr::collect()

  extremes <- dplyr::bind_rows(high_waves, storm_winds, rogue_waves) |>
    dplyr::arrange(dplyr::desc(.data$time))

  # Ingestion stats: new records per station this week.
  # MANDATORY: canonical station list first, left-join data.
  report_composed <- Sys.time()
  ingestion_data <- buoy_tbl(con) |>
    dplyr::filter(
      .data$time >= !!as.POSIXct(start_date, tz = "UTC"),
      .data$time < !!as.POSIXct(current_date, tz = "UTC")
    ) |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      new_records = dplyr::n(),
      earliest = min(.data$time, na.rm = TRUE),
      latest = max(.data$time, na.rm = TRUE),
      .groups = "drop"
    ) |>
    dplyr::collect()

  ingestion_stats <- all_stations |>
    dplyr::select("station_id") |>
    dplyr::left_join(ingestion_data, by = "station_id") |>
    dplyr::mutate(
      new_records = tidyr::replace_na(new_records, 0L),
      report_composed = report_composed,
      staleness_hours = dplyr::if_else(
        is.na(.data$latest),
        Inf,  # no data = infinitely stale
        round(as.numeric(difftime(report_composed, .data$latest, units = "hours")), 1)
      ),
      staleness_alert = .data$staleness_hours > 18,
      status = dplyr::if_else(new_records == 0L, "offline", "reporting")
    ) |>
    dplyr::arrange(.data$station_id)

  # Validate freshness when data exists (abort if ALL stations stale, warn if some)
  if (nrow(ingestion_stats) > 0) {
    validate_email_freshness(ingestion_stats, max_stale_hours = 96)
  } else {
    cli::cli_warn(c(
      "!" = "No ingestion data found in lookback window.",
      "i" = "Email may contain stale data. Check that the database has recent records."
    ))
  }

  # Database totals
  db_stats <- tryCatch(
    get_database_stats(con),
    error = function(e) NULL
  )

  # Data coverage analysis
  data_coverage <- tryCatch(
    compute_data_coverage(con, start_date, current_date),
    error = function(e) {
      cli::cli_warn("Failed to compute data coverage: {e$message}")
      NULL
    }
  )

  # Combine results
  summary <- list(
    current_week = current_week,
    previous_week = prev_week,
    historical = historical,
    extreme_events = extremes,
    ingestion_stats = ingestion_stats,
    data_coverage = data_coverage,
    db_stats = db_stats,
    update_result = update_result,
    report_date = current_date,
    period = list(start = start_date, end = current_date - 1)
  )

  # Calculate changes
  if (nrow(current_week) > 0 && nrow(prev_week) > 0) {
    comparison <- merge(current_week, prev_week,
                       by = "station_id", suffixes = c("_current", "_prev"))

    comparison$wave_change_pct <- round(
      100 * (comparison$avg_wave_height_current - comparison$avg_wave_height_prev) /
        comparison$avg_wave_height_prev, 1)

    comparison$wind_change_pct <- round(
      100 * (comparison$avg_wind_speed_current - comparison$avg_wind_speed_prev) /
        comparison$avg_wind_speed_prev, 1)

    summary$week_over_week <- comparison
  }

  return(summary)
}

#' Create HTML Email Summary
#'
#' @description
#' Formats the weekly summary as an HTML email using blastula.
#'
#' @param summary Summary object from generate_weekly_summary()
#'
#' @return blastula email object
#'
#' @export
create_email_summary <- function(summary) {

  # Format extreme events table (top half, reverse time order)
  extreme_text <- if (nrow(summary$extreme_events) > 0) {
    evt <- summary$extreme_events
    evt <- evt[order(evt$time, decreasing = TRUE), ]
    evt <- utils::head(evt, ceiling(nrow(evt) / 2))
    evt_rows <- paste(vapply(seq_len(nrow(evt)), function(i) {
      row <- evt[i, ]
      val <- tryCatch(
        round(as.numeric(row$value), 1),
        warning = function(w) row$value
      )
      paste0(
        "<tr><td>", row$station_id, "</td>",
        "<td>", row$time, "</td>",
        "<td>", row$event_type, "</td>",
        "<td>", val, "</td></tr>"
      )
    }, character(1)), collapse = "")

    paste0(
      "<h3>Rogue and high waves (last week, reverse time order)</h3>",
      "<table border='1' style='border-collapse: collapse;'>",
      "<tr><th>Station</th><th>Time</th><th>Event</th><th>Value</th></tr>",
      evt_rows,
      "</table>"
    )
  } else {
    "<p>No extreme events detected this week.</p>"
  }

  # Format station statistics — join with coverage for missing_hours, sort desc
  stats_df <- summary$current_week
  if (!is.null(summary$data_coverage) &&
      "coverage" %in% names(summary$data_coverage)) {
    cov_df <- summary$data_coverage$coverage[, c("station_id", "missing_hours")]
    stats_df <- merge(stats_df, cov_df, by = "station_id", all.x = TRUE)
    stats_df <- stats_df[order(-stats_df$missing_hours, -stats_df$max_wave_height), ]
  } else if (nrow(stats_df) > 0) {
    stats_df$missing_hours <- NA_real_
  }

  station_stats <- if (nrow(stats_df) == 0) {
    "<p>No station data available this week.</p>"
  } else {
    paste(apply(stats_df, 1, function(row) {
    missing_li <- if (!is.na(row["missing_hours"])) {
      mh <- as.numeric(row["missing_hours"])
      mh_style <- if (mh > 150) {
        "color:#dc3545;font-size:1.4em;font-weight:bold;"
      } else if (mh > 100) {
        "color:#dc3545;font-size:1.2em;font-weight:bold;"
      } else if (mh > 50) {
        "color:#ff8800;font-size:1.1em;font-weight:bold;"
      } else if (mh > 0) {
        "color:#ffc107;font-weight:bold;"
      } else {
        "color:#28a745;"
      }
      paste0("<li style='", mh_style, "'>Missing Hours: ", row["missing_hours"], "</li>")
    } else {
      ""
    }
    paste0(
      "<h3>Station ", row["station_id"], "</h3>",
      "<ul>",
      missing_li,
      "<li>Observations: ", row["n_observations"], "</li>",
      "<li>Maximum Wave Height: ", round(as.numeric(row["max_wave_height"]), 2), " m</li>",
      "<li>Average Wave Height: ", round(as.numeric(row["avg_wave_height"]), 2), " m</li>",
      "<li>Average Wind Speed: ", round(as.numeric(row["avg_wind_speed"]), 1), " knots</li>",
      "<li>Air Temperature: ", round(as.numeric(row["avg_air_temp"]), 1), " C</li>",
      "<li>Sea Temperature: ", round(as.numeric(row["avg_sea_temp"]), 1), " C</li>",
      "</ul>"
    )
  }), collapse = "")
  }

  # Format ingestion stats table with staleness
  ingestion_text <- if (!is.null(summary$ingestion_stats) && nrow(summary$ingestion_stats) > 0) {
    ing <- summary$ingestion_stats
    ing_rows <- paste(vapply(seq_len(nrow(ing)), function(i) {
      row <- ing[i, ]
      stale_color <- if (isTRUE(row$staleness_alert)) "#dc3545" else "#28a745"
      stale_label <- if (isTRUE(row$staleness_alert)) {
        paste0("<strong style='color:", stale_color, "'>", row$staleness_hours, "h STALE</strong>")
      } else {
        paste0("<span style='color:", stale_color, "'>", row$staleness_hours, "h</span>")
      }
      paste0(
        "<tr><td>", row$station_id, "</td>",
        "<td>", format(row$new_records, big.mark = ","), "</td>",
        "<td>", format(row$earliest, "%Y-%m-%d %H:%M"), "</td>",
        "<td>", format(row$latest, "%Y-%m-%d %H:%M"), "</td>",
        "<td>", stale_label, "</td></tr>"
      )
    }, character(1)), collapse = "")

    composed_ts <- format(ing$report_composed[1], "%Y-%m-%d %H:%M:%S %Z")
    paste0(
      "<p><small>Report composed: <strong>", composed_ts, "</strong>. ",
      "Staleness = hours since latest observation. ",
      "<span style='color:#dc3545'>Alert</span> if &gt; 18h.</small></p>",
      "<table border='1' style='border-collapse: collapse;'>",
      "<tr><th>Station</th><th>New Records</th><th>Earliest</th>",
      "<th>Latest</th><th>Staleness</th></tr>",
      ing_rows,
      "</table>"
    )
  } else {
    "<p>No new records ingested.</p>"
  }

  # Format database totals
  db_totals_text <- if (!is.null(summary$db_stats)) {
    stats <- summary$db_stats
    paste0(
      "<p><strong>Dataset Totals:</strong> ",
      format(stats$total_records, big.mark = ","), " records, ",
      round(stats$db_size_mb, 1), " MB</p>"
    )
  } else {
    ""
  }

  # Format data coverage section
  coverage_text <- if (!is.null(summary$data_coverage)) {
    cov <- summary$data_coverage$coverage
    gaps <- summary$data_coverage$gaps

    # Coverage table with color coding
    cov_rows <- paste(vapply(seq_len(nrow(cov)), function(i) {
      row <- cov[i, ]
      color <- if (row$coverage_pct >= 90) "#28a745"
               else if (row$coverage_pct >= 80) "#ffc107"
               else "#dc3545"
      paste0(
        "<tr><td>", row$station_id, "</td>",
        "<td>", row$expected_hours, "</td>",
        "<td>", row$actual_hours, "</td>",
        "<td style='color:", color, "; font-weight:bold'>", row$coverage_pct, "%</td>",
        "<td>", row$missing_hours, "</td></tr>"
      )
    }, character(1)), collapse = "")

    cov_table <- paste0(
      "<p><small>Coverage = distinct hours with observations / expected ",
      "<a href='https://en.wikipedia.org/wiki/Hourly'>hourly</a> observations. ",
      "Source: <a href='https://erddap.marine.ie/'>Marine Institute ERDDAP</a></small></p>",
      "<table border='1' style='border-collapse: collapse;'>",
      "<tr><th>Station</th><th>Expected Hours</th><th>Actual Hours</th>",
      "<th>Coverage</th><th>Missing Hours</th></tr>",
      cov_rows,
      "</table>"
    )

    # Gaps sub-table
    gaps_table <- if (nrow(gaps) > 0) {
      gap_rows <- paste(vapply(seq_len(nrow(gaps)), function(i) {
        row <- gaps[i, ]
        paste0(
          "<tr><td>", row$station_id, "</td>",
          "<td>", row$gap_start, "</td>",
          "<td>", row$gap_end, "</td>",
          "<td>", row$gap_hours, "h</td></tr>"
        )
      }, character(1)), collapse = "")

      paste0(
        "<h3>Significant Gaps (&ge; 6 hours)</h3>",
        "<table border='1' style='border-collapse: collapse;'>",
        "<tr><th>Station</th><th>Gap Start</th><th>Gap End</th><th>Duration</th></tr>",
        gap_rows,
        "</table>"
      )
    } else {
      "<p>No significant gaps (&ge; 6 hours) detected.</p>"
    }

    paste0(cov_table, gaps_table)
  } else {
    ""
  }

  # Create email body
  email_body <- paste0(
    "<div style='font-size:18px;'>",
    "<h1>Irish Weather Buoy Network - Weekly Summary</h1>",
    "<p><strong>Report Period:</strong> ",
    summary$period$start, " to ", summary$period$end, "</p>",

    "<details open>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>Data Ingestion This Week</summary>",
    ingestion_text,
    db_totals_text,
    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>Data Coverage &amp; Gaps</summary>",
    coverage_text,
    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>Week-over-Week Changes</summary>",
    if (!is.null(summary$week_over_week)) {
      paste0(
        "<table border='1' style='border-collapse: collapse;'>",
        "<tr><th>Station</th><th>Wave Height Change</th><th>Wind Speed Change</th></tr>",
        paste(apply(summary$week_over_week[, c("station_id", "wave_change_pct", "wind_change_pct")], 1,
          function(row) {
            wave_color <- if(as.numeric(row[2]) > 0) "red" else "green"
            wind_color <- if(as.numeric(row[3]) > 0) "red" else "green"
            paste0(
              "<tr><td>", row[1], "</td>",
              "<td style='color:", wave_color, "'>", row[2], "%</td>",
              "<td style='color:", wind_color, "'>", row[3], "%</td></tr>"
            )
          }), collapse = ""),
        "</table>"
      )
    } else {
      "<p>Previous week data not available for comparison.</p>"
    },

    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>Rogue &amp; High Waves</summary>",
    extreme_text,
    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>Station Statistics</summary>",
    station_stats,
    "</details>",

    "</div>",
    "<hr>",
    "<p><small>Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), " by the ",
    "<a href='https://johngavin.github.io/irishbuoys/'>irishbuoys</a> R package ",
    "(<a href='https://github.com/JohnGavin/irishbuoys'>source on GitHub</a>).</small></p>",
    "<p><small>Data source: <a href='https://erddap.marine.ie/'>Marine Institute ERDDAP Server</a></small></p>",
    "<p><small><em>Disclaimer: irishbuoys is an independent open-source project. ",
    "It is not affiliated with, endorsed by, or part of the Marine Institute ",
    "or the Irish Weather Buoy Network.</em></small></p>"
  )

  # Create email using blastula
  email <- blastula::compose_email(
    body = blastula::md(email_body),
    footer = blastula::md(paste0(
      "Automated report from the ",
      "[irishbuoys](https://johngavin.github.io/irishbuoys/) R package ",
      "([GitHub](https://github.com/JohnGavin/irishbuoys)). ",
      "This is an independent open-source project, not affiliated with the Marine Institute ",
      "or the Irish Weather Buoy Network."
    ))
  )

  return(email)
}

#' Generate and Send Summary Email
#'
#' @description
#' Main function to generate summary and send via email.
#' Requires GMAIL_USERNAME and GMAIL_APP_PASSWORD environment variables.
#'
#' @param recipient Email recipient (default from GMAIL_USERNAME env var)
#' @param sender Email sender (default from GMAIL_USERNAME env var)
#'
#' @export
generate_and_send_summary <- function(
    recipient = Sys.getenv("GMAIL_USERNAME"),
    sender = Sys.getenv("GMAIL_USERNAME")
) {

  cli::cli_h1("Generating Weekly Summary")

  # Generate summary
  summary <- generate_weekly_summary()

  # Create email
  email <- create_email_summary(summary)

  # Add subject line
  subject <- paste0(
    "Irish Buoy Network Weekly Report - ",
    format(Sys.Date(), "%B %d, %Y")
  )

  # Check if we have Gmail credentials
  gmail_user <- Sys.getenv("GMAIL_USERNAME")
  gmail_pass <- Sys.getenv("GMAIL_APP_PASSWORD")

  if (nzchar(gmail_user) && nzchar(gmail_pass)) {
    cli::cli_alert_info("Sending email to {recipient}")

    # Create SMTP credentials for Gmail
    creds <- blastula::creds_envvar(
      user = gmail_user,
      pass_envvar = "GMAIL_APP_PASSWORD",
      host = "smtp.gmail.com",
      port = 465,
      use_ssl = TRUE
    )

    # Send email
    tryCatch({
      blastula::smtp_send(
        email = email,
        to = recipient,
        from = sender,
        subject = subject,
        credentials = creds
      )
      cli::cli_alert_success("Email sent successfully")
    }, error = function(e) {
      cli::cli_alert_danger("Failed to send email: {e$message}")
      # Save email to file as backup
      html_file <- file.path(tempdir(), paste0("email_summary_", Sys.Date(), ".html"))
      writeLines(as.character(email), html_file)
      cli::cli_alert_info("Email saved to {html_file}")
    })
  } else {
    cli::cli_alert_warning("Gmail credentials not configured (set GMAIL_USERNAME and GMAIL_APP_PASSWORD)")
    # Save to file instead
    html_file <- file.path(tempdir(), paste0("email_summary_", Sys.Date(), ".html"))
    writeLines(as.character(email), html_file)
    cli::cli_alert_info("Summary saved to {html_file}")
  }

  return(invisible(summary))
}