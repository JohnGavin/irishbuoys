# ---- Weekly email: single homes for thresholds, units, caps and links ------
# Every number or URL used in the email text is derived from these objects;
# the event queries in generate_weekly_summary() use the same thresholds.

# Event rules. Units: Hs and Hmax in metres ("m"), wind speed in knots ("kn");
# these agree with get_data_dictionary() (checked in tests).
.email_rules <- list(
  high_waves = list(event_type = "High Waves", threshold = 8, unit = "m"),
  storm_winds = list(event_type = "Storm Winds", threshold = 48, unit = "kn"),
  rogue_wave = list(
    event_type = "Rogue Wave", ratio = 2, min_hs = 2, unit = "m"
  )
)

# Maximum events shown per event table (the email says when rows are cut).
.email_max_events_per_table <- 20L

# Dashboard base URL and the page/anchor each email section links to.
.dashboard_base_url <- "https://johngavin.github.io/irishbuoys/"
.dashboard_targets <- list(
  # Page-level anchors of the Irish Buoys Explorer dashboard.
  high_waves = list(page = "dashboard_static", anchor = "signif-wave-m"),
  storm_winds = list(page = "dashboard_static", anchor = "wind-speed-kn"),
  rogue_wave = list(page = "dashboard_static", anchor = "data"),
  station_stats = list(page = "dashboard_static", anchor = "max-wave-m"),
  definitions = list(page = "dashboard_static", anchor = "reference"),
  # Pipeline-metrics page sections (full history, not last week only).
  ingestion = list(page = "telemetry", anchor = "key-metrics"),
  coverage = list(page = "telemetry", anchor = "data-coverage")
)

#' Build a dashboard URL for an email section
#'
#' @param key Name in `.dashboard_targets`.
#' @return A single URL string.
#' @noRd
email_dashboard_url <- function(key) {
  target <- .dashboard_targets[[key]]
  if (is.null(target)) {
    cli::cli_abort(c(
      "x" = "Unknown dashboard target {.val {key}}.",
      "i" = "Known targets: {.val {names(.dashboard_targets)}}."
    ))
  }
  paste0(
    .dashboard_base_url, "articles/", target$page, ".html#", target$anchor
  )
}

#' HTML anchor to a dashboard target
#' @noRd
email_link <- function(text, key) {
  paste0("<a href='", email_dashboard_url(key), "'>", text, "</a>")
}

#' Coerce event times to POSIXct (UTC); unparsable values become NA
#' @noRd
email_parse_time <- function(x) {
  if (inherits(x, "POSIXt")) {
    as.POSIXct(x)
  } else if (inherits(x, "Date")) {
    as.POSIXct(x)
  } else if (is.character(x)) {
    as.POSIXct(x, tz = "UTC", optional = TRUE)
  } else {
    as.POSIXct(rep(NA_real_, length(x)), tz = "UTC")
  }
}

#' Full timestamp with timezone, e.g. "2026-10-22 00:00:00 UTC"
#' @noRd
email_format_time <- function(t) {
  out <- paste(format(t, "%Y-%m-%d %H:%M:%S", tz = "UTC"), "UTC")
  out[is.na(t)] <- "time unknown"
  out
}

#' Format a numeric column to fixed decimals; non-finite becomes "n/a"
#' @noRd
email_format_num <- function(x, digits = 1L) {
  if (!is.numeric(x)) {
    return(rep("n/a", length(x)))
  }
  out <- formatC(x, format = "f", digits = digits)
  out[!is.finite(x)] <- "n/a"
  out
}

#' HTML table of one event type (newest first, capped, never silent)
#'
#' @param evt Events data frame with station_id, time, event_type, value, hs.
#' @param type_key Name in `.email_rules`.
#' @return HTML string: heading, rule text, count line, table.
#' @noRd
email_event_table <- function(evt, type_key, max_rows = .email_max_events_per_table) {
  rule <- .email_rules[[type_key]]
  defs <- "definitions"
  th <- function(text) paste0("<th>", email_link(text, defs), "</th>")

  for (col in c("station_id", "time", "event_type", "value", "hs")) {
    if (!col %in% names(evt)) {
      evt[[col]] <- if (col %in% c("value", "hs")) NA_real_ else NA_character_
    }
  }
  sub <- evt[!is.na(evt$event_type) & evt$event_type == rule$event_type, ,
             drop = FALSE]
  sub$time_utc <- email_parse_time(sub$time)
  sub <- sub[order(sub$time_utc, decreasing = TRUE, na.last = TRUE), ,
             drop = FALSE]
  n_total <- nrow(sub)
  shown <- utils::head(sub, max_rows)
  n_shown <- nrow(shown)

  time_txt <- email_format_time(shown$time_utc)
  val_txt <- email_format_num(shown$value)
  hs_txt <- email_format_num(shown$hs)

  heading_label <- switch(
    type_key,
    high_waves = "High Waves",
    storm_winds = "Storm Winds",
    rogue_wave = "Rogue Waves"
  )
  rule_text <- switch(
    type_key,
    high_waves = paste0(
      "Rule: significant wave height (Hs, the mean height of the highest ",
      "third of waves) above ", rule$threshold, " ", rule$unit, "."
    ),
    storm_winds = paste0(
      "Rule: wind speed above ", rule$threshold, " ", rule$unit,
      " (kn = knots, nautical miles per hour)."
    ),
    rogue_wave = paste0(
      "Rule: maximum wave height (Hmax, the single highest wave in the ",
      "measurement period) more than ", rule$ratio, " times the Hs, and Hs ",
      "above ", rule$min_hs, " ", rule$unit, "."
    )
  )

  count_txt <- if (n_total == 0L) {
    "None this week."
  } else if (n_total > n_shown) {
    paste0(
      "Showing the newest ", n_shown, " of ", n_total,
      " events (each event is one hourly observation); ",
      email_link("see the dashboard section", type_key),
      " (it covers the full history, not only last week)."
    )
  } else {
    paste0("Showing all ", n_total, " events (newest first).")
  }

  header <- switch(
    type_key,
    high_waves = paste0(
      "<tr><th>Station</th><th>Time (UTC)</th>",
      th(paste0("Significant wave height Hs (", rule$unit, ")")), "</tr>"
    ),
    storm_winds = paste0(
      "<tr><th>Station</th><th>Time (UTC)</th>",
      th(paste0("Wind speed (", rule$unit, ")")), "</tr>"
    ),
    rogue_wave = paste0(
      "<tr><th>Station</th><th>Time (UTC)</th>",
      th(paste0("Maximum wave height Hmax (", rule$unit, ")")),
      th(paste0("Significant wave height Hs (", rule$unit, ")")),
      th("Ratio Hmax/Hs"), "</tr>"
    )
  )

  body <- if (n_shown == 0L) {
    ""
  } else {
    ratio_txt <- if (is.numeric(shown$value) && is.numeric(shown$hs)) {
      email_format_num(shown$value / shown$hs)
    } else {
      rep("n/a", n_shown)
    }
    paste(vapply(seq_len(n_shown), function(i) {
      cells <- switch(
        type_key,
        rogue_wave = paste0(
          "<td>", val_txt[i], "</td><td>", hs_txt[i], "</td><td>",
          ratio_txt[i], "</td>"
        ),
        paste0("<td>", val_txt[i], "</td>")
      )
      paste0(
        "<tr><td>", shown$station_id[i], "</td><td>", time_txt[i], "</td>",
        cells, "</tr>"
      )
    }, character(1)), collapse = "")
  }

  paste0(
    "<h4>", email_link(heading_label, type_key), "</h4>",
    "<p><small>", rule_text, "</small></p>",
    "<p>", count_txt, "</p>",
    if (n_shown > 0L) {
      paste0(
        "<table border='1' style='border-collapse: collapse;'>",
        header, body, "</table>"
      )
    } else {
      ""
    }
  )
}

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
  if (is.na(expected_hours) || expected_hours < 1L) {
    cli::cli_abort(c(
      "x" = "Invalid coverage window: expected_hours = {expected_hours}",
      "i" = "start_date = {start_date}, end_date = {end_date}"
    ))
  }

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

  # Include ALL canonical stations (offline stations show 0% coverage)
  all_stations <- get_station_info()
  coverage <- all_stations |>
    dplyr::select("station_id") |>
    dplyr::left_join(coverage, by = "station_id") |>
    dplyr::mutate(
      actual_hours = tidyr::replace_na(.data$actual_hours, 0L),
      n_records = tidyr::replace_na(.data$n_records, 0L),
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
  # Thresholds and event labels come from `.email_rules` (one home); the
  # email text is built from the same constants. `value` is the single
  # measure of the event type; `hs` is the significant wave height each
  # event was judged against (rogue waves need it to be interpretable).
  hw_threshold <- .email_rules$high_waves$threshold
  sw_threshold <- .email_rules$storm_winds$threshold
  rogue_ratio <- .email_rules$rogue_wave$ratio
  rogue_min_hs <- .email_rules$rogue_wave$min_hs

  high_waves <- base_current |>
    dplyr::filter(.data$wave_height > !!hw_threshold) |>
    dplyr::transmute(
      station_id = .data$station_id,
      time = .data$time,
      event_type = !!.email_rules$high_waves$event_type,
      value = .data$wave_height,
      hs = .data$wave_height
    ) |>
    dplyr::collect()

  storm_winds <- base_current |>
    dplyr::filter(.data$wind_speed > !!sw_threshold) |>
    dplyr::transmute(
      station_id = .data$station_id,
      time = .data$time,
      event_type = !!.email_rules$storm_winds$event_type,
      value = .data$wind_speed,
      hs = .data$wave_height
    ) |>
    dplyr::collect()

  rogue_waves <- base_current |>
    dplyr::filter(
      .data$hmax > (!!rogue_ratio) * .data$wave_height,
      .data$wave_height > !!rogue_min_hs
    ) |>
    dplyr::transmute(
      station_id = .data$station_id,
      time = .data$time,
      event_type = !!.email_rules$rogue_wave$event_type,
      value = .data$hmax,
      hs = .data$wave_height
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

  # Extreme events: one table per event type, each column a single measure
  # with its unit in the header. Newest first, capped at
  # .email_max_events_per_table per table with an explicit "N of M" line.
  extreme_text <- if (nrow(summary$extreme_events) > 0) {
    evt <- summary$extreme_events
    known <- vapply(.email_rules, function(r) r$event_type, character(1))
    n_other <- sum(is.na(evt$event_type) | !evt$event_type %in% known)
    other_note <- if (n_other > 0) {
      paste0(
        "<p><small>", n_other, " event(s) of an unrecognised type are not ",
        "shown.</small></p>"
      )
    } else {
      ""
    }
    paste0(
      "<p>Events from the last week, newest first. Times are in UTC ",
      "(Coordinated Universal Time). Column headings link to their ",
      "definitions on the dashboard.</p>",
      email_event_table(evt, "high_waves"),
      email_event_table(evt, "storm_winds"),
      email_event_table(evt, "rogue_wave"),
      other_note
    )
  } else {
    paste0(
      "<p>No extreme events detected this week (High Waves: significant ",
      "wave height, Hs, above ", .email_rules$high_waves$threshold, " ",
      .email_rules$high_waves$unit, "; Storm Winds: wind speed above ",
      .email_rules$storm_winds$threshold, " ", .email_rules$storm_winds$unit,
      " (kn = knots); Rogue Wave: maximum wave height, Hmax, more than ",
      .email_rules$rogue_wave$ratio, " times Hs and Hs above ",
      .email_rules$rogue_wave$min_hs, " ", .email_rules$rogue_wave$unit,
      ").</p>"
    )
  }

  # Format station statistics — join with coverage for missing_hours, sort desc
  stats_df <- summary$current_week
  if (!is.null(summary$data_coverage) &&
      "coverage" %in% names(summary$data_coverage)) {
    cov_df <- summary$data_coverage$coverage[, c("station_id", "missing_hours")]
    stats_df <- merge(stats_df, cov_df, by = "station_id", all.x = TRUE)
    # Offline stations first, then by missing_hours descending
    is_offline <- is.na(stats_df$n_observations) | stats_df$n_observations == 0L
    stats_df <- stats_df[order(!is_offline, -stats_df$missing_hours, -stats_df$max_wave_height), ]
  } else if (nrow(stats_df) > 0) {
    stats_df$missing_hours <- NA_real_
  }

  station_stats <- if (nrow(stats_df) == 0) {
    "<p>No station data available this week.</p>"
  } else {
    paste(apply(stats_df, 1, function(row) {
    n_obs <- as.integer(row["n_observations"])
    is_offline <- is.na(n_obs) || n_obs == 0L

    # Offline stations get a prominent red banner, not NA metrics
    if (is_offline) {
      return(paste0(
        "<h3 style='color:#dc3545;'>Station ", row["station_id"],
        " — OFFLINE</h3>",
        "<p style='color:#dc3545;font-weight:bold;'>",
        "No observations received this week. ",
        "Station may be offline or ERDDAP data unavailable.</p>"
      ))
    }

    missing_li <- if (!is.na(row["missing_hours"])) {
      mh <- as.numeric(row["missing_hours"])
      mh_style <- if (is.na(mh) || mh > 150) {
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

    fmt <- function(x, digits = 2) {
      v <- suppressWarnings(as.numeric(x))
      if (is.na(v)) return("N/A")
      round(v, digits)
    }

    paste0(
      "<h3>Station ", row["station_id"], "</h3>",
      "<ul>",
      missing_li,
      "<li>Observations: ", n_obs, "</li>",
      "<li>Maximum Wave Height: ", fmt(row["max_wave_height"]), " m</li>",
      "<li>Average Wave Height: ", fmt(row["avg_wave_height"]), " m</li>",
      "<li>Average Wind Speed: ", fmt(row["avg_wind_speed"], 1), " knots</li>",
      "<li>Air Temperature: ", fmt(row["avg_air_temp"], 1), " C</li>",
      "<li>Sea Temperature: ", fmt(row["avg_sea_temp"], 1), " C</li>",
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
      pct <- row$coverage_pct
      color <- if (isTRUE(pct >= 90)) "#28a745"
               else if (isTRUE(pct >= 80)) "#ffc107"
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
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>", email_link("Data Ingestion This Week", "ingestion"), "</summary>",
    ingestion_text,
    db_totals_text,
    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>", email_link("Data Coverage &amp; Gaps", "coverage"), "</summary>",
    coverage_text,
    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>Week-over-Week Changes</summary>",
    "<p><small>No dashboard section shows week-over-week changes, so this ",
    "heading has no link.</small></p>",
    if (!is.null(summary$week_over_week) && nrow(summary$week_over_week) > 0) {
      paste0(
        "<table border='1' style='border-collapse: collapse;'>",
        "<tr><th>Station</th><th>Wave Height Change</th><th>Wind Speed Change</th></tr>",
        paste(apply(summary$week_over_week[, c("station_id", "wave_change_pct", "wind_change_pct")], 1,
          function(row) {
            wv <- suppressWarnings(as.numeric(row[2]))
            wn <- suppressWarnings(as.numeric(row[3]))
            if (is.na(wv) || is.na(wn)) {
              return(paste0(
                "<tr><td>", row[1], "</td>",
                "<td style='color:#999;'>N/A</td>",
                "<td style='color:#999;'>N/A</td></tr>"
              ))
            }
            wave_color <- if (wv > 0) "red" else "green"
            wind_color <- if (wn > 0) "red" else "green"
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
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>", email_link("Rogue &amp; High Waves", "rogue_wave"), "</summary>",
    extreme_text,
    "</details>",

    "<details>",
    "<summary style='cursor:pointer;font-size:1.3em;font-weight:bold;'>", email_link("Station Statistics", "station_stats"), "</summary>",
    station_stats,
    "</details>",

    "</div>",
    "<hr>",
    "<p><small>Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z"), " by the ",
    "<a href='", .dashboard_base_url, "'>irishbuoys</a> R package ",
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
      "[irishbuoys](", .dashboard_base_url, ") R package ",
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