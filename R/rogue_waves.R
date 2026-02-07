#' Rogue Wave Detection and Analysis
#'
#' @description
#' Functions for detecting and analyzing rogue waves from buoy data.
#' Rogue waves are defined as waves where Hmax > threshold * WaveHeight.
#'
#' Standard definition: Hmax > 2.0 * significant wave height
#' Extreme definition: Hmax > 2.2 * significant wave height

#' Detect Rogue Waves in Buoy Data
#'
#' @description
#' Identifies rogue wave events based on the ratio of maximum wave height
#' (Hmax) to significant wave height (WaveHeight).
#' Uses dplyr verbs translated to SQL for efficient DuckDB execution.
#'
#' @param con DBI connection to DuckDB database
#' @param threshold Hmax/WaveHeight ratio threshold (default: 2.0)
#' @param min_wave_height Minimum significant wave height to consider (default: 2m)
#' @param start_date Optional start date filter
#' @param end_date Optional end date filter
#' @param stations Optional vector of station IDs to filter
#'
#' @return Data frame of rogue wave events with associated conditions
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' rogues <- detect_rogue_waves(con, threshold = 2.0)
#' DBI::dbDisconnect(con)
#' }
detect_rogue_waves <- function(
    con,
    threshold = 2.0,
    min_wave_height = 2.0,
    start_date = NULL,
    end_date = NULL,
    stations = NULL
) {

  # Start with lazy table reference
  tbl_ref <- buoy_tbl(con)

  # Apply filters using dplyr verbs
  tbl_ref <- tbl_ref |>
    dplyr::filter(
      !is.na(.data$hmax),
      !is.na(.data$wave_height),
      .data$wave_height >= !!min_wave_height,
      .data$hmax > !!threshold * .data$wave_height
    )

  if (!is.null(start_date)) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$time >= !!start_date)
  }

  if (!is.null(end_date)) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$time <= !!end_date)
  }

  if (!is.null(stations)) {
    tbl_ref <- tbl_ref |> dplyr::filter(.data$station_id %in% !!stations)
  }

  # Select columns and calculate rogue ratio
  rogues <- tbl_ref |>
    dplyr::mutate(
      rogue_ratio = .data$hmax / .data$wave_height,
      peak_period = .data$tp
    ) |>
    dplyr::select(
      "station_id", "time", "wave_height", "hmax", "rogue_ratio",
      "wave_period", "peak_period", "wind_speed", "wind_direction",
      "gust", "atmospheric_pressure", "sea_temperature"
    ) |>
    dplyr::arrange(dplyr::desc(.data$rogue_ratio), dplyr::desc(.data$time)) |>
    dplyr::collect()

  if (nrow(rogues) > 0) {
    cli::cli_alert_success("Detected {nrow(rogues)} rogue wave events (threshold: {threshold})")
  } else {
    cli::cli_alert_info("No rogue waves detected with threshold {threshold}")
  }

  return(rogues)
}

#' Analyze Rogue Wave Statistics
#'
#' @description
#' Computes statistics on rogue wave occurrence rates and associated conditions.
#'
#' @param con DBI connection to DuckDB database
#' @param threshold Hmax/WaveHeight ratio threshold (default: 2.0)
#' @param min_wave_height Minimum significant wave height (default: 2m)
#'
#' @return List containing rogue wave statistics by station and overall
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' stats <- analyze_rogue_statistics(con)
#' print(stats$by_station)
#' DBI::dbDisconnect(con)
#' }
analyze_rogue_statistics <- function(
    con,
    threshold = 2.0,
    min_wave_height = 2.0
) {

  cli::cli_h2("Analyzing Rogue Wave Statistics")

  # Overall statistics
  overall <- DBI::dbGetQuery(con, glue::glue("
    WITH eligible AS (
      SELECT *
      FROM buoy_data
      WHERE wave_height >= {min_wave_height}
        AND hmax IS NOT NULL
        AND wave_height IS NOT NULL
    ),
    rogue_events AS (
      SELECT *
      FROM eligible
      WHERE hmax > {threshold} * wave_height
    )
    SELECT
      (SELECT COUNT(*) FROM eligible) as total_observations,
      (SELECT COUNT(*) FROM rogue_events) as rogue_count,
      ROUND(100.0 * (SELECT COUNT(*) FROM rogue_events) /
            NULLIF((SELECT COUNT(*) FROM eligible), 0), 2) as rogue_pct,
      (SELECT AVG(hmax / wave_height) FROM rogue_events) as avg_rogue_ratio,
      (SELECT MAX(hmax / wave_height) FROM rogue_events) as max_rogue_ratio,
      (SELECT MAX(hmax) FROM rogue_events) as max_hmax
  "))

  # Statistics by station
  by_station <- DBI::dbGetQuery(con, glue::glue("
    WITH eligible AS (
      SELECT *
      FROM buoy_data
      WHERE wave_height >= {min_wave_height}
        AND hmax IS NOT NULL
    )
    SELECT
      station_id,
      COUNT(*) as total_obs,
      SUM(CASE WHEN hmax > {threshold} * wave_height THEN 1 ELSE 0 END) as rogue_count,
      ROUND(100.0 * SUM(CASE WHEN hmax > {threshold} * wave_height THEN 1 ELSE 0 END) /
            COUNT(*), 2) as rogue_pct,
      ROUND(AVG(CASE WHEN hmax > {threshold} * wave_height
                THEN hmax / wave_height END), 2) as avg_rogue_ratio,
      ROUND(MAX(hmax), 2) as max_hmax,
      ROUND(AVG(wave_height), 2) as avg_wave_height
    FROM eligible
    GROUP BY station_id
    ORDER BY rogue_pct DESC
  "))

  # Conditions associated with rogue waves vs normal waves
  conditions <- DBI::dbGetQuery(con, glue::glue("
    WITH eligible AS (
      SELECT
        *,
        CASE WHEN hmax > {threshold} * wave_height THEN 'rogue' ELSE 'normal' END as wave_type
      FROM buoy_data
      WHERE wave_height >= {min_wave_height}
        AND hmax IS NOT NULL
    )
    SELECT
      wave_type,
      COUNT(*) as n,
      ROUND(AVG(wave_height), 2) as avg_wave_height,
      ROUND(AVG(wave_period), 2) as avg_wave_period,
      ROUND(AVG(wind_speed), 1) as avg_wind_speed,
      ROUND(AVG(gust), 1) as avg_gust,
      ROUND(AVG(atmospheric_pressure), 1) as avg_pressure
    FROM eligible
    GROUP BY wave_type
  "))

  # Time distribution (hour of day)
  hourly <- DBI::dbGetQuery(con, glue::glue("
    SELECT
      EXTRACT(HOUR FROM time) as hour,
      COUNT(*) as rogue_count
    FROM buoy_data
    WHERE hmax > {threshold} * wave_height
      AND wave_height >= {min_wave_height}
      AND hmax IS NOT NULL
    GROUP BY EXTRACT(HOUR FROM time)
    ORDER BY hour
  "))

  result <- list(
    overall = overall,
    by_station = by_station,
    conditions = conditions,
    hourly_distribution = hourly,
    threshold = threshold,
    min_wave_height = min_wave_height
  )

  # Print summary
  cli::cli_alert_info("Total observations (wave >= {min_wave_height}m): {overall$total_observations}")
  cli::cli_alert_info("Rogue wave events: {overall$rogue_count} ({overall$rogue_pct}%)")
  if (!is.na(overall$max_hmax)) {
    cli::cli_alert_info("Maximum Hmax observed: {round(overall$max_hmax, 2)}m")
  }

 return(result)
}

#' Calculate Wave Steepness
#'
#' @description
#' Calculates wave steepness, an important safety metric.
#' Steepness > 0.07 indicates breaking waves (dangerous).
#'
#' @param wave_height Significant wave height in meters
#' @param wave_period Wave period in seconds
#'
#' @return Wave steepness (dimensionless)
#'
#' @details
#' Wave steepness = H / L where L = g * T^2 / (2 * pi)
#' Simplified: steepness = H / (1.56 * T^2)
#'
#' @export
#' @examples
#' # 3m wave with 8 second period
#' steepness <- calculate_wave_steepness(3, 8)
#' # steepness = 0.03 (safe)
#'
#' # 3m wave with 4 second period
#' steepness <- calculate_wave_steepness(3, 4)
#' # steepness = 0.12 (dangerous - breaking waves)
calculate_wave_steepness <- function(wave_height, wave_period) {
  # Wavelength L = g * T^2 / (2 * pi) = 1.56 * T^2
  wavelength <- 1.56 * wave_period^2
  steepness <- wave_height / wavelength
  return(steepness)
}

#' Add Wave Metrics to Data
#'
#' @description
#' Adds calculated wave metrics including rogue wave flag and steepness.
#'
#' @param data Data frame with wave_height, hmax, and wave_period columns
#' @param rogue_threshold Threshold for rogue wave classification (default: 2.0)
#'
#' @return Data frame with additional columns: rogue_ratio, is_rogue, steepness, danger_level
#'
#' @export
add_wave_metrics <- function(data, rogue_threshold = 2.0) {

  data$rogue_ratio <- data$hmax / data$wave_height
  data$is_rogue <- data$rogue_ratio > rogue_threshold & data$wave_height >= 2

  data$steepness <- calculate_wave_steepness(data$wave_height, data$wave_period)

  # Danger level based on steepness
  data$danger_level <- dplyr::case_when(
    data$steepness > 0.07 ~ "dangerous",
    data$steepness > 0.04 ~ "moderate",
    TRUE ~ "safe"
  )

  return(data)
}

#' Get Rogue Wave Summary Report
#'
#' @description
#' Generates a formatted summary report of rogue wave analysis.
#'
#' @param con DBI connection to DuckDB database
#' @param days Number of days to analyze (default: 30)
#'
#' @return Character string with formatted report
#'
#' @export
rogue_wave_report <- function(con, days = 30) {

  start_date <- Sys.Date() - days

  # Get rogue events
  rogues <- detect_rogue_waves(
    con,
    threshold = 2.0,
    start_date = start_date
  )

  # Get statistics
  stats <- analyze_rogue_statistics(con, threshold = 2.0)

  # Build report
  report <- paste0(
    "ROGUE WAVE ANALYSIS REPORT\n",
    "==========================\n",
    "Period: ", start_date, " to ", Sys.Date(), "\n",
    "Threshold: Hmax > 2.0 x Significant Wave Height\n\n",

    "SUMMARY\n",
    "-------\n",
    "Total eligible observations: ", stats$overall$total_observations, "\n",
    "Rogue wave events detected: ", stats$overall$rogue_count, "\n",
    "Occurrence rate: ", stats$overall$rogue_pct, "%\n",
    if (!is.na(stats$overall$max_hmax)) {
      paste0("Maximum Hmax: ", round(stats$overall$max_hmax, 2), "m\n")
    } else "",
    "\n",

    "BY STATION\n",
    "----------\n",
    paste(capture.output(print(stats$by_station, row.names = FALSE)), collapse = "\n"),
    "\n\n",

    "CONDITIONS COMPARISON\n",
    "--------------------\n",
    paste(capture.output(print(stats$conditions, row.names = FALSE)), collapse = "\n"),
    "\n"
  )

  return(report)
}
