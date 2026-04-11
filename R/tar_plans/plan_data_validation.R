#' Targets Plan: Data Validation
#'
#' Systematic data-level validation as targets. Every check uses dplyr (NO raw SQL).
#' Runs on every tar_make() after data_update, before downstream analysis.
#'
#' Configuration constants — adjust per project:
#' @keywords internal

# ── Configuration ────────────────────────────────────────────────────────────
EXPECTED_FREQUENCY_HOURS <- 1L
ENTITY_ID_COLUMN <- "station_id"
TIMESTAMP_COLUMN <- "time"
MIN_COVERAGE_ABORT <- 30
MIN_COVERAGE_WARN <- 80
MAX_GAP_HOURS <- 6
MAX_STALE_HOURS <- 72
LOOKBACK_DAYS_VALIDATION <- 7L

plan_data_validation <- list(

  # ── Temporal Coverage ────────────────────────────────────────────────────────
  # Expected vs actual hourly observations per station.
  # Fails pipeline if any station < 30% coverage.

  targets::tar_target(
    dv_temporal_coverage,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      end_date <- Sys.Date()
      start_date <- end_date - LOOKBACK_DAYS_VALIDATION
      start_dt <- as.POSIXct(start_date, tz = "UTC")
      end_dt <- as.POSIXct(end_date, tz = "UTC")
      expected_hours <- as.integer(difftime(end_dt, start_dt, units = "hours"))

      # MANDATORY: start from canonical station list, left-join data.
      # Never group_by(station_id) on filtered data alone — stations with
      # zero recent records must appear as 0% coverage, not be omitted.
      # See rule: never-drop-missing-stations.
      all_stations <- get_station_info()

      data_coverage <- buoy_tbl(con) |>
        dplyr::filter(
          time >= .env$start_dt,
          time < .env$end_dt
        ) |>
        dplyr::collect() |>
        dplyr::mutate(
          hour = as.POSIXct(format(time, "%Y-%m-%d %H:00:00"), tz = "UTC")
        ) |>
        dplyr::group_by(station_id) |>
        dplyr::summarise(
          actual_hours = dplyr::n_distinct(hour),
          n_records = dplyr::n(),
          .groups = "drop"
        )

      coverage <- all_stations |>
        dplyr::select("station_id") |>
        dplyr::left_join(data_coverage, by = "station_id") |>
        dplyr::mutate(
          actual_hours = tidyr::replace_na(actual_hours, 0L),
          n_records = tidyr::replace_na(n_records, 0L),
          expected_hours = expected_hours,
          coverage_pct = round(100 * actual_hours / expected_hours, 1),
          missing_hours = expected_hours - actual_hours,
          status = dplyr::if_else(actual_hours == 0L, "offline", "reporting")
        )

      # Warn (not abort) if any station below critical threshold.
      # A single station ERDDAP outage should not block the entire pipeline.
      low_cov <- dplyr::filter(coverage, coverage_pct < MIN_COVERAGE_ABORT)
      if (nrow(low_cov) > 0) {
        cli::cli_warn(c(
          "!" = "Critically low temporal coverage detected",
          "i" = "Stations below {MIN_COVERAGE_ABORT}%: {paste(low_cov$station_id, collapse = ', ')}",
          "i" = "Expected {expected_hours} hourly observations per station",
          "i" = "Pipeline continues with available data"
        ))
      }

      # Warn if any station below warn threshold
      warn_cov <- dplyr::filter(coverage, coverage_pct < MIN_COVERAGE_WARN)
      if (nrow(warn_cov) > 0) {
        cli::cli_warn(c(
          "!" = "Low temporal coverage detected",
          "i" = "Stations below {MIN_COVERAGE_WARN}%: {paste(warn_cov$station_id, collapse = ', ')}",
          "i" = "This may indicate ERDDAP data gaps or ingestion issues"
        ))
      }

      cli::cli_alert_success(
        "Temporal coverage: {nrow(coverage)} stations checked, {expected_hours}h expected"
      )
      coverage
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Temporal Gaps ────────────────────────────────────────────────────────────
  # Contiguous gaps >= MAX_GAP_HOURS per station. Informational (no abort).

  targets::tar_target(
    dv_temporal_gaps,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      end_date <- Sys.Date()
      start_date <- end_date - LOOKBACK_DAYS_VALIDATION
      start_dt <- as.POSIXct(start_date, tz = "UTC")
      end_dt <- as.POSIXct(end_date, tz = "UTC")

      all_obs <- buoy_tbl(con) |>
        dplyr::filter(
          time >= .env$start_dt,
          time < .env$end_dt
        ) |>
        dplyr::collect() |>
        dplyr::mutate(
          hour = as.POSIXct(format(time, "%Y-%m-%d %H:00:00"), tz = "UTC")
        ) |>
        dplyr::distinct(station_id, hour) |>
        dplyr::arrange(station_id, hour) |>
        dplyr::group_by(station_id) |>
        dplyr::mutate(
          prev_hour = dplyr::lag(hour),
          gap_hours = as.numeric(difftime(hour, prev_hour, units = "hours"))
        ) |>
        dplyr::ungroup()

      gaps <- all_obs |>
        dplyr::filter(gap_hours >= MAX_GAP_HOURS) |>
        dplyr::transmute(
          station_id,
          gap_start = prev_hour,
          gap_end = hour,
          gap_hours
        )

      if (nrow(gaps) > 0) {
        cli::cli_warn(c(
          "!" = "{nrow(gaps)} temporal gap(s) >= {MAX_GAP_HOURS}h detected",
          "i" = "Stations affected: {paste(unique(gaps$station_id), collapse = ', ')}"
        ))
      } else {
        cli::cli_alert_success("No temporal gaps >= {MAX_GAP_HOURS}h detected")
      }

      gaps
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Sampling Frequency ──────────────────────────────────────────────────────
  # Median interval between observations should be ~EXPECTED_FREQUENCY_HOURS.
  # Fails if median > 2x expected frequency.

  targets::tar_target(
    dv_sampling_frequency,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      end_date <- Sys.Date()
      start_date <- end_date - LOOKBACK_DAYS_VALIDATION
      start_dt <- as.POSIXct(start_date, tz = "UTC")
      end_dt <- as.POSIXct(end_date, tz = "UTC")

      intervals <- buoy_tbl(con) |>
        dplyr::filter(
          time >= .env$start_dt,
          time < .env$end_dt
        ) |>
        dplyr::select(station_id, time) |>
        dplyr::collect() |>
        dplyr::arrange(station_id, time) |>
        dplyr::group_by(station_id) |>
        dplyr::mutate(
          interval_hours = as.numeric(difftime(time, dplyr::lag(time), units = "hours"))
        ) |>
        dplyr::filter(!is.na(interval_hours)) |>
        dplyr::summarise(
          median_interval = round(stats::median(interval_hours), 2),
          mean_interval = round(mean(interval_hours), 2),
          n_obs = dplyr::n() + 1L,
          .groups = "drop"
        )

      max_acceptable <- 2 * EXPECTED_FREQUENCY_HOURS
      bad_freq <- dplyr::filter(intervals, median_interval > max_acceptable)
      if (nrow(bad_freq) > 0) {
        cli::cli_abort(c(
          "x" = "Sampling frequency validation FAILED",
          "i" = "Stations with median interval > {max_acceptable}h: {paste(bad_freq$station_id, collapse = ', ')}",
          "i" = "Expected ~{EXPECTED_FREQUENCY_HOURS}h between observations"
        ))
      }

      cli::cli_alert_success(
        "Sampling frequency OK: all stations median <= {max_acceptable}h"
      )
      intervals
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Station Completeness ────────────────────────────────────────────────────
  # All expected stations present in the validation period.

  targets::tar_target(
    dv_station_completeness,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      end_date <- Sys.Date()
      start_date <- end_date - LOOKBACK_DAYS_VALIDATION
      start_dt <- as.POSIXct(start_date, tz = "UTC")
      end_dt <- as.POSIXct(end_date, tz = "UTC")

      # Get stations active in the database (ever)
      all_stations <- buoy_tbl(con) |>
        dplyr::distinct(station_id) |>
        dplyr::collect() |>
        dplyr::pull(station_id) |>
        sort()

      # Get stations present in the validation window
      recent_stations <- buoy_tbl(con) |>
        dplyr::filter(
          time >= .env$start_dt,
          time < .env$end_dt
        ) |>
        dplyr::distinct(station_id) |>
        dplyr::collect() |>
        dplyr::pull(station_id) |>
        sort()

      missing <- setdiff(all_stations, recent_stations)

      if (length(missing) > 0) {
        cli::cli_warn(c(
          "!" = "Station completeness: {length(missing)} station(s) missing recent data",
          "i" = "Missing: {paste(missing, collapse = ', ')}",
          "i" = "These stations have historical data but none in the last {LOOKBACK_DAYS_VALIDATION} days",
          "i" = "Pipeline continues with available stations (real-world outage, not a data quality bug)"
        ))
      }

      cli::cli_alert_success(
        "Station completeness: {length(recent_stations)}/{length(all_stations)} stations reporting"
      )

      list(
        all_stations = all_stations,
        recent_stations = recent_stations,
        missing = missing
      )
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Duplicate Check ─────────────────────────────────────────────────────────
  # No duplicate (time, station_id) pairs.

  targets::tar_target(
    dv_duplicate_check,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      total <- buoy_tbl(con) |>
        dplyr::summarise(n = dplyr::n()) |>
        dplyr::collect() |>
        dplyr::pull(n)

      distinct_count <- buoy_tbl(con) |>
        dplyr::distinct(time, station_id) |>
        dplyr::summarise(n = dplyr::n()) |>
        dplyr::collect() |>
        dplyr::pull(n)

      n_dupes <- total - distinct_count

      if (n_dupes > 0) {
        cli::cli_abort(c(
          "x" = "Duplicate check FAILED: {n_dupes} duplicate (time, station_id) pairs found",
          "i" = "Total records: {total}, distinct keys: {distinct_count}"
        ))
      }

      cli::cli_alert_success(
        "Duplicate check: 0 duplicates in {format(total, big.mark = ',')} records"
      )

      list(total_records = total, distinct_keys = distinct_count, duplicates = n_dupes)
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Data Freshness ──────────────────────────────────────────────────────────
  # Latest observation must be within MAX_STALE_HOURS.

  targets::tar_target(
    dv_freshness,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      latest <- buoy_tbl(con) |>
        dplyr::summarise(max_time = max(time, na.rm = TRUE)) |>
        dplyr::collect() |>
        dplyr::pull(max_time)

      hours_old <- as.numeric(
        difftime(Sys.time(), as.POSIXct(latest, tz = "UTC"), units = "hours")
      )

      if (hours_old > MAX_STALE_HOURS) {
        cli::cli_abort(c(
          "x" = "Data freshness FAILED: latest observation is {round(hours_old, 1)} hours old",
          "i" = "Maximum allowed staleness: {MAX_STALE_HOURS} hours",
          "i" = "Latest observation: {latest}"
        ))
      }

      cli::cli_alert_success(
        "Data freshness: latest observation {round(hours_old, 1)}h ago ({latest})"
      )

      list(latest_observation = latest, hours_old = round(hours_old, 1))
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Value Ranges ────────────────────────────────────────────────────────────
  # Physical bounds check using existing validate_buoy_data() if available.

  targets::tar_target(
    dv_value_ranges,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      end_date <- Sys.Date()
      start_date <- end_date - LOOKBACK_DAYS_VALIDATION
      start_dt <- as.POSIXct(start_date, tz = "UTC")
      end_dt <- as.POSIXct(end_date, tz = "UTC")

      recent <- buoy_tbl(con) |>
        dplyr::filter(
          time >= .env$start_dt,
          time < .env$end_dt
        ) |>
        dplyr::collect()

      n_total <- nrow(recent)
      if (n_total == 0) {
        cli::cli_abort(c(
          "x" = "Value ranges: no data in validation window",
          "i" = "Window: {start_date} to {end_date}"
        ))
      }

      # Physical bounds checks
      checks <- list(
        wave_height = list(min = 0, max = 30, col = "wave_height"),
        wind_speed = list(min = 0, max = 120, col = "wind_speed"),
        air_temp = list(min = -20, max = 45, col = "air_temperature"),
        sea_temp = list(min = -2, max = 35, col = "sea_temperature"),
        pressure = list(min = 870, max = 1084, col = "atmospheric_pressure")
      )

      violations <- purrr::map_dfr(checks, function(chk) {
        vals <- recent[[chk$col]]
        vals <- vals[!is.na(vals)]
        n_below <- sum(vals < chk$min)
        n_above <- sum(vals > chk$max)
        tibble::tibble(
          variable = chk$col,
          n_checked = length(vals),
          n_below_min = n_below,
          n_above_max = n_above,
          n_violations = n_below + n_above,
          pct_violations = round(100 * (n_below + n_above) / max(length(vals), 1), 2)
        )
      })

      total_violations <- sum(violations$n_violations)
      total_checked <- sum(violations$n_checked)
      pct_fail <- if (total_checked > 0) 100 * total_violations / total_checked else 0

      if (pct_fail > 5) {
        cli::cli_abort(c(
          "x" = "Value range check FAILED: {round(pct_fail, 1)}% violations (threshold: 5%)",
          "i" = "{total_violations} out-of-bounds values across {total_checked} checked"
        ))
      }

      cli::cli_alert_success(
        "Value ranges: {round(pct_fail, 2)}% violations ({total_violations}/{total_checked})"
      )

      violations
    },
    cue = targets::tar_cue(mode = "always")
  ),

  # ── Validation Report ───────────────────────────────────────────────────────
  # Combines all above into a summary list. Informational only.

  targets::tar_target(
    dv_report,
    {
      report <- list(
        temporal_coverage = dv_temporal_coverage,
        temporal_gaps = dv_temporal_gaps,
        sampling_frequency = dv_sampling_frequency,
        station_completeness = dv_station_completeness,
        duplicate_check = dv_duplicate_check,
        freshness = dv_freshness,
        value_ranges = dv_value_ranges,
        validation_time = Sys.time()
      )

      cli::cli_h2("Data Validation Report")
      cli::cli_alert_info(paste0(
        "Stations: {nrow(report$temporal_coverage)} | ",
        "Gaps: {nrow(report$temporal_gaps)} | ",
        "Duplicates: {report$duplicate_check$duplicates} | ",
        "Freshness: {report$freshness$hours_old}h"
      ))

      report
    },
    cue = targets::tar_cue(mode = "always")
  )
)
