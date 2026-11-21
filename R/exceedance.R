#' Exceedance model helpers
#'
#' @description
#' One exceedance model, one home: [p_hmax_exceedance()] (Forristall 1978
#' Weibull wave heights, Rayleigh as a special case). This file holds what the
#' observed-record plots need around it: the record duration, the rogue-wave
#' ratio thresholds and the pre-plot data checks.
#'
#' @name exceedance
#' @keywords internal
NULL

#' Duration of one buoy wave record
#'
#' @description
#' The one named home for the length of an observed wave record: 17.5 minutes
#' (1050 s), the lower bound the Marine Institute uses for the Irish Weather
#' Buoy Network (see [explain_measurement_period()] in `R/wave_science.R`).
#' The number of waves in a record is `N = duration / mean period`.
#'
#' Callers that evaluate [p_hmax_exceedance()] on observed records pass this as
#' `duration_s`. The 3600 s default of [p_hmax_exceedance()] is for forecast
#' hours only.
#'
#' @return Record duration in seconds (a single number).
#' @export
#' @family storm-alert
#' @examples
#' ib_record_duration_s()
ib_record_duration_s <- function() {
  17.5 * 60
}

# Hmax / Hs definitions of a rogue wave (2.0) and an extreme rogue wave (2.2).
# The 2.0 value is also the `threshold` default of detect_rogue_waves().
ib_rogue_ratio_thresholds <- function() {
  c(rogue = 2.0, extreme = 2.2)
}

# Forristall parameters of the Rayleigh special case.
.ib_rayleigh <- function() {
  list(alpha = 1 / sqrt(2), beta = 2)
}

# P(Hmax > h) and its natural log, numerically stable. Inputs are equal-length
# vectors with hs > 0 and tz > 0 (no NA). `p` is computed as
# -expm1(N * log1p(-p1)); where the single-wave probability p1 underflows to 0,
# N * p1 is used and `log_p` carries the value, so a ratio of 8.1 gives a tiny
# positive p instead of 0.
.ib_hmax_exceed <- function(h, hs, tz, duration_s, alpha, beta) {
  n_waves <- duration_s / tz
  log_p1 <- -(pmax(h, 0) / (alpha * hs))^beta
  p1 <- exp(log_p1)
  p <- -expm1(n_waves * log1p(-p1))
  log_p <- log(p)
  tiny <- p1 == 0
  if (any(tiny)) {
    log_p[tiny] <- log(n_waves[tiny]) + log_p1[tiny]
    p[tiny] <- exp(log_p[tiny])
  }
  data.frame(p = p, log_p = log_p)
}

# Pre-plot data checks and the model output per record.
# `data` needs time, station_id, wave_height, hmax and wave_period; a qc_flag
# column is used when present (0 = unchecked and 1 = good pass; anything else
# is suspect, #114). Returns the cleaned records with ratio, n_waves,
# nlog10_p (-log10 p) and suspect, plus the counts behind the figure caption.
.ib_exceedance_prep <- function(data, duration_s = ib_record_duration_s()) {
  required <- c("time", "station_id", "wave_height", "hmax", "wave_period")
  if (!is.data.frame(data) || !all(required %in% names(data))) {
    missing_cols <- setdiff(required, names(data))
    cli::cli_abort(c(
      "x" = "{.arg data} must be a data frame with columns {.field {required}}.",
      "i" = "Missing: {.field {missing_cols}}."
    ))
  }
  n_input <- nrow(data)
  has_na <- is.na(data$time) | is.na(data$station_id) | is.na(data$wave_height) |
    is.na(data$hmax) | is.na(data$wave_period)
  kept <- data[!has_na, , drop = FALSE]
  computable <- kept$wave_height > 0 & kept$wave_period > 0
  n_not_computable <- sum(!computable)
  kept <- kept[computable, , drop = FALSE]

  checks <- list(
    n_input = as.integer(n_input),
    n_na_dropped = as.integer(sum(has_na)),
    n_not_computable = as.integer(n_not_computable),
    n_hmax_lt_hs = as.integer(sum(kept$hmax < kept$wave_height)),
    n_ratio_gt_3 = as.integer(sum(kept$hmax / kept$wave_height > 3)),
    n_plotted = nrow(kept)
  )

  out <- kept[, required, drop = FALSE]
  out$suspect <- if ("qc_flag" %in% names(kept)) {
    !is.na(kept$qc_flag) & !(kept$qc_flag %in% c(0L, 1L))
  } else {
    rep(FALSE, nrow(kept))
  }
  out$ratio <- kept$hmax / kept$wave_height
  out$n_waves <- duration_s / kept$wave_period
  if (nrow(out) > 0L) {
    fit <- .ib_hmax_exceed(
      kept$hmax, kept$wave_height, kept$wave_period, duration_s,
      alpha = 0.681, beta = 2.126
    )
    out$nlog10_p <- -fit$log_p / log(10)
  } else {
    out$nlog10_p <- numeric(0)
  }
  out <- out[order(out$station_id, out$time), , drop = FALSE]
  rownames(out) <- NULL

  checks$caption <- paste0(
    "Data checks: ", checks$n_input, " records read; ",
    checks$n_na_dropped, " dropped for NA values and ",
    checks$n_not_computable, " with Hs or period <= 0; ",
    checks$n_hmax_lt_hs, " with Hmax < Hs and ",
    checks$n_ratio_gt_3, " with Hmax/Hs > 3 kept (flagged, not dropped)."
  )
  list(data = out, checks = checks, caption = checks$caption)
}

# Gust / sustained-wind ratio above which a gust is rogue (the definition used
# by the rogue_gust_events target and the gust-ratio plot).
ib_rogue_gust_threshold <- function() {
  1.5
}
