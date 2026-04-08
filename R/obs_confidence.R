#' Observation Freshness and Confidence Decay
#'
#' @description
#' Helpers that translate "how old is the latest observation" into a unit-scale
#' confidence multiplier and provide a way to widen any existing CI as obs age.
#'
#' Used by `dash_vignette_scalars` (Option E from the rogue-wave forecasting
#' plan) so the dashboard can visibly de-rate observation-derived risk metrics
#' when the buoy data is stale (e.g. M6 currently lags by ~2 days).
#'
#' @name obs_confidence
#' @keywords internal
NULL

#' Confidence Multiplier from Observation Age
#'
#' @description
#' Maps observation age in hours to a confidence multiplier in `(0, 1]`.
#' Confidence is 1.0 while data is fresh, then decays linearly between
#' breakpoints. Floor of 0.1 — we never claim zero information.
#'
#' Default schedule (chosen to match the buoy fetch cadence):
#' \itemize{
#'   \item   0 -  6 h : 1.00 (well within the 6-h fetch cycle)
#'   \item   6 - 24 h : 1.00 -> 0.50 (one missed fetch up to one day)
#'   \item  24 - 72 h : 0.50 -> 0.25 (one to three missed days)
#'   \item    > 72 h  : 0.10 (floor)
#' }
#'
#' @param age_hours Numeric vector of ages in hours. NA in -> NA out.
#'
#' @return Numeric vector in `[0.1, 1]`, same length as `age_hours`.
#' @export
#' @family obs-confidence
#' @examples
#' compute_obs_confidence(c(0, 6, 12, 24, 48, 72, 168))
compute_obs_confidence <- function(age_hours) {
  out <- rep(NA_real_, length(age_hours))
  ok <- !is.na(age_hours) & is.finite(age_hours)
  if (!any(ok)) return(out)
  a <- pmax(age_hours[ok], 0)
  conf <- ifelse(
    a <= 6,
    1.0,
    ifelse(
      a <= 24,
      1.0 - 0.5 * (a - 6) / (24 - 6),
      ifelse(
        a <= 72,
        0.5 - 0.25 * (a - 24) / (72 - 24),
        0.10
      )
    )
  )
  out[ok] <- pmax(pmin(conf, 1), 0.1)
  out
}

#' Status Label from Observation Confidence
#'
#' @description
#' Maps a confidence multiplier to a short human-readable status label and a
#' suggested colour for dashboard badges.
#'
#' @param confidence Numeric vector of confidence values in `[0.1, 1]`.
#'
#' @return List with `label` (character) and `color` (character hex), both the
#'   same length as `confidence`.
#' @export
#' @family obs-confidence
#' @examples
#' obs_status_label(c(1, 0.7, 0.4, 0.15))
obs_status_label <- function(confidence) {
  label <- dplyr::case_when(
    is.na(confidence) ~ NA_character_,
    confidence >= 0.9 ~ "fresh",
    confidence >= 0.6 ~ "ageing",
    confidence >= 0.3 ~ "stale",
    .default = "very stale"
  )
  color <- dplyr::case_when(
    is.na(confidence) ~ NA_character_,
    confidence >= 0.9 ~ "#2e7d32",  # green
    confidence >= 0.6 ~ "#f9a825",  # amber
    confidence >= 0.3 ~ "#e65100",  # dark orange
    .default = "#b71c1c"            # dark red
  )
  list(label = label, color = color)
}

#' Widen a Confidence Interval by an Obs-Confidence Factor
#'
#' @description
#' Inflates the half-width of an existing CI by `1 / confidence`. Useful when
#' the underlying point estimate is from observations and you want the
#' displayed band to grow as the data ages, *without* refitting the model.
#'
#' This is a heuristic display device, not a proper Bayesian update. It
#' preserves the median estimate and only stretches the band. Stretching is
#' applied symmetrically about the point estimate.
#'
#' @param point Numeric vector of point estimates.
#' @param lower Numeric vector of original CI lower bounds.
#' @param upper Numeric vector of original CI upper bounds.
#' @param confidence Numeric multiplier in `(0, 1]` (e.g. from
#'   [compute_obs_confidence()]). Vectorised — recycled to length of `point`.
#'
#' @return List with `lower` and `upper` numeric vectors, widened symmetrically
#'   about `point`.
#' @export
#' @family obs-confidence
#' @examples
#' widen_ci(point = 10, lower = 8, upper = 12, confidence = 0.5)
widen_ci <- function(point, lower, upper, confidence) {
  n <- length(point)
  conf_v <- rep_len(confidence, n)
  lo_v <- rep_len(lower, n)
  hi_v <- rep_len(upper, n)
  half_lo <- point - lo_v
  half_hi <- hi_v - point
  scale <- 1 / pmax(conf_v, 0.1)
  list(
    lower = point - half_lo * scale,
    upper = point + half_hi * scale
  )
}
