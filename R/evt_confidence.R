#' Order-Statistics Confidence Intervals for Quantiles
#'
#' @description
#' Distribution-free confidence intervals for population quantiles using
#' order statistics. Uses the Beta distribution to find order-statistic
#' indices j,k such that `(X_(j), X_(k))` covers the p-th quantile with
#' at least the specified confidence level.
#'
#' @param x Numeric vector of observations (NAs removed internally).
#' @param probs Numeric vector of probabilities for which to compute CIs
#'   (e.g. `c(0.95, 0.99)`).
#' @param conf_level Confidence level (default 0.95).
#'
#' @return A data.frame with columns: `probability`, `quantile`, `lower`,
#'   `upper`, `j`, `k`, `actual_coverage`, `method`.
#'
#' @details
#' For a sample of size n, the probability that the interval `(X_(j), X_(k))`
#' contains the p-th quantile is `pbeta(p, j, n-j+1) - pbeta(p, k, n-k+1)`.
#' We search for the tightest such interval achieving at least `conf_level`
#' coverage.
#'
#' This method is distribution-free: it requires no parametric assumptions.
#' With ~8 years of hourly data (~70k observations), order-statistic CIs are
#' well-defined even for extreme quantiles like the 99th percentile.
#'
#' @export
#' @examples
#' set.seed(42)
#' x <- rnorm(1000)
#' ci_order_statistics(x, probs = c(0.95, 0.99))
ci_order_statistics <- function(x, probs, conf_level = 0.95) {
  x <- x[!is.na(x)]
  n <- length(x)

  if (n < 10) {
    return(data.frame(
      probability = probs,
      quantile = NA_real_,
      lower = NA_real_,
      upper = NA_real_,
      j = NA_integer_,
      k = NA_integer_,
      actual_coverage = NA_real_,
      method = "order_statistics",
      stringsAsFactors = FALSE
    ))
  }

  x_sorted <- sort(x)

  results <- lapply(probs, function(p) {
    # Point estimate
    q_hat <- stats::quantile(x, p, names = FALSE)

    # Find tightest (j, k) interval with coverage >= conf_level
    # Start from the expected index and search outward
    r <- floor(n * p) + 1
    r <- max(1, min(r, n))

    best_j <- NA_integer_
    best_k <- NA_integer_
    best_width <- Inf
    best_coverage <- 0

    # Search a reasonable range around the expected index
    half_range <- max(10, ceiling(3 * sqrt(n * p * (1 - p))))
    j_min <- max(1, r - half_range)
    k_max <- min(n, r + half_range)

    for (j in j_min:(r)) {
      for (k in (r):k_max) {
        if (k <= j) next
        # Coverage: P(X_(j) <= Q_p <= X_(k))
        coverage <- stats::pbeta(p, j, n - j + 1) -
          stats::pbeta(p, k, n - k + 1)
        if (coverage >= conf_level) {
          width <- x_sorted[k] - x_sorted[j]
          if (width < best_width) {
            best_j <- j
            best_k <- k
            best_width <- width
            best_coverage <- coverage
          }
        }
      }
    }

    data.frame(
      probability = p,
      quantile = q_hat,
      lower = if (!is.na(best_j)) x_sorted[best_j] else NA_real_,
      upper = if (!is.na(best_k)) x_sorted[best_k] else NA_real_,
      j = best_j,
      k = best_k,
      actual_coverage = best_coverage,
      method = "order_statistics",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}

#' Bootstrap Confidence Intervals for GPD Return Levels
#'
#' @description
#' Non-parametric bootstrap (optionally block bootstrap) confidence intervals
#' for GPD-based return levels. Resamples the raw data, refits the GPD, and
#' computes return levels for each replicate.
#'
#' @param data Data frame containing the variable to analyse.
#' @param variable Character name of the column (e.g. `"wave_height"`).
#' @param return_periods Numeric vector of return periods in years
#'   (default `c(1, 5, 10)`).
#' @param n_boot Number of bootstrap replicates (default 500).
#' @param conf_level Confidence level (default 0.95).
#' @param block_size Integer block size for block bootstrap (observations, not
#'   hours). `NULL` or 0 for iid bootstrap. Use 48 for hourly data
#'   (2-day blocks) to preserve temporal dependence.
#' @param threshold_quantile Quantile for the POT threshold (default 0.95).
#' @param n_obs_per_year Observations per year for return level calculation
#'   (default 8760 for hourly).
#' @param seed Random seed for reproducibility (default 42).
#'
#' @return A data.frame with columns: `return_period`, `return_level`,
#'   `lower`, `upper`, `n_success`, `method`.
#'
#' @details
#' For each bootstrap replicate:
#' 1. Resample observations (iid or block bootstrap)
#' 2. Compute the threshold as the `threshold_quantile` of the resample
#' 3. Fit GPD via [mev::fit.gpd()] to exceedances
#' 4. Compute return levels via [calculate_gpd_return_levels()]
#'
#' The percentile method is used: CIs are the `alpha/2` and `1-alpha/2`
#' quantiles of the bootstrap distribution of return levels.
#'
#' @export
ci_bootstrap_return_levels <- function(
    data,
    variable,
    return_periods = c(1, 5, 10),
    n_boot = 500,
    conf_level = 0.95,
    block_size = NULL,
    threshold_quantile = 0.95,
    n_obs_per_year = 8760,
    seed = 42
) {
  if (!requireNamespace("mev", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg mev} is required for bootstrap CIs.")
  }

  vals <- data[[variable]]
  vals <- vals[!is.na(vals)]
  n <- length(vals)

  if (n < 100) {
    return(data.frame(
      return_period = return_periods,
      return_level = NA_real_,
      lower = NA_real_,
      upper = NA_real_,
      n_success = 0L,
      method = "bootstrap",
      stringsAsFactors = FALSE
    ))
  }

  set.seed(seed)
  alpha <- 1 - conf_level

  # Pre-allocate bootstrap return level matrix: n_boot x length(return_periods)
  boot_rl <- matrix(NA_real_, nrow = n_boot, ncol = length(return_periods))
  use_blocks <- !is.null(block_size) && block_size > 1

  for (b in seq_len(n_boot)) {
    # Resample
    if (use_blocks) {
      # Block bootstrap: sample contiguous blocks
      n_blocks <- ceiling(n / block_size)
      block_starts <- sample.int(n - block_size + 1, n_blocks, replace = TRUE)
      idx <- unlist(lapply(block_starts, function(s) s:(s + block_size - 1)))
      idx <- idx[idx <= n]
      boot_vals <- vals[idx[seq_len(min(length(idx), n))]]
    } else {
      boot_vals <- sample(vals, n, replace = TRUE)
    }

    # Fit GPD to bootstrap sample
    u <- stats::quantile(boot_vals, threshold_quantile, names = FALSE)
    exceedances <- boot_vals[boot_vals > u]

    if (length(exceedances) < 30) next

    tryCatch({
      fit <- mev::fit.gpd(xdat = exceedances, threshold = u)
      gpd_list <- list(
        u = u,
        scale = fit$estimate["scale"],
        shape = fit$estimate["shape"],
        n_exceed = length(exceedances)
      )
      rl <- calculate_gpd_return_levels(
        gpd_list,
        return_periods = return_periods,
        n_obs_per_year = n_obs_per_year,
        conf_level = conf_level
      )
      boot_rl[b, ] <- rl$return_level
    }, error = function(e) NULL)
  }

  # Compute point estimate from original data
  u_orig <- stats::quantile(vals, threshold_quantile, names = FALSE)
  exc_orig <- vals[vals > u_orig]
  fit_orig <- tryCatch(
    mev::fit.gpd(xdat = exc_orig, threshold = u_orig),
    error = function(e) NULL
  )

  if (!is.null(fit_orig)) {
    gpd_orig <- list(
      u = u_orig,
      scale = fit_orig$estimate["scale"],
      shape = fit_orig$estimate["shape"],
      n_exceed = length(exc_orig)
    )
    rl_orig <- calculate_gpd_return_levels(
      gpd_orig,
      return_periods = return_periods,
      n_obs_per_year = n_obs_per_year
    )
    point_est <- rl_orig$return_level
  } else {
    point_est <- rep(NA_real_, length(return_periods))
  }

  # Percentile CIs from bootstrap distribution
  results <- lapply(seq_along(return_periods), function(i) {
    boot_vals_i <- boot_rl[, i]
    boot_vals_i <- boot_vals_i[!is.na(boot_vals_i)]
    n_success <- length(boot_vals_i)

    if (n_success < 10) {
      return(data.frame(
        return_period = return_periods[i],
        return_level = point_est[i],
        lower = NA_real_,
        upper = NA_real_,
        n_success = n_success,
        method = "bootstrap",
        stringsAsFactors = FALSE
      ))
    }

    data.frame(
      return_period = return_periods[i],
      return_level = point_est[i],
      lower = stats::quantile(boot_vals_i, alpha / 2, names = FALSE),
      upper = stats::quantile(boot_vals_i, 1 - alpha / 2, names = FALSE),
      n_success = n_success,
      method = "bootstrap",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}

#' Parametric Bootstrap CIs for GPD Return Levels
#'
#' @description
#' Simulate from a fitted GPD, refit, and compute return levels to
#' obtain parametric bootstrap confidence intervals.
#'
#' @param gpd_fit A list with elements `u`, `scale`, `shape`, `n_exceed`
#'   (as returned by the per-station GPD targets).
#' @param n_boot Number of bootstrap replicates (default 500).
#' @param return_periods Numeric vector of return periods in years.
#' @param conf_level Confidence level (default 0.95).
#' @param n_obs_per_year Observations per year (default 8760).
#' @param seed Random seed (default 42).
#'
#' @return A data.frame with columns: `return_period`, `return_level`,
#'   `lower`, `upper`, `n_success`, `method`.
#'
#' @details
#' For each replicate:
#' 1. Simulate `n_exceed` exceedances from GPD(scale, shape)
#' 2. Add threshold to obtain values above `u`
#' 3. Refit GPD via [mev::fit.gpd()]
#' 4. Compute return levels
#'
#' Uses the percentile method for CIs.
#'
#' @export
ci_parametric_bootstrap <- function(
    gpd_fit,
    n_boot = 500,
    return_periods = c(1, 5, 10),
    conf_level = 0.95,
    n_obs_per_year = 8760,
    seed = 42
) {
  if (!requireNamespace("mev", quietly = TRUE)) {
    cli::cli_abort("Package {.pkg mev} is required for parametric bootstrap CIs.")
  }

  # Validate input

  if (!is.list(gpd_fit) || !is.null(gpd_fit$error) ||
      is.null(gpd_fit$scale) || is.null(gpd_fit$shape)) {
    return(data.frame(
      return_period = return_periods,
      return_level = NA_real_,
      lower = NA_real_,
      upper = NA_real_,
      n_success = 0L,
      method = "parametric_bootstrap",
      stringsAsFactors = FALSE
    ))
  }

  u <- as.numeric(gpd_fit$u)
  sigma <- as.numeric(gpd_fit$scale)
  xi <- as.numeric(gpd_fit$shape)
  n_exceed <- gpd_fit$n_exceed

  set.seed(seed)
  alpha <- 1 - conf_level

  # Point estimate from original fit
  rl_orig <- calculate_gpd_return_levels(
    gpd_fit,
    return_periods = return_periods,
    n_obs_per_year = n_obs_per_year
  )
  point_est <- rl_orig$return_level

  # Bootstrap
  boot_rl <- matrix(NA_real_, nrow = n_boot, ncol = length(return_periods))

  for (b in seq_len(n_boot)) {
    # Simulate GPD exceedances
    if (abs(xi) < 1e-6) {
      sim_exc <- stats::rexp(n_exceed, rate = 1 / sigma)
    } else {
      # GPD quantile function: sigma/xi * ((1-u)^(-xi) - 1)
      sim_u <- stats::runif(n_exceed)
      sim_exc <- (sigma / xi) * ((1 - sim_u)^(-xi) - 1)
    }

    # Values above threshold
    sim_vals <- sim_exc + u

    tryCatch({
      fit <- mev::fit.gpd(xdat = sim_vals, threshold = u)
      gpd_list <- list(
        u = u,
        scale = fit$estimate["scale"],
        shape = fit$estimate["shape"],
        n_exceed = n_exceed
      )
      rl <- calculate_gpd_return_levels(
        gpd_list,
        return_periods = return_periods,
        n_obs_per_year = n_obs_per_year
      )
      boot_rl[b, ] <- rl$return_level
    }, error = function(e) NULL)
  }

  # Percentile CIs
  results <- lapply(seq_along(return_periods), function(i) {
    boot_vals_i <- boot_rl[, i]
    boot_vals_i <- boot_vals_i[!is.na(boot_vals_i)]
    n_success <- length(boot_vals_i)

    if (n_success < 10) {
      return(data.frame(
        return_period = return_periods[i],
        return_level = point_est[i],
        lower = NA_real_,
        upper = NA_real_,
        n_success = n_success,
        method = "parametric_bootstrap",
        stringsAsFactors = FALSE
      ))
    }

    data.frame(
      return_period = return_periods[i],
      return_level = point_est[i],
      lower = stats::quantile(boot_vals_i, alpha / 2, names = FALSE),
      upper = stats::quantile(boot_vals_i, 1 - alpha / 2, names = FALSE),
      n_success = n_success,
      method = "parametric_bootstrap",
      stringsAsFactors = FALSE
    )
  })

  do.call(rbind, results)
}
