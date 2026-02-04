#' Extreme Value Analysis Functions
#'
#' @description
#' Functions for fitting extreme value distributions and calculating
#' return levels for wave heights and wind speeds.
#'
#' Uses the extRemes package for GEV (annual maxima) and GPD (threshold exceedances).
#'
#' @name extreme_values
#' @keywords internal
NULL

#' Fit GEV Distribution to Annual Maxima
#'
#' @description
#' Fits a Generalized Extreme Value distribution to annual maximum values.
#' This is the Block Maxima approach to extreme value analysis.
#'
#' @param data Data frame with columns: time, value (the variable to analyze)
#' @param variable Name of the variable column (default: "wave_height")
#' @param time_col Name of the time column (default: "time")
#' @param min_years Minimum years of data required (default: 5)
#'
#' @return List with:
#'   - fit: extRemes fevd object
#'   - annual_maxima: data frame of annual maxima
#'   - parameters: GEV parameters (location, scale, shape)
#'   - diagnostics: model diagnostic information
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, variables = c("time", "wave_height"))
#' gev_result <- fit_gev_annual_maxima(data)
#' DBI::dbDisconnect(con)
#' }
fit_gev_annual_maxima <- function(
    data,
    variable = "wave_height",
    time_col = "time",
    min_years = 5
) {

  if (!requireNamespace("extRemes", quietly = TRUE)) {
    cli::cli_abort("Package 'extRemes' is required. Add it to your Nix environment.")
  }

  cli::cli_progress_step("Fitting GEV distribution to annual maxima...")

  # Ensure time is POSIXct
  if (!inherits(data[[time_col]], "POSIXct")) {
    data[[time_col]] <- as.POSIXct(data[[time_col]])
  }

  # Extract year
  data$year <- as.integer(format(data[[time_col]], "%Y"))

  # Calculate annual maxima
  annual_max <- stats::aggregate(
    data[[variable]],
    by = list(year = data$year),
    FUN = max,
    na.rm = TRUE
  )
  names(annual_max) <- c("year", "max_value")

  # Remove years with NA
  annual_max <- annual_max[is.finite(annual_max$max_value), ]

  if (nrow(annual_max) < min_years) {
    cli::cli_alert_warning("Insufficient data: only {nrow(annual_max)} years available, need at least {min_years}")
    return(list(
      fit = NULL,
      annual_maxima = annual_max,
      parameters = c(location = NA, scale = NA, shape = NA),
      n_years = nrow(annual_max),
      variable = variable,
      error = "Insufficient data for GEV fitting"
    ))
  }

  cli::cli_alert_info("Fitting GEV to {nrow(annual_max)} annual maxima ({min(annual_max$year)}-{max(annual_max$year)})")

  # Fit GEV
  fit <- extRemes::fevd(
    x = annual_max$max_value,
    type = "GEV",
    method = "MLE"  # Maximum Likelihood Estimation
  )

  # Extract parameters
  params <- fit$results$par
  names(params) <- c("location", "scale", "shape")

  cli::cli_alert_success("GEV fit complete: location={round(params['location'], 2)}, scale={round(params['scale'], 2)}, shape={round(params['shape'], 3)}")

  return(list(
    fit = fit,
    annual_maxima = annual_max,
    parameters = params,
    n_years = nrow(annual_max),
    variable = variable
  ))
}

#' Fit GPD Distribution to Threshold Exceedances
#'
#' @description
#' Fits a Generalized Pareto Distribution to values exceeding a threshold.
#' This is the Peaks Over Threshold (POT) approach.
#'
#' @param data Data frame with the variable to analyze
#' @param variable Name of the variable column (default: "wave_height")
#' @param threshold Threshold value (default: NULL, uses 95th percentile)
#' @param decluster Logical, whether to decluster exceedances (default: TRUE)
#' @param decluster_hours Minimum hours between independent exceedances (default: 48)
#'
#' @return List with:
#'   - fit: extRemes fevd object
#'   - exceedances: data frame of exceedances
#'   - threshold: threshold used
#'   - parameters: GPD parameters (scale, shape)
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, variables = c("time", "wave_height"))
#' gpd_result <- fit_gpd_threshold(data, threshold = 6)
#' DBI::dbDisconnect(con)
#' }
fit_gpd_threshold <- function(
    data,
    variable = "wave_height",
    threshold = NULL,
    decluster = TRUE,
    decluster_hours = 48
) {

  if (!requireNamespace("extRemes", quietly = TRUE)) {
    cli::cli_abort("Package 'extRemes' is required. Add it to your Nix environment.")
  }

  cli::cli_progress_step("Fitting GPD to threshold exceedances...")

  values <- data[[variable]]
  values <- values[is.finite(values)]

  # Determine threshold if not provided
  if (is.null(threshold)) {
    threshold <- stats::quantile(values, 0.95, na.rm = TRUE)
    cli::cli_alert_info("Using 95th percentile threshold: {round(threshold, 2)}")
  }

  # Get exceedances
  exceedance_idx <- which(values > threshold)
  exceedances <- values[exceedance_idx]

  # Decluster if requested (keep only peak of each cluster)
  if (decluster && "time" %in% names(data)) {
    times <- data$time[exceedance_idx]
    if (!inherits(times, "POSIXct")) {
      times <- as.POSIXct(times)
    }

    # Sort by time
    ord <- order(times)
    times <- times[ord]
    exceedances <- exceedances[ord]

    # Keep peaks separated by at least decluster_hours
    keep <- rep(FALSE, length(exceedances))
    keep[1] <- TRUE
    last_kept_time <- times[1]

    for (i in 2:length(exceedances)) {
      time_diff <- as.numeric(difftime(times[i], last_kept_time, units = "hours"))
      if (time_diff >= decluster_hours) {
        keep[i] <- TRUE
        last_kept_time <- times[i]
      } else if (exceedances[i] > exceedances[which(keep)[sum(keep)]]) {
        # Replace previous peak if this one is higher
        keep[which(keep)[sum(keep)]] <- FALSE
        keep[i] <- TRUE
        last_kept_time <- times[i]
      }
    }

    exceedances <- exceedances[keep]
    cli::cli_alert_info("Declustered: {length(exceedance_idx)} -> {length(exceedances)} independent exceedances")
  }

  if (length(exceedances) < 30) {
    cli::cli_abort("Insufficient exceedances: only {length(exceedances)}, need at least 30")
  }

  cli::cli_alert_info("Fitting GPD to {length(exceedances)} exceedances above threshold {round(threshold, 2)}")

  # Fit GPD
  fit <- extRemes::fevd(
    x = exceedances,
    threshold = threshold,
    type = "GP",
    method = "MLE"
  )

  # Extract parameters
  params <- fit$results$par
  names(params) <- c("scale", "shape")

  cli::cli_alert_success("GPD fit complete: scale={round(params['scale'], 2)}, shape={round(params['shape'], 3)}")

  return(list(
    fit = fit,
    exceedances = exceedances,
    threshold = threshold,
    parameters = params,
    n_exceedances = length(exceedances),
    variable = variable
  ))
}

#' Calculate Return Levels
#'
#' @description
#' Calculates return levels for specified return periods from a fitted
#' extreme value model.
#'
#' @param fit Result from fit_gev_annual_maxima or fit_gpd_threshold
#' @param return_periods Numeric vector of return periods in years (default: c(10, 50, 100))
#' @param conf_level Confidence level for intervals (default: 0.95)
#'
#' @return Data frame with:
#'   - return_period: return period in years
#'   - return_level: estimated return level
#'   - lower: lower confidence bound
#'   - upper: upper confidence bound
#'
#' @export
#' @examples
#' \dontrun{
#' gev_result <- fit_gev_annual_maxima(data)
#' levels <- calculate_return_levels(gev_result, c(10, 50, 100))
#' print(levels)
#' }
calculate_return_levels <- function(
    fit,
    return_periods = c(10, 50, 100),
    conf_level = 0.95
) {

  # Handle case where GEV fitting failed
  if (is.null(fit$fit)) {
    cli::cli_alert_warning("Return levels not calculated: GEV fit not available")
    return(data.frame(
      return_period = return_periods,
      return_level = NA_real_,
      lower = NA_real_,
      upper = NA_real_,
      variable = fit$variable,
      error = fit$error
    ))
  }

  cli::cli_progress_step("Calculating return levels...")

  # Get return levels with confidence intervals
  rl_results <- extRemes::return.level(
    fit$fit,
    return.period = return_periods,
    do.ci = TRUE,
    alpha = 1 - conf_level
  )

  # Extract values
  if (is.matrix(rl_results)) {
    return_levels <- data.frame(
      return_period = return_periods,
      return_level = rl_results[, 2],  # Point estimate
      lower = rl_results[, 1],         # Lower CI
      upper = rl_results[, 3],         # Upper CI
      variable = fit$variable
    )
  } else {
    # Single return period case
    return_levels <- data.frame(
      return_period = return_periods,
      return_level = as.numeric(rl_results[2]),
      lower = as.numeric(rl_results[1]),
      upper = as.numeric(rl_results[3]),
      variable = fit$variable
    )
  }

  cli::cli_alert_success("Return levels calculated for {length(return_periods)} periods")

  return(return_levels)
}

#' Create Return Level Plot Data
#'
#' @description
#' Generates data for a return level plot showing the fitted distribution
#' and confidence intervals.
#'
#' @param fit Result from fit_gev_annual_maxima or fit_gpd_threshold
#' @param max_return_period Maximum return period to plot (default: 200)
#' @param n_points Number of points for the curve (default: 100)
#'
#' @return Data frame suitable for plotting
#'
#' @export
create_return_level_plot_data <- function(
    fit,
    max_return_period = 200,
    n_points = 100
) {

  # Handle case where GEV fitting failed
  if (is.null(fit$fit)) {
    cli::cli_alert_warning("Return level plot data not calculated: GEV fit not available")
    return(data.frame(
      return_period = numeric(0),
      return_level = numeric(0),
      lower = numeric(0),
      upper = numeric(0),
      variable = character(0)
    ))
  }

  return_periods <- exp(seq(log(1.1), log(max_return_period), length.out = n_points))

  rl_data <- calculate_return_levels(fit, return_periods, conf_level = 0.95)

  return(rl_data)
}

#' Analyze Gust Factor
#'
#' @description
#' Analyzes the ratio of peak gust to sustained wind speed.
#' This is the wind equivalent of the wave Hmax/Hs ratio.
#'
#' @param data Data frame with gust and wind_speed columns
#' @param min_wind_speed Minimum sustained wind speed to consider (default: 5 m/s)
#'
#' @return List with:
#'   - summary: summary statistics of gust factor
#'   - extreme_gusts: observations with high gust factors
#'   - by_wind_category: gust factor by wind speed category
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, variables = c("time", "wind_speed", "gust"))
#' gust_analysis <- analyze_gust_factor(data)
#' DBI::dbDisconnect(con)
#' }
analyze_gust_factor <- function(data, min_wind_speed = 5) {

  cli::cli_h2("Analyzing Gust Factor (Peak Gust / Sustained Wind)")

  # Calculate gust factor
  valid_idx <- !is.na(data$wind_speed) & !is.na(data$gust) &
    data$wind_speed >= min_wind_speed

  gust_factor <- data$gust[valid_idx] / data$wind_speed[valid_idx]

  # Summary statistics
  summary_stats <- data.frame(
    statistic = c("n", "mean", "median", "sd", "p95", "p99", "max"),
    value = c(
      length(gust_factor),
      mean(gust_factor, na.rm = TRUE),
      stats::median(gust_factor, na.rm = TRUE),
      stats::sd(gust_factor, na.rm = TRUE),
      stats::quantile(gust_factor, 0.95, na.rm = TRUE),
      stats::quantile(gust_factor, 0.99, na.rm = TRUE),
      max(gust_factor, na.rm = TRUE)
    )
  )

  # Identify extreme gusts (gust factor > 1.5)
  extreme_threshold <- 1.5
  extreme_idx <- which(valid_idx)[gust_factor > extreme_threshold]

  if (length(extreme_idx) > 0) {
    extreme_gusts <- data[extreme_idx, ]
    extreme_gusts$gust_factor <- gust_factor[gust_factor > extreme_threshold]
    extreme_gusts <- extreme_gusts[order(-extreme_gusts$gust_factor), ]
  } else {
    extreme_gusts <- data.frame()
  }

  # Gust factor by wind speed category
  wind_categories <- cut(
    data$wind_speed[valid_idx],
    breaks = c(5, 10, 15, 20, 25, Inf),
    labels = c("5-10", "10-15", "15-20", "20-25", ">25"),
    include.lowest = TRUE
  )

  by_category <- stats::aggregate(
    gust_factor,
    by = list(wind_category = wind_categories),
    FUN = function(x) c(n = length(x), mean = mean(x), p95 = stats::quantile(x, 0.95))
  )
  by_category <- data.frame(
    wind_category = by_category$wind_category,
    n = by_category$x[, 1],
    mean_gf = by_category$x[, 2],
    p95_gf = by_category$x[, 3]
  )

  # Is there a "rogue gust" equivalent?
  # Using 2x the typical gust factor (typical ~1.3, so rogue > 2.6)
  typical_gf <- 1.3
  rogue_threshold <- 2 * typical_gf
  n_rogue_gusts <- sum(gust_factor > rogue_threshold, na.rm = TRUE)
  pct_rogue_gusts <- 100 * n_rogue_gusts / length(gust_factor)

  cli::cli_alert_info("Typical gust factor: {round(summary_stats$value[2], 2)}")
  cli::cli_alert_info("'Rogue gust' events (GF > {rogue_threshold}): {n_rogue_gusts} ({round(pct_rogue_gusts, 3)}%)")

  return(list(
    summary = summary_stats,
    extreme_gusts = extreme_gusts,
    by_category = by_category,
    rogue_gust_threshold = rogue_threshold,
    n_rogue_gusts = n_rogue_gusts,
    pct_rogue_gusts = pct_rogue_gusts
  ))
}

#' Compare Rogue Wave and Rogue Gust Occurrence
#'
#' @description
#' Compares the occurrence rates of rogue waves (Hmax/Hs > 2) and
#' extreme gusts (gust/wind > 2.6).
#'
#' @param data Data frame with wave_height, hmax, wind_speed, gust columns
#'
#' @return Data frame comparing occurrence rates
#'
#' @export
compare_rogue_wave_gust <- function(data) {

  # Rogue wave definition: Hmax/Hs > 2.0
  valid_waves <- !is.na(data$wave_height) & !is.na(data$hmax) &
    data$wave_height >= 2

  if (sum(valid_waves) > 0) {
    wave_ratio <- data$hmax[valid_waves] / data$wave_height[valid_waves]
    n_rogue_waves <- sum(wave_ratio > 2.0, na.rm = TRUE)
    pct_rogue_waves <- 100 * n_rogue_waves / sum(valid_waves)
  } else {
    n_rogue_waves <- 0
    pct_rogue_waves <- NA
  }

  # "Rogue gust" definition: gust/wind > 2.6 (2x typical 1.3)
  valid_wind <- !is.na(data$wind_speed) & !is.na(data$gust) &
    data$wind_speed >= 5

  if (sum(valid_wind) > 0) {
    gust_factor <- data$gust[valid_wind] / data$wind_speed[valid_wind]
    n_rogue_gusts <- sum(gust_factor > 2.6, na.rm = TRUE)
    pct_rogue_gusts <- 100 * n_rogue_gusts / sum(valid_wind)
  } else {
    n_rogue_gusts <- 0
    pct_rogue_gusts <- NA
  }

  comparison <- data.frame(
    phenomenon = c("Rogue Wave", "Rogue Gust"),
    definition = c("Hmax/Hs > 2.0", "Gust/Wind > 2.6"),
    n_events = c(n_rogue_waves, n_rogue_gusts),
    n_eligible = c(sum(valid_waves), sum(valid_wind)),
    occurrence_pct = c(pct_rogue_waves, pct_rogue_gusts)
  )

  return(comparison)
}
