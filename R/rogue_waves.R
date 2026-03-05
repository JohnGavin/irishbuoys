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
  # Defensive: NULL check for connection
  if (is.null(con)) {
    cli::cli_abort(c(
      "x" = "{.arg con} cannot be NULL",
      "i" = "Provide a DBI connection from {.fn connect_duckdb}"
    ))
  }

  # Defensive: Valid DBI connection
  if (!inherits(con, "DBIConnection")) {
    cli::cli_abort(c(
      "x" = "{.arg con} must be a DBI connection",
      "i" = "You provided {.cls {class(con)}}",
      ">" = "Use {.code con <- connect_duckdb()} to create a connection"
    ))
  }

  # Defensive: Numeric threshold
  if (!is.numeric(threshold) || length(threshold) != 1 || threshold <= 0) {
    cli::cli_abort(c(
      "x" = "{.arg threshold} must be a positive number",
      "i" = "Standard rogue wave threshold is 2.0"
    ))
  }

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

  # Eligible observations: wave_height >= threshold with valid hmax
  eligible_tbl <- buoy_tbl(con) |>
    dplyr::filter(
      .data$wave_height >= !!min_wave_height,
      !is.na(.data$hmax),
      !is.na(.data$wave_height)
    )

  # Overall statistics
  eligible_data <- eligible_tbl |>
    dplyr::mutate(
      is_rogue = .data$hmax > !!threshold * .data$wave_height,
      rogue_ratio = .data$hmax / .data$wave_height
    ) |>
    dplyr::collect()

  rogue_data <- dplyr::filter(eligible_data, .data$is_rogue)

  overall <- tibble::tibble(
    total_observations = nrow(eligible_data),
    rogue_count = nrow(rogue_data),
    rogue_pct = round(100 * nrow(rogue_data) / max(nrow(eligible_data), 1), 2),
    avg_rogue_ratio = if (nrow(rogue_data) > 0) round(mean(rogue_data$rogue_ratio), 4) else NA_real_,
    max_rogue_ratio = if (nrow(rogue_data) > 0) round(max(rogue_data$rogue_ratio), 4) else NA_real_,
    max_hmax = if (nrow(rogue_data) > 0) round(max(rogue_data$hmax), 2) else NA_real_
  )

  # Statistics by station
  by_station <- eligible_data |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      total_obs = dplyr::n(),
      rogue_count = sum(.data$is_rogue),
      rogue_pct = round(100 * sum(.data$is_rogue) / dplyr::n(), 2),
      avg_rogue_ratio = round(mean(.data$rogue_ratio[.data$is_rogue], na.rm = TRUE), 2),
      max_hmax = round(max(.data$hmax), 2),
      avg_wave_height = round(mean(.data$wave_height), 2),
      .groups = "drop"
    ) |>
    dplyr::arrange(dplyr::desc(.data$rogue_pct))

  # Conditions associated with rogue waves vs normal waves
  conditions <- eligible_data |>
    dplyr::mutate(
      wave_type = dplyr::if_else(.data$is_rogue, "rogue", "normal")
    ) |>
    dplyr::group_by(.data$wave_type) |>
    dplyr::summarise(
      n = dplyr::n(),
      avg_wave_height = round(mean(.data$wave_height, na.rm = TRUE), 2),
      avg_wave_period = round(mean(.data$wave_period, na.rm = TRUE), 2),
      avg_wind_speed = round(mean(.data$wind_speed, na.rm = TRUE), 1),
      avg_gust = round(mean(.data$gust, na.rm = TRUE), 1),
      avg_pressure = round(mean(.data$atmospheric_pressure, na.rm = TRUE), 1),
      .groups = "drop"
    )

  # Time distribution (hour of day)
  hourly <- rogue_data |>
    dplyr::mutate(hour = as.integer(format(.data$time, "%H"))) |>
    dplyr::count(.data$hour, name = "rogue_count") |>
    dplyr::arrange(.data$hour)

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
  # Defensive: NULL checks
  if (is.null(wave_height)) {
    cli::cli_abort(c(
      "x" = "{.arg wave_height} cannot be NULL",
      "i" = "Provide numeric wave height values in meters"
    ))
  }
  if (is.null(wave_period)) {
    cli::cli_abort(c(
      "x" = "{.arg wave_period} cannot be NULL",
      "i" = "Provide numeric wave period values in seconds"
    ))
  }

  # Defensive: Type checks
  if (!is.numeric(wave_height)) {
    cli::cli_abort(c(
      "x" = "{.arg wave_height} must be numeric",
      "i" = "You provided {.cls {class(wave_height)}}"
    ))
  }
  if (!is.numeric(wave_period)) {
    cli::cli_abort(c(
      "x" = "{.arg wave_period} must be numeric",
      "i" = "You provided {.cls {class(wave_period)}}"
    ))
  }

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
  # Defensive: NULL check
  if (is.null(data)) {
    cli::cli_abort(c(
      "x" = "{.arg data} cannot be NULL",
      "i" = "Provide a data frame with wave measurements"
    ))
  }

  # Defensive: Type check
  if (!inherits(data, "data.frame")) {
    cli::cli_abort(c(
      "x" = "{.arg data} must be a data frame",
      "i" = "You provided {.cls {class(data)}}"
    ))
  }

  # Defensive: Required columns
  required_cols <- c("wave_height", "hmax", "wave_period")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Data must contain: {.val {required_cols}}"
    ))
  }

  # Defensive: Empty data
  if (nrow(data) == 0) {
    cli::cli_alert_warning("Data has 0 rows, returning empty data frame with metric columns")
    data$rogue_ratio <- numeric(0)
    data$is_rogue <- logical(0)
    data$steepness <- numeric(0)
    data$danger_level <- character(0)
    return(data)
  }

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

#' Test Spatial Propagation of Rogue Wave Events
#'
#' @description
#' Tests whether rogue wave events at one station are followed by rogue events
#' at another station within a time window consistent with wave propagation.
#' Uses a permutation test: the null hypothesis is that rogue events at the
#' second station are uniformly distributed over time (no clustering with the
#' first station).
#'
#' For each station pair, the theoretical propagation lag is estimated as
#' `distance_km / propagation_speed_kmh` (default 30 km/h for deep-water
#' swell group velocity). Co-occurrence is counted when a station-2 rogue event
#' falls within `[lag - tolerance, lag + tolerance]` hours of a station-1 event.
#'
#' @param data Data frame with columns: `time` (POSIXct), `station_id`
#'   (character), `wave_height` (numeric), `hmax` (numeric).
#' @param rogue_threshold Hmax/Hs ratio threshold for rogue classification
#'   (default: 2.0).
#' @param min_wave_height Minimum significant wave height in metres for a
#'   qualifying observation (default: 2.0).
#' @param station_pairs Optional list of character vectors, each of length 2,
#'   specifying directed pairs `c(source, receiver)`. If `NULL`, uses default
#'   focus pairs: M6->M2, M6->M3, M6->M5, M2->M3, M3->M5.
#' @param propagation_speed_kmh Assumed deep-water group velocity in km/h
#'   (default: 30).
#' @param n_permutations Number of permutations for the test (default: 500).
#' @param station_info Optional data frame from [get_station_info()]. If `NULL`,
#'   uses the default 5-station network.
#'
#' @return List with:
#'   \describe{
#'     \item{h3_table}{Data frame with columns: `station1`, `station2`,
#'       `distance_km`, `theoretical_lag_hrs`, `n_rogue_s1`, `n_rogue_s2`,
#'       `co_occurrence_count`, `co_occurrence_rate`, `marginal_rate`,
#'       `perm_mean_rate`, `p_value`, `h3_significant` (logical), `h3_verdict`.}
#'     \item{rogue_events}{Data frame of all detected rogue wave events.}
#'     \item{n_rogue_total}{Total number of rogue events across all stations.}
#'   }
#'
#' @family rogue-waves
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, variables = c("time", "station_id", "wave_height", "hmax"))
#' result <- test_rogue_propagation(data)
#' result$h3_table
#' DBI::dbDisconnect(con)
#' }
test_rogue_propagation <- function(
    data,
    rogue_threshold = 2.0,
    min_wave_height = 2.0,
    station_pairs = NULL,
    propagation_speed_kmh = 30,
    n_permutations = 500,
    station_info = NULL
) {
  # Validate inputs
  required_cols <- c("time", "station_id", "wave_height", "hmax")
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Data must contain: {.val {required_cols}}"
    ))
  }

  if (is.null(station_info)) {
    station_info <- get_station_info()
  }
  dist_matrix <- station_distance_matrix(station_info)

  # Identify rogue events
  valid_idx <- !is.na(data$hmax) & !is.na(data$wave_height) &
    data$wave_height >= min_wave_height
  rogue_data <- data[valid_idx, ]
  rogue_data$rogue_ratio <- rogue_data$hmax / rogue_data$wave_height
  rogue_data$is_rogue <- rogue_data$rogue_ratio > rogue_threshold

  rogue_events <- rogue_data[rogue_data$is_rogue, ]
  cli::cli_alert_info(
    "Detected {nrow(rogue_events)} rogue events out of {nrow(rogue_data)} qualifying observations"
  )

  if (nrow(rogue_events) == 0) {
    cli::cli_alert_warning("No rogue wave events detected")
    return(list(
      h3_table = data.frame(),
      rogue_events = rogue_events,
      n_rogue_total = 0
    ))
  }

  # Default station pairs
  if (is.null(station_pairs)) {
    station_pairs <- list(
      c("M6", "M2"), c("M6", "M3"), c("M6", "M5"),
      c("M2", "M3"), c("M3", "M5")
    )
  }

  # Filter to pairs where both stations exist in data
  available_stations <- unique(data$station_id)
  station_pairs <- Filter(function(p) {
    p[1] %in% available_stations && p[2] %in% available_stations
  }, station_pairs)

  if (length(station_pairs) == 0) {
    cli::cli_alert_warning("No valid station pairs found in data")
    return(list(
      h3_table = data.frame(),
      rogue_events = rogue_events,
      n_rogue_total = nrow(rogue_events)
    ))
  }

  cli::cli_alert_info(
    "Testing rogue propagation for {length(station_pairs)} station pairs ({n_permutations} permutations)"
  )

  total_hours <- as.numeric(
    difftime(max(rogue_data$time), min(rogue_data$time), units = "hours")
  )

  results <- lapply(station_pairs, function(pair) {
    s1 <- pair[1]
    s2 <- pair[2]

    # Distance and theoretical lag
    dist_km <- if (s1 %in% rownames(dist_matrix) && s2 %in% colnames(dist_matrix)) {
      dist_matrix[s1, s2]
    } else {
      NA_real_
    }
    theoretical_lag_hrs <- dist_km / propagation_speed_kmh

    # Rogue event times at each station
    r1_times <- rogue_events$time[rogue_events$station_id == s1]
    r2_times <- rogue_events$time[rogue_events$station_id == s2]

    if (length(r1_times) < 3 || length(r2_times) < 3) {
      cli::cli_alert_warning(
        "Skipping {s1}->{s2}: too few rogues ({length(r1_times)}, {length(r2_times)})"
      )
      return(data.frame(
        station1 = s1, station2 = s2,
        distance_km = dist_km,
        theoretical_lag_hrs = theoretical_lag_hrs,
        n_rogue_s1 = length(r1_times), n_rogue_s2 = length(r2_times),
        co_occurrence_count = NA_integer_,
        co_occurrence_rate = NA_real_, marginal_rate = NA_real_,
        perm_mean_rate = NA_real_, p_value = NA_real_,
        h3_significant = NA,
        h3_verdict = "INCONCLUSIVE - too few rogue events",
        stringsAsFactors = FALSE, row.names = NULL
      ))
    }

    # Co-occurrence window
    lag_window <- max(1, round(theoretical_lag_hrs))
    tolerance <- max(2, lag_window)

    # Count observed co-occurrences
    r1_num <- as.numeric(r1_times)
    r2_num <- as.numeric(r2_times)
    co_occur <- sum(vapply(r1_num, function(t1) {
      time_diffs_hrs <- (r2_num - t1) / 3600
      any(abs(time_diffs_hrs - lag_window) <= tolerance)
    }, logical(1)))
    obs_rate <- co_occur / length(r1_times)

    # Marginal rate
    marginal_rate <- length(r2_times) * (2 * tolerance) / total_hours

    # Permutation test
    all_s2_times <- data$time[data$station_id == s2]
    all_s2_num <- as.numeric(all_s2_times)
    perm_rates <- replicate(n_permutations, {
      perm_r2 <- sample(all_s2_num, length(r2_times), replace = FALSE)
      perm_co <- sum(vapply(r1_num, function(t1) {
        any(abs((perm_r2 - t1) / 3600 - lag_window) <= tolerance)
      }, logical(1)))
      perm_co / length(r1_times)
    })

    p_value <- mean(perm_rates >= obs_rate)
    is_sig <- p_value < 0.05

    data.frame(
      station1 = s1, station2 = s2,
      distance_km = dist_km,
      theoretical_lag_hrs = theoretical_lag_hrs,
      n_rogue_s1 = length(r1_times), n_rogue_s2 = length(r2_times),
      co_occurrence_count = co_occur,
      co_occurrence_rate = obs_rate,
      marginal_rate = marginal_rate,
      perm_mean_rate = mean(perm_rates),
      p_value = p_value,
      h3_significant = is_sig,
      h3_verdict = if (is_sig) {
        "SUPPORTED - significant spatial clustering"
      } else {
        "NOT SUPPORTED - no significant clustering"
      },
      stringsAsFactors = FALSE, row.names = NULL
    )
  })

  h3_table <- do.call(rbind, results)
  row.names(h3_table) <- NULL

  n_sig <- sum(h3_table$h3_significant, na.rm = TRUE)
  cli::cli_alert_success(
    "{n_sig}/{nrow(h3_table)} pairs show significant rogue wave clustering (p < 0.05)"
  )

  list(
    h3_table = h3_table,
    rogue_events = rogue_events,
    n_rogue_total = nrow(rogue_events)
  )
}
