#' Trend Analysis and Seasonal Decomposition Functions
#'
#' @description
#' Functions for analyzing temporal trends in wave and wind data,
#' including seasonal decomposition and long-term trend estimation.
#'
#' @name trend_analysis
#' @keywords internal
NULL

#' Perform STL Decomposition
#'
#' @description
#' Applies Seasonal-Trend decomposition using Loess (STL) to a time series.
#' This separates the signal into seasonal, trend, and remainder components.
#'
#' @param data Data frame with time and value columns
#' @param variable Name of the variable to decompose (default: "wave_height")
#' @param time_col Name of the time column (default: "time")
#' @param frequency Seasonal frequency (default: "daily" = 24 hours)
#'
#' @return List with:
#'   - decomposition: stl object
#'   - components: data frame with time, seasonal, trend, remainder
#'   - summary: summary statistics of each component
#'
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, stations = "M3")
#' stl_result <- decompose_stl(data)
#' DBI::dbDisconnect(con)
#' }
decompose_stl <- function(
    data,
    variable = "wave_height",
    time_col = "time",
    frequency = "daily"
) {

  cli::cli_progress_step("Performing STL decomposition...")

  # Ensure time is sorted
  data <- data[order(data[[time_col]]), ]

  # Create time series
  values <- data[[variable]]

  # Determine frequency
  freq <- switch(
    frequency,
    "daily" = 24,       # 24 hours in a day
    "weekly" = 168,     # 168 hours in a week
    "monthly" = 720,    # ~720 hours in a month
    "annual" = 8766,    # ~8766 hours in a year
    24                  # default to daily
  )

  # Remove NAs for decomposition
  valid_idx <- !is.na(values)

  if (sum(valid_idx) < 2 * freq) {
    cli::cli_abort("Insufficient data for STL decomposition. Need at least {2 * freq} observations.")
  }

  # Interpolate missing values for time series
  values_interp <- stats::approx(
    x = which(valid_idx),
    y = values[valid_idx],
    xout = 1:length(values),
    rule = 2
  )$y

  # Create ts object
  ts_data <- stats::ts(values_interp, frequency = freq)

  # STL decomposition
  stl_result <- stats::stl(ts_data, s.window = "periodic")

  # Extract components
  components <- data.frame(
    time = data[[time_col]],
    original = values,
    seasonal = as.numeric(stl_result$time.series[, "seasonal"]),
    trend = as.numeric(stl_result$time.series[, "trend"]),
    remainder = as.numeric(stl_result$time.series[, "remainder"])
  )

  # Summary statistics
  summary_stats <- data.frame(
    component = c("seasonal", "trend", "remainder"),
    mean = c(
      mean(components$seasonal, na.rm = TRUE),
      mean(components$trend, na.rm = TRUE),
      mean(components$remainder, na.rm = TRUE)
    ),
    sd = c(
      stats::sd(components$seasonal, na.rm = TRUE),
      stats::sd(components$trend, na.rm = TRUE),
      stats::sd(components$remainder, na.rm = TRUE)
    ),
    variance_pct = c(
      100 * stats::var(components$seasonal, na.rm = TRUE),
      100 * stats::var(components$trend, na.rm = TRUE),
      100 * stats::var(components$remainder, na.rm = TRUE)
    ) / stats::var(values, na.rm = TRUE)
  )

  cli::cli_alert_success("STL decomposition complete")
  cli::cli_alert_info("Variance explained - Seasonal: {round(summary_stats$variance_pct[1], 1)}%, Trend: {round(summary_stats$variance_pct[2], 1)}%")

  return(list(
    decomposition = stl_result,
    components = components,
    summary = summary_stats,
    frequency = freq,
    variable = variable
  ))
}

#' Calculate Seasonal Means
#'
#' @description
#' Calculates mean values by month and season for a variable.
#'
#' @param data Data frame with time and value columns
#' @param variable Name of the variable (default: "wave_height")
#' @param time_col Name of the time column (default: "time")
#'
#' @return List with:
#'   - monthly: mean values by month
#'   - seasonal: mean values by season (DJF, MAM, JJA, SON)
#'
#' @export
calculate_seasonal_means <- function(
    data,
    variable = "wave_height",
    time_col = "time"
) {

  cli::cli_progress_step("Calculating seasonal means...")

  # Ensure time is POSIXct
  if (!inherits(data[[time_col]], "POSIXct")) {
    data[[time_col]] <- as.POSIXct(data[[time_col]])
  }

  # Extract month
  data$month <- as.integer(format(data[[time_col]], "%m"))

  # Monthly means
  monthly <- stats::aggregate(
    data[[variable]],
    by = list(month = data$month),
    FUN = function(x) c(
      mean = mean(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE),
      median = stats::median(x, na.rm = TRUE),
      n = sum(!is.na(x))
    )
  )
  monthly <- data.frame(
    month = monthly$month,
    mean = monthly$x[, 1],
    sd = monthly$x[, 2],
    median = monthly$x[, 3],
    n = monthly$x[, 4]
  )

  # Add month names
  monthly$month_name <- month.abb[monthly$month]

  # Seasonal means (meteorological seasons)
  data$season <- dplyr::case_when(
    data$month %in% c(12, 1, 2) ~ "Winter (DJF)",
    data$month %in% c(3, 4, 5) ~ "Spring (MAM)",
    data$month %in% c(6, 7, 8) ~ "Summer (JJA)",
    data$month %in% c(9, 10, 11) ~ "Autumn (SON)"
  )

  seasonal <- stats::aggregate(
    data[[variable]],
    by = list(season = data$season),
    FUN = function(x) c(
      mean = mean(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE),
      max = max(x, na.rm = TRUE),
      n = sum(!is.na(x))
    )
  )
  seasonal <- data.frame(
    season = seasonal$season,
    mean = seasonal$x[, 1],
    sd = seasonal$x[, 2],
    max = seasonal$x[, 3],
    n = seasonal$x[, 4]
  )

  # Order seasons correctly
  season_order <- c("Winter (DJF)", "Spring (MAM)", "Summer (JJA)", "Autumn (SON)")
  seasonal <- seasonal[match(season_order, seasonal$season), ]

  cli::cli_alert_success("Seasonal means calculated")

  return(list(
    monthly = monthly,
    seasonal = seasonal,
    variable = variable
  ))
}

#' Calculate Annual Trends
#'
#' @description
#' Calculates annual statistics and fits a linear trend to detect
#' long-term changes in the data.
#'
#' @param data Data frame with time and value columns
#' @param variable Name of the variable (default: "wave_height")
#' @param time_col Name of the time column (default: "time")
#'
#' @return List with:
#'   - annual_stats: annual mean, max, etc.
#'   - trend_model: linear model for trend
#'   - trend_per_decade: change per decade with significance
#'
#' @export
calculate_annual_trends <- function(
    data,
    variable = "wave_height",
    time_col = "time"
) {

  cli::cli_progress_step("Calculating annual trends...")

  # Ensure time is POSIXct
  if (!inherits(data[[time_col]], "POSIXct")) {
    data[[time_col]] <- as.POSIXct(data[[time_col]])
  }

  # Extract year
  data$year <- as.integer(format(data[[time_col]], "%Y"))

  # Annual statistics
  annual_stats <- stats::aggregate(
    data[[variable]],
    by = list(year = data$year),
    FUN = function(x) c(
      mean = mean(x, na.rm = TRUE),
      median = stats::median(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE),
      max = max(x, na.rm = TRUE),
      p90 = stats::quantile(x, 0.90, na.rm = TRUE),
      p99 = stats::quantile(x, 0.99, na.rm = TRUE),
      n = sum(!is.na(x))
    )
  )
  annual_stats <- data.frame(
    year = annual_stats$year,
    mean = annual_stats$x[, 1],
    median = annual_stats$x[, 2],
    sd = annual_stats$x[, 3],
    max = annual_stats$x[, 4],
    p90 = annual_stats$x[, 5],
    p99 = annual_stats$x[, 6],
    n = annual_stats$x[, 7]
  )

  # Fit linear trend to annual means
  if (nrow(annual_stats) >= 3) {
    trend_model <- stats::lm(mean ~ year, data = annual_stats)
    trend_summary <- summary(trend_model)

    # Trend per decade
    trend_per_year <- stats::coef(trend_model)["year"]
    trend_per_decade <- trend_per_year * 10
    p_value <- trend_summary$coefficients["year", "Pr(>|t|)"]
    r_squared <- trend_summary$r.squared

    cli::cli_alert_info("Trend: {round(trend_per_decade, 3)} {variable} units per decade (p={round(p_value, 3)})")
  } else {
    trend_model <- NULL
    trend_per_decade <- NA
    p_value <- NA
    r_squared <- NA
    cli::cli_alert_warning("Insufficient years for trend analysis")
  }

  return(list(
    annual_stats = annual_stats,
    trend_model = trend_model,
    trend_per_decade = trend_per_decade,
    p_value = p_value,
    r_squared = r_squared,
    variable = variable
  ))
}

#' Detect Anomalies
#'
#' @description
#' Identifies anomalous values using standard deviation thresholds
#' relative to seasonal norms.
#'
#' @param data Data frame with time and value columns
#' @param variable Name of the variable (default: "wave_height")
#' @param time_col Name of the time column (default: "time")
#' @param threshold Number of standard deviations for anomaly detection (default: 3)
#'
#' @return List with:
#'   - anomalies: data frame of anomalous observations
#'   - seasonal_norms: monthly mean and sd used as baseline
#'   - summary: count of anomalies by month
#'
#' @export
detect_anomalies <- function(
    data,
    variable = "wave_height",
    time_col = "time",
    threshold = 3
) {

  cli::cli_progress_step("Detecting anomalies...")

  # Ensure time is POSIXct
  if (!inherits(data[[time_col]], "POSIXct")) {
    data[[time_col]] <- as.POSIXct(data[[time_col]])
  }

  # Extract month
  data$month <- as.integer(format(data[[time_col]], "%m"))

  # Calculate monthly norms
  monthly_norms <- stats::aggregate(
    data[[variable]],
    by = list(month = data$month),
    FUN = function(x) c(
      mean = mean(x, na.rm = TRUE),
      sd = stats::sd(x, na.rm = TRUE)
    )
  )
  monthly_norms <- data.frame(
    month = monthly_norms$month,
    norm_mean = monthly_norms$x[, 1],
    norm_sd = monthly_norms$x[, 2]
  )

  # Merge norms back to data
  data <- merge(data, monthly_norms, by = "month", all.x = TRUE)

  # Calculate z-score
  data$z_score <- (data[[variable]] - data$norm_mean) / data$norm_sd

  # Identify anomalies
  data$is_anomaly <- abs(data$z_score) > threshold

  anomalies <- data[data$is_anomaly & !is.na(data$is_anomaly), ]
  anomalies <- anomalies[order(-abs(anomalies$z_score)), ]

  # Summary by month
  anomaly_summary <- stats::aggregate(
    data$is_anomaly,
    by = list(month = data$month),
    FUN = function(x) sum(x, na.rm = TRUE)
  )
  names(anomaly_summary) <- c("month", "n_anomalies")
  anomaly_summary$month_name <- month.abb[anomaly_summary$month]

  cli::cli_alert_success("Detected {nrow(anomalies)} anomalies (>{threshold} SD from seasonal norm)")

  return(list(
    anomalies = anomalies,
    seasonal_norms = monthly_norms,
    summary = anomaly_summary,
    threshold = threshold,
    variable = variable
  ))
}

#' Create Trend Summary Report
#'
#' @description
#' Generates a formatted summary of trend analysis results.
#'
#' @param seasonal_means Result from calculate_seasonal_means
#' @param annual_trends Result from calculate_annual_trends
#' @param anomalies Result from detect_anomalies (optional)
#'
#' @return Character string with formatted report
#'
#' @export
trend_summary_report <- function(
    seasonal_means,
    annual_trends,
    anomalies = NULL
) {

  report <- paste0(
    "=== Trend Analysis Report: ", seasonal_means$variable, " ===\n\n",
    "SEASONAL PATTERNS\n",
    "-----------------\n"
  )

  for (i in 1:nrow(seasonal_means$seasonal)) {
    s <- seasonal_means$seasonal[i, ]
    report <- paste0(report, sprintf(
      "%s: mean=%.2f (sd=%.2f), max=%.2f, n=%d\n",
      s$season, s$mean, s$sd, s$max, s$n
    ))
  }

  report <- paste0(report, "\nANNUAL TREND\n", "------------\n")

  if (!is.na(annual_trends$trend_per_decade)) {
    significance <- ifelse(annual_trends$p_value < 0.05, "significant", "not significant")
    report <- paste0(report, sprintf(
      "Trend: %+.3f per decade (p=%.3f, %s)\n",
      annual_trends$trend_per_decade, annual_trends$p_value, significance
    ))
    report <- paste0(report, sprintf("R-squared: %.3f\n", annual_trends$r_squared))
  } else {
    report <- paste0(report, "Insufficient data for trend analysis\n")
  }

  if (!is.null(anomalies)) {
    report <- paste0(
      report, "\nANOMALIES\n", "---------\n",
      sprintf("Total anomalies detected: %d (threshold: %d SD)\n",
              nrow(anomalies$anomalies), anomalies$threshold)
    )
  }

  return(report)
}
