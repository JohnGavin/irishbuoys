#' Joint Distribution Analysis Functions
#'
#' @description
#' Functions for analyzing joint distributions and dependencies between buoys,
#' including cross-correlations, time-lagged predictions, and copula-based
#' extreme value analysis.
#'
#' @name joint_analysis
#' @keywords internal
NULL

#' Station Information with Coordinates
#'
#' @description
#' Returns a data frame with station metadata including coordinates and depths.
#'
#' @return Data frame with columns: station_id, location, lat, lon, depth_m, distance_km
#' @export
#' @examples
#' get_station_info()
get_station_info <- function() {

data.frame(
    station_id = c("M2", "M3", "M4", "M5", "M6"),
    location = c(
      "Southwest Ireland",
      "Southwest Ireland",
      "Southeast Ireland",
      "West Ireland",
      "Northwest Atlantic"
    ),
    lat = c(51.22, 51.22, 51.69, 51.69, 53.07),
    lon = c(-9.99, -10.55, -6.70, -10.00, -15.93),
    depth_m = c(155, 155, 62, 70, 3000),
    distance_km = c(50, 65, 30, 55, 320),
    stringsAsFactors = FALSE
  )
}

#' Calculate Distance Between Two Stations
#'
#' @description
#' Calculates the great-circle distance between two points using the Haversine formula.
#'
#' @param lat1,lon1 Coordinates of first point (degrees)
#' @param lat2,lon2 Coordinates of second point (degrees)
#'
#' @return Distance in kilometers
#' @export
#' @examples
#' # Distance from M6 to M2
#' haversine_distance(53.07, -15.93, 51.22, -9.99)
haversine_distance <- function(lat1, lon1, lat2, lon2) {
  # Earth's radius in km

R <- 6371

  # Convert to radians
  lat1_rad <- lat1 * pi / 180
  lat2_rad <- lat2 * pi / 180
  delta_lat <- (lat2 - lat1) * pi / 180
  delta_lon <- (lon2 - lon1) * pi / 180

  # Haversine formula
  a <- sin(delta_lat / 2)^2 +
    cos(lat1_rad) * cos(lat2_rad) * sin(delta_lon / 2)^2
  c <- 2 * atan2(sqrt(a), sqrt(1 - a))

  R * c
}

#' Calculate Distance Matrix Between All Stations
#'
#' @description
#' Creates a matrix of distances between all station pairs.
#'
#' @param station_info Data frame from get_station_info() or NULL to use default
#'
#' @return Named matrix of distances in km
#' @export
#' @examples
#' station_distance_matrix()
station_distance_matrix <- function(station_info = NULL) {
  if (is.null(station_info)) {
    station_info <- get_station_info()
  }

  n <- nrow(station_info)
  dist_matrix <- matrix(0, nrow = n, ncol = n)
  rownames(dist_matrix) <- station_info$station_id
  colnames(dist_matrix) <- station_info$station_id

  for (i in seq_len(n)) {
    for (j in seq_len(n)) {
      if (i != j) {
        dist_matrix[i, j] <- haversine_distance(
          station_info$lat[i], station_info$lon[i],
          station_info$lat[j], station_info$lon[j]
        )
      }
    }
  }

  round(dist_matrix, 1)
}

#' Calculate Cross-Correlation Between Two Stations
#'
#' @description
#' Computes cross-correlation function (CCF) between two stations for a given variable,
#' identifying the optimal lag for prediction.
#'
#' @param data Data frame with columns: time, station_id, and the variable
#' @param station1,station2 Station IDs to compare
#' @param variable Variable to analyze (default: "wave_height")
#' @param max_lag Maximum lag in hours to test (default: 48)
#'
#' @return List with:
#'   - ccf: cross-correlation values at each lag
#'   - optimal_lag: lag (hours) with maximum correlation
#'   - max_correlation: correlation at optimal lag
#'   - lag_hours: vector of lag values
#'
#' @export
cross_correlation_stations <- function(
    data,
    station1,
    station2,
    variable = "wave_height",
    max_lag = 48
) {
  # Filter to each station
  data1 <- data[data$station_id == station1, c("time", variable)]
  data2 <- data[data$station_id == station2, c("time", variable)]

  names(data1) <- c("time", "value1")
  names(data2) <- c("time", "value2")

  # Merge on time to align observations
  merged <- merge(data1, data2, by = "time", all = FALSE)

  if (nrow(merged) < max_lag * 2) {
    cli::cli_alert_warning(
      "Insufficient overlapping data between {station1} and {station2}"
    )
    return(list(
      ccf = NULL,
      optimal_lag = NA,
      max_correlation = NA,
      n_obs = nrow(merged),
      error = "Insufficient data"
    ))
  }

  # Remove NAs
  merged <- merged[complete.cases(merged), ]

  # Compute CCF
  # Positive lag means station2 leads station1 (station2 predicts station1)
  ccf_result <- stats::ccf(
    merged$value1,
    merged$value2,
    lag.max = max_lag,
    plot = FALSE
  )

  # Extract results
  lag_hours <- ccf_result$lag[, 1, 1]
  correlations <- ccf_result$acf[, 1, 1]

  # Find optimal lag (maximum absolute correlation)
  optimal_idx <- which.max(abs(correlations))
  optimal_lag <- lag_hours[optimal_idx]
  max_corr <- correlations[optimal_idx]

  list(
    ccf = correlations,
    lag_hours = lag_hours,
    optimal_lag = optimal_lag,
    max_correlation = max_corr,
    n_obs = nrow(merged),
    station1 = station1,
    station2 = station2,
    variable = variable
  )
}

#' Analyze All Station Pairs
#'
#' @description
#' Computes cross-correlations for all unique station pairs.
#'
#' @param data Data frame with columns: time, station_id, and the variable
#' @param variable Variable to analyze (default: "wave_height")
#' @param max_lag Maximum lag in hours (default: 48)
#'
#' @return Data frame with one row per station pair containing:
#'   - station1, station2: station pair
#'   - distance_km: distance between stations
#'   - optimal_lag: lag with max correlation
#'   - max_correlation: correlation at optimal lag
#'   - expected_lag: expected lag based on wave propagation (~30 km/h)
#'
#' @export
analyze_station_pairs <- function(
    data,
    variable = "wave_height",
    max_lag = 48
) {
  stations <- sort(unique(data$station_id))
  station_info <- get_station_info()
  dist_matrix <- station_distance_matrix(station_info)

  # Generate all unique pairs
  pairs <- utils::combn(stations, 2, simplify = FALSE)

  results <- lapply(pairs, function(pair) {
    ccf_result <- cross_correlation_stations(
      data, pair[1], pair[2], variable, max_lag
    )

    dist_km <- dist_matrix[pair[1], pair[2]]

    # Expected lag assuming wave propagation speed of ~30 km/h (swell)
    # This is approximate - actual speed varies with wave period
    expected_lag_hours <- dist_km / 30

    data.frame(
      station1 = pair[1],
      station2 = pair[2],
      distance_km = dist_km,
      optimal_lag = ccf_result$optimal_lag,
      max_correlation = ccf_result$max_correlation,
      expected_lag = round(expected_lag_hours, 1),
      n_obs = ccf_result$n_obs,
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}

#' Predict Station from Another with Optimal Lag
#'
#' @description
#' Uses one station to predict another at the optimal lag.
#' Particularly useful for M6 (offshore) predicting coastal stations.
#'
#' @param data Data frame with columns: time, station_id, and the variable
#' @param predictor_station Station to use as predictor (e.g., "M6")
#' @param target_station Station to predict (e.g., "M2")
#' @param variable Variable to predict (default: "wave_height")
#' @param lag_hours Lag in hours (positive = predictor leads target)
#'
#' @return List with:
#'   - model: lm object
#'   - r_squared: R-squared of prediction
#'   - rmse: Root mean squared error
#'   - predictions: data frame with actual and predicted values
#'
#' @export
predict_station_lagged <- function(
    data,
    predictor_station,
    target_station,
    variable = "wave_height",
    lag_hours = NULL
) {
  # If lag not specified, find optimal lag
  if (is.null(lag_hours)) {
    ccf_result <- cross_correlation_stations(
      data, predictor_station, target_station, variable
    )
    lag_hours <- ccf_result$optimal_lag
    cli::cli_alert_info(
      "Using optimal lag of {lag_hours} hours (r = {round(ccf_result$max_correlation, 3)})"
    )
  }

  # Filter to each station
  predictor_data <- data[data$station_id == predictor_station, c("time", variable)]
  target_data <- data[data$station_id == target_station, c("time", variable)]

  names(predictor_data) <- c("time", "predictor")
  names(target_data) <- c("time", "target")

  # Shift predictor time forward by lag (predictor leads)
  predictor_data$time_shifted <- predictor_data$time + lag_hours * 3600

  # Merge on shifted time
  merged <- merge(
    predictor_data[, c("time_shifted", "predictor")],
    target_data,
    by.x = "time_shifted",
    by.y = "time",
    all = FALSE
  )
  names(merged)[1] <- "time"

  # Remove NAs
  merged <- merged[complete.cases(merged), ]

  if (nrow(merged) < 100) {
    cli::cli_alert_warning("Insufficient data for prediction model")
    return(list(error = "Insufficient data"))
  }

  # Fit simple linear model
  model <- stats::lm(target ~ predictor, data = merged)

  # Calculate metrics
  predictions <- stats::predict(model, merged)
  residuals <- merged$target - predictions
  rmse <- sqrt(mean(residuals^2))
  r_squared <- summary(model)$r.squared

  list(
    model = model,
    r_squared = r_squared,
    rmse = rmse,
    lag_hours = lag_hours,
    predictor_station = predictor_station,
    target_station = target_station,
    variable = variable,
    n_obs = nrow(merged),
    predictions = data.frame(
      time = merged$time,
      actual = merged$target,
      predicted = predictions,
      residual = residuals
    )
  )
}

#' Fit Bivariate Copula for Joint Extremes
#'
#' @description
#' Fits a copula model to capture the joint dependence structure between
#' two stations, especially in the tails (extremes).
#'
#' @param data Data frame with columns: time, station_id, and the variable
#' @param station1,station2 Station IDs to analyze
#' @param variable Variable to analyze (default: "wave_height")
#' @param copula_family Copula family: "gaussian", "t", "clayton", "gumbel", "frank"
#'

#' @return List with:
#'   - copula: fitted copula object
#'   - parameters: copula parameters
#'   - tau: Kendall's tau (rank correlation)
#'   - tail_dependence: lower and upper tail dependence coefficients
#'
#' @export
fit_bivariate_copula <- function(
    data,
    station1,
    station2,
    variable = "wave_height",
    copula_family = "gumbel"
) {
  if (!requireNamespace("copula", quietly = TRUE)) {
    cli::cli_abort("Package 'copula' is required. Add it to your Nix environment.")
  }

  # Filter to each station
  data1 <- data[data$station_id == station1, c("time", variable)]
  data2 <- data[data$station_id == station2, c("time", variable)]

  names(data1) <- c("time", "value1")
  names(data2) <- c("time", "value2")

  # Merge on time
  merged <- merge(data1, data2, by = "time", all = FALSE)
  merged <- merged[complete.cases(merged), ]

  if (nrow(merged) < 500) {
    cli::cli_alert_warning("Insufficient data for copula fitting")
    return(list(error = "Insufficient data"))
  }

  cli::cli_progress_step(
    "Fitting {copula_family} copula to {station1}-{station2} ({nrow(merged)} obs)"
  )

  # Transform to pseudo-observations (empirical CDF, scaled to (0,1))
  u1 <- rank(merged$value1) / (nrow(merged) + 1)
  u2 <- rank(merged$value2) / (nrow(merged) + 1)
  pseudo_obs <- cbind(u1, u2)

  # Create copula object
  cop <- switch(
    copula_family,
    "gaussian" = copula::normalCopula(dim = 2),
    "t" = copula::tCopula(dim = 2),
    "clayton" = copula::claytonCopula(dim = 2),
    "gumbel" = copula::gumbelCopula(dim = 2),
    "frank" = copula::frankCopula(dim = 2),
    cli::cli_abort("Unknown copula family: {copula_family}")
  )

  # Fit copula
  fit <- copula::fitCopula(cop, pseudo_obs, method = "ml")

  # Extract parameters
  params <- copula::coef(fit)

  # Calculate Kendall's tau
  tau <- copula::tau(fit@copula)

  # Tail dependence (only meaningful for some copulas)
  tail_dep <- tryCatch(
    {
      lambda <- copula::lambda(fit@copula)
      list(lower = lambda[1], upper = lambda[2])
    },
    error = function(e) list(lower = NA, upper = NA)
  )

  cli::cli_alert_success(
    "Copula fit: tau = {round(tau, 3)}, upper tail dep = {round(tail_dep$upper, 3)}"
  )

  list(
    copula = fit,
    copula_family = copula_family,
    parameters = params,
    tau = tau,
    tail_dependence = tail_dep,
    station1 = station1,
    station2 = station2,
    variable = variable,
    n_obs = nrow(merged),
    pseudo_obs = pseudo_obs
  )
}

#' Analyze Joint Extremes Between Stations
#'
#' @description
#' Analyzes how often extreme events co-occur at multiple stations.
#'
#' @param data Data frame with columns: time, station_id, and the variable
#' @param variable Variable to analyze (default: "wave_height")
#' @param threshold_quantile Quantile threshold for "extreme" (default: 0.95)
#'
#' @return List with:
#'   - joint_extreme_counts: matrix of joint extreme event counts
#'   - conditional_probs: P(station j extreme | station i extreme)
#'   - extreme_events: data frame of all extreme events
#'
#' @export
analyze_joint_extremes <- function(
    data,
    variable = "wave_height",
    threshold_quantile = 0.95
) {
  stations <- sort(unique(data$station_id))

  # Calculate threshold per station
  thresholds <- tapply(
    data[[variable]],
    data$station_id,
    function(x) stats::quantile(x, threshold_quantile, na.rm = TRUE)
  )

  # Flag extreme observations
  data$is_extreme <- mapply(
    function(val, station) {
      if (is.na(val)) return(FALSE)
      val >= thresholds[station]
    },
    data[[variable]],
    data$station_id
  )

  # Pivot to wide format (one column per station)
  extreme_wide <- stats::reshape(
    as.data.frame(data[, c("time", "station_id", "is_extreme")]),
    direction = "wide",
    idvar = "time",
    timevar = "station_id",
    v.names = "is_extreme"
  )
  names(extreme_wide) <- gsub("is_extreme\\.", "", names(extreme_wide))

  # Count joint extremes for each pair
  n_stations <- length(stations)
  joint_counts <- matrix(0, n_stations, n_stations)
  rownames(joint_counts) <- stations
  colnames(joint_counts) <- stations

  for (i in seq_along(stations)) {
    for (j in seq_along(stations)) {
      si <- stations[i]
      sj <- stations[j]
      if (si %in% names(extreme_wide) && sj %in% names(extreme_wide)) {
        joint_counts[i, j] <- sum(
          extreme_wide[[si]] & extreme_wide[[sj]],
          na.rm = TRUE
        )
      }
    }
  }

  # Calculate conditional probabilities
  # P(j extreme | i extreme) = count(both extreme) / count(i extreme)
  marginal_counts <- diag(joint_counts)
  cond_probs <- joint_counts / marginal_counts

  # Identify all extreme events with station info
  extreme_events <- data[data$is_extreme, c("time", "station_id", variable)]
  extreme_events <- extreme_events[order(extreme_events$time), ]

  list(
    joint_extreme_counts = joint_counts,
    conditional_probs = round(cond_probs, 3),
    marginal_counts = marginal_counts,
    threshold_quantile = threshold_quantile,
    thresholds = thresholds,
    extreme_events = extreme_events,
    n_joint_any = sum(rowSums(extreme_wide[, stations], na.rm = TRUE) > 1)
  )
}

#' Create Joint Analysis Summary
#'
#' @description
#' Comprehensive summary of joint dependencies across all stations.
#'
#' @param data Data frame with buoy data
#' @param variable Variable to analyze (default: "wave_height")
#'
#' @return List containing all joint analysis results
#' @export
joint_analysis_summary <- function(data, variable = "wave_height") {
  cli::cli_h1("Joint Distribution Analysis")

  # Station info and distances
  station_info <- get_station_info()
  dist_matrix <- station_distance_matrix(station_info)

  cli::cli_h2("Cross-Correlations")
  pair_analysis <- analyze_station_pairs(data, variable)

  cli::cli_h2("Joint Extremes")
  joint_extremes <- analyze_joint_extremes(data, variable)

  cli::cli_h2("M6 Prediction Models")
  # M6 is furthest offshore - test if it predicts others
  m6_predictions <- lapply(c("M2", "M3", "M4", "M5"), function(target) {
    tryCatch(
      predict_station_lagged(data, "M6", target, variable),
      error = function(e) list(error = e$message)
    )
  })
  names(m6_predictions) <- c("M2", "M3", "M4", "M5")

  list(
    station_info = station_info,
    distance_matrix = dist_matrix,
    pair_correlations = pair_analysis,
    joint_extremes = joint_extremes,
    m6_predictions = m6_predictions,
    variable = variable
  )
}

#' Compute Pairwise Extremal Dependence Across Stations
#'
#' @description
#' Estimates the upper tail dependence coefficient (lambda_U) for all unique
#' station pairs using a Gumbel copula. For Gumbel copula with parameter alpha,
#' lambda_U = 2 - 2^(1/alpha). Bootstrap confidence intervals assess whether
#' lambda_U is significantly greater than zero (H1: spatial coherence of extremes).
#'
#' Also computes empirical chi statistics at multiple quantile levels and
#' Kendall's tau for overall rank dependence.
#'
#' @param data Data frame with columns: `time` (POSIXct), `station_id` (character),
#'   and the variable specified by `variable`.
#' @param variable Variable to analyze (default: `"wave_height"`).
#' @param threshold_quantile Quantile levels at which to compute empirical chi
#'   (default: `seq(0.9, 0.99, by = 0.01)`).
#' @param n_bootstrap Number of bootstrap replicates for lambda CI (default: 100).
#' @param boot_subsample Maximum observations per bootstrap replicate. Subsampling
#'   speeds computation for large datasets (default: 5000).
#' @param station_info Optional data frame with station metadata (from
#'   [get_station_info()]). If `NULL`, uses the default 5-station network.
#'
#' @return List with:
#'   \describe{
#'     \item{dependence_table}{Data frame with columns: `station1`, `station2`,
#'       `distance_km`, `kendall_tau`, `lambda_upper`, `lambda_lower`,
#'       `lambda_upper_ci_low`, `lambda_upper_ci_high`, `n_concurrent`,
#'       `copula_alpha`, `chi_q95`, `chi_q99`, `h1_significant` (logical).}
#'     \item{method}{Character: `"gumbel_copula"`.}
#'     \item{n_bootstrap}{Integer: number of bootstrap replicates used.}
#'     \item{threshold_quantile}{Numeric vector of quantile levels for chi.}
#'   }
#'   If the copula package is unavailable or no valid pairs exist, returns
#'   a list with an `error` field.
#'
#' @family joint-analysis
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, variables = c("time", "station_id", "wave_height"))
#' result <- compute_extremal_dependence(data)
#' result$dependence_table
#' DBI::dbDisconnect(con)
#' }
compute_extremal_dependence <- function(
    data,
    variable = "wave_height",
    threshold_quantile = seq(0.9, 0.99, by = 0.01),
    n_bootstrap = 100,
    boot_subsample = 5000,
    station_info = NULL
) {
  if (!requireNamespace("copula", quietly = TRUE)) {
    cli::cli_abort(c(
      "x" = "Package {.pkg copula} is required for extremal dependence analysis.",
      "i" = "Add {.pkg copula} to your Nix environment."
    ))
  }

  # Validate inputs
  required_cols <- c("time", "station_id", variable)
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

  stations <- sort(unique(data$station_id))
  if (length(stations) < 2) {
    cli::cli_abort(c(
      "x" = "Need at least 2 stations, found {length(stations)}.",
      "i" = "Check {.arg data$station_id}."
    ))
  }

  pairs <- utils::combn(stations, 2, simplify = FALSE)
  cli::cli_alert_info(
    "Computing extremal dependence for {length(pairs)} station pairs ({n_bootstrap} bootstrap replicates)"
  )

  results <- lapply(pairs, function(pair) {
    s1 <- pair[1]
    s2 <- pair[2]

    # Align observations by time
    d1 <- data[data$station_id == s1, c("time", variable)]
    d2 <- data[data$station_id == s2, c("time", variable)]
    names(d1) <- c("time", "v1")
    names(d2) <- c("time", "v2")

    joined <- merge(d1, d2, by = "time", all = FALSE)
    joined <- joined[stats::complete.cases(joined), ]

    if (nrow(joined) < 100) {
      cli::cli_alert_warning(
        "Skipping {s1}-{s2}: only {nrow(joined)} concurrent observations"
      )
      return(NULL)
    }

    # Empirical chi at quantile levels
    chi_vals <- vapply(threshold_quantile, function(q) {
      u1 <- stats::quantile(joined$v1, q)
      u2 <- stats::quantile(joined$v2, q)
      n_s1_exceed <- sum(joined$v1 > u1)
      if (n_s1_exceed == 0) return(NA_real_)
      sum(joined$v1 > u1 & joined$v2 > u2) / n_s1_exceed
    }, numeric(1))
    names(chi_vals) <- paste0("q", threshold_quantile)

    # Kendall's tau (subsample for speed)
    if (nrow(joined) > 10000) {
      tau_idx <- sample(nrow(joined), 10000)
      tau <- stats::cor(joined$v1[tau_idx], joined$v2[tau_idx], method = "kendall")
    } else {
      tau <- stats::cor(joined$v1, joined$v2, method = "kendall")
    }

    # Fit Gumbel copula for upper tail dependence
    cop_result <- tryCatch({
      u_obs <- copula::pobs(cbind(joined$v1, joined$v2))
      gumbel_fit <- copula::fitCopula(
        copula::gumbelCopula(dim = 2), u_obs, method = "ml"
      )
      alpha <- copula::coef(gumbel_fit)
      lambda_U <- 2 - 2^(1 / alpha)

      # Bootstrap CI for lambda_U
      boot_n <- min(nrow(u_obs), boot_subsample)
      lambda_boot <- replicate(n_bootstrap, {
        idx <- sample(nrow(u_obs), boot_n, replace = TRUE)
        tryCatch({
          fit_b <- copula::fitCopula(
            copula::gumbelCopula(dim = 2), u_obs[idx, ], method = "ml"
          )
          2 - 2^(1 / copula::coef(fit_b))
        }, error = function(e) NA_real_)
      })
      lambda_ci <- stats::quantile(lambda_boot, c(0.025, 0.975), na.rm = TRUE)

      list(
        alpha = alpha,
        lambda_U = lambda_U,
        ci_low = unname(lambda_ci[1]),
        ci_high = unname(lambda_ci[2])
      )
    }, error = function(e) {
      cli::cli_alert_warning("Copula fit failed for {s1}-{s2}: {e$message}")
      list(alpha = NA_real_, lambda_U = NA_real_, ci_low = NA_real_, ci_high = NA_real_)
    })

    # Distance
    dist_km <- if (s1 %in% rownames(dist_matrix) && s2 %in% colnames(dist_matrix)) {
      dist_matrix[s1, s2]
    } else {
      NA_real_
    }

    data.frame(
      station1 = s1,
      station2 = s2,
      distance_km = dist_km,
      kendall_tau = tau,
      lambda_upper = cop_result$lambda_U,
      # Gumbel copula has lambda_L = 0 by construction (upper-tail-only dependence)
      lambda_lower = 0,
      lambda_upper_ci_low = cop_result$ci_low,
      lambda_upper_ci_high = cop_result$ci_high,
      n_concurrent = nrow(joined),
      copula_alpha = cop_result$alpha,
      chi_q95 = chi_vals["q0.95"],
      chi_q99 = chi_vals["q0.99"],
      h1_significant = !is.na(cop_result$ci_low) && cop_result$ci_low > 0,
      stringsAsFactors = FALSE,
      row.names = NULL
    )
  })

  dep_table <- do.call(rbind, Filter(Negate(is.null), results))
  row.names(dep_table) <- NULL

  if (is.null(dep_table) || nrow(dep_table) == 0) {
    return(list(
      dependence_table = data.frame(),
      method = "gumbel_copula",
      n_bootstrap = n_bootstrap,
      threshold_quantile = threshold_quantile,
      error = "No valid station pairs with sufficient concurrent data"
    ))
  }

  n_sig <- sum(dep_table$h1_significant, na.rm = TRUE)
  cli::cli_alert_success(
    "{n_sig}/{nrow(dep_table)} pairs show significant positive extremal dependence (lambda CI > 0)"
  )

  list(
    dependence_table = dep_table,
    method = "gumbel_copula",
    n_bootstrap = n_bootstrap,
    threshold_quantile = threshold_quantile
  )
}
