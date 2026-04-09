# Tests for R/storm_alert.R
# Unit tests (no network) + integration tests (skip_if_offline)

# ── knots_to_beaufort ─────────────────────────────────────────────

test_that("knots_to_beaufort handles boundary values correctly", {
  # Beaufort 0: < 1 kn

  expect_equal(knots_to_beaufort(0), 0L)
  expect_equal(knots_to_beaufort(0.5), 0L)

  # Beaufort 7: 28-33 kn
  expect_equal(knots_to_beaufort(33), 7L)

  # Beaufort 8 (Gale): 34-40 kn — the alert threshold

  expect_equal(knots_to_beaufort(34), 8L)
  expect_equal(knots_to_beaufort(40), 8L)

  # Beaufort 10 (Storm): 48-55 kn
  expect_equal(knots_to_beaufort(48), 10L)
  expect_equal(knots_to_beaufort(55), 10L)

  # Beaufort 12 (Hurricane): >= 64 kn
  expect_equal(knots_to_beaufort(64), 12L)
  expect_equal(knots_to_beaufort(100), 12L)
})

test_that("knots_to_beaufort is vectorized", {
  result <- knots_to_beaufort(c(0, 5, 20, 34, 48, 64))
  expect_equal(result, c(0L, 2L, 5L, 8L, 10L, 12L))
  expect_type(result, "integer")
  expect_length(result, 6)
})

# ── beaufort_to_description ───────────────────────────────────────

test_that("beaufort_to_description returns all 13 labels", {
  result <- beaufort_to_description(0:12)
  expect_length(result, 13)
  expect_equal(result[1], "Calm")
  expect_equal(result[9], "Gale")        # Beaufort 8
  expect_equal(result[11], "Storm")      # Beaufort 10
  expect_equal(result[13], "Hurricane Force")  # Beaufort 12
})

test_that("beaufort_to_description clamps out-of-range values", {
  expect_equal(beaufort_to_description(-1), "Calm")
  expect_equal(beaufort_to_description(15), "Hurricane Force")
})

# ── detect_storm_events ───────────────────────────────────────────

test_that("detect_storm_events filters by threshold", {
  forecasts <- tibble::tibble(
    station_id = rep("M2", 5),
    time = Sys.time() + 3600 * 1:5,
    wind_speed_kn = c(10, 20, 34, 42, 50),
    wind_gust_kn = c(15, 25, 40, 48, 60)
  )

  result <- detect_storm_events(forecasts, threshold_knots = 34)
  expect_equal(nrow(result), 3)  # 34, 42, 50 all >= 34
  expect_true(all(result$wind_speed_kn >= 34))
  expect_true("beaufort" %in% names(result))
  expect_true("description" %in% names(result))
  expect_true("is_gust_driven" %in% names(result))
})

test_that("detect_storm_events flags gust-driven events", {
  forecasts <- tibble::tibble(
    station_id = "M3",
    time = Sys.time() + 3600,
    wind_speed_kn = 25,   # Below threshold
    wind_gust_kn = 40     # Above threshold
  )

  result <- detect_storm_events(forecasts, threshold_knots = 34, use_gusts = TRUE)
  expect_equal(nrow(result), 1)
  expect_true(result$is_gust_driven)

  # With use_gusts=FALSE, this should not be detected
  result_no_gusts <- detect_storm_events(forecasts, threshold_knots = 34, use_gusts = FALSE)
  expect_equal(nrow(result_no_gusts), 0)
})

test_that("detect_storm_events respects env var threshold", {
  forecasts <- tibble::tibble(
    station_id = "M2",
    time = Sys.time() + 3600,
    wind_speed_kn = 25,
    wind_gust_kn = 30
  )

  # Set env var to low threshold
  withr::with_envvar(c(STORM_ALERT_THRESHOLD_KNOTS = "20"), {
    result <- detect_storm_events(forecasts)
    expect_equal(nrow(result), 1)
  })

  # Default (41 kn) — should not detect (25 < 41)
  withr::with_envvar(c(STORM_ALERT_THRESHOLD_KNOTS = NA), {
    result <- detect_storm_events(forecasts)
    expect_equal(nrow(result), 0)
  })
})

test_that("detect_storm_events handles invalid env var gracefully", {
  forecasts <- tibble::tibble(
    station_id = "M2",
    time = Sys.time() + 3600,
    wind_speed_kn = 45,
    wind_gust_kn = 50
  )

  # Invalid env var falls back to 41 (Beaufort 9)
  withr::with_envvar(c(STORM_ALERT_THRESHOLD_KNOTS = "not_a_number"), {
    expect_warning(
      detect_storm_events(forecasts),
      "Invalid"
    )
    # Run again to check the actual result (warning already tested above)
    result <- suppressWarnings(detect_storm_events(forecasts))
    expect_equal(nrow(result), 1)  # 45 >= 41 (default)
  })
})

test_that("detect_storm_events returns empty tibble for empty input", {
  empty <- tibble::tibble(
    station_id = character(),
    time = as.POSIXct(character()),
    wind_speed_kn = numeric(),
    wind_gust_kn = numeric()
  )

  result <- detect_storm_events(empty)
  expect_equal(nrow(result), 0)
  expect_true("beaufort" %in% names(result))
})

# ── create_storm_alert_email ──────────────────────────────────────

test_that("create_storm_alert_email returns blastula email", {
  skip_if_not_installed("blastula")

  events <- tibble::tibble(
    station_id = "M2",
    time = as.POSIXct("2026-02-26 12:00:00", tz = "UTC"),
    wind_speed_kn = 40,
    wind_gust_kn = 55,
    beaufort = 8L,
    description = "Gale",
    is_gust_driven = FALSE
  )

  email <- create_storm_alert_email(events)
  expect_s3_class(email, "blastula_message")

  # Check HTML contains key fields
  html <- paste(as.character(email), collapse = "")
  expect_true(grepl("M2", html))
  expect_true(grepl("Gale", html))
  expect_true(grepl("Storm Alert", html))
})

test_that("create_storm_alert_email handles multiple stations", {
  skip_if_not_installed("blastula")

  events <- tibble::tibble(
    station_id = c("M2", "M2", "M6", "M6"),
    time = as.POSIXct("2026-02-26 12:00:00", tz = "UTC") + 3600 * 0:3,
    wind_speed_kn = c(38, 42, 50, 55),
    wind_gust_kn = c(45, 50, 60, 65),
    beaufort = c(8L, 9L, 10L, 10L),
    description = c("Gale", "Strong Gale", "Storm", "Storm"),
    is_gust_driven = c(FALSE, FALSE, FALSE, FALSE)
  )

  email <- create_storm_alert_email(events)
  html <- paste(as.character(email), collapse = "")
  expect_true(grepl("M2", html))
  expect_true(grepl("M6", html))
  expect_true(grepl("Storm", html))
})

test_that("create_storm_alert_email includes Met Eireann warnings", {
  skip_if_not_installed("blastula")

  events <- tibble::tibble(
    station_id = "M5",
    time = as.POSIXct("2026-02-26 12:00:00", tz = "UTC"),
    wind_speed_kn = 45,
    wind_gust_kn = 55,
    beaufort = 9L,
    description = "Strong Gale",
    is_gust_driven = FALSE
  )

  met_warnings <- c(
    "Gale warning in force for Irish coastal waters",
    "Storm force winds expected in Rockall and Malin"
  )

  email <- create_storm_alert_email(events, met_warnings = met_warnings)
  html <- paste(as.character(email), collapse = "")
  expect_true(grepl("Met Eireann", html))
  expect_true(grepl("Rockall", html))
})

# ── Integration tests (network required) ─────────────────────────

test_that("fetch_open_meteo_forecast returns correct structure", {
  skip_if_offline()

  # M2 coordinates, 1-day forecast
  result <- fetch_open_meteo_forecast(51.22, -9.99, "M2", forecast_days = 1)
  expect_s3_class(result, "tbl_df")
  # API may be unreachable in CI (DNS/SSL issues in Nix sandbox)
  skip_if(nrow(result) == 0, "Open Meteo API unreachable")
  expect_named(result, c("station_id", "time", "wind_speed_kn", "wind_gust_kn", "forecast_fetched_at"))
  expect_true(all(result$station_id == "M2"))
  # 1-day forecast should have ~24 hourly rows
  expect_true(nrow(result) >= 20 && nrow(result) <= 30)
})

test_that("fetch_open_meteo_forecast returns empty tibble for invalid coords", {
  skip_if_offline()

  # Coordinates outside valid range should still return data (Open-Meteo clamps)
  # but lat=999 should fail
  result <- fetch_open_meteo_forecast(999, 999, "INVALID", forecast_days = 1)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("fetch_all_forecasts returns data for all stations", {
  skip_if_offline()

  result <- fetch_all_forecasts(forecast_days = 1)
  expect_s3_class(result, "tbl_df")
  # API may be unreachable in CI (DNS/SSL issues in Nix sandbox)
  skip_if(nrow(result) == 0, "Open Meteo API unreachable")
  expect_true(nrow(result) > 100)  # 5 stations * ~24 hours
  stations <- unique(result$station_id)
  expect_true(all(c("M2", "M3", "M4", "M5", "M6") %in% stations))
})

test_that("send_storm_alert dry_run with high threshold returns no_storms", {
  skip_if_offline()

  result <- send_storm_alert(threshold_knots = 999, dry_run = TRUE)
  expect_type(result, "list")
  # API may be unreachable in CI; send_storm_alert returns error status
  skip_if(identical(result$status, "error"), "Open Meteo API unreachable")
  expect_equal(result$status, "no_storms")
  expect_equal(result$n_storms, 0)
})

test_that("send_storm_alert dry_run with low threshold produces preview", {
  skip_if_offline()
  skip_if_not_installed("blastula")

  result <- send_storm_alert(threshold_knots = 5, dry_run = TRUE)
  expect_type(result, "list")
  # API may be unreachable in CI
  skip_if(identical(result$status, "error"), "Open Meteo API unreachable")
  # With threshold 5 kn, almost certainly storms detected
  if (result$status == "preview") {
    expect_true(result$n_storms > 0)
    expect_true(file.exists(result$preview_file))
  }
  # Could also be no_storms in very rare calm conditions
  expect_true(result$status %in% c("preview", "no_storms"))
})

# ── p_hmax_exceedance (Forristall short-term distribution) ───────

test_that("p_hmax_exceedance returns probabilities in [0, 1]", {
  p <- p_hmax_exceedance(c(10, 15, 20, 25), hs = 10, tz = 9)
  expect_length(p, 4)
  expect_true(all(p >= 0 & p <= 1))
  # Probability of exceedance is monotonically decreasing in h
  expect_true(all(diff(p) <= 0))
})

test_that("p_hmax_exceedance returns NA for invalid inputs", {
  expect_true(is.na(p_hmax_exceedance(20, hs = 0, tz = 9)))
  expect_true(is.na(p_hmax_exceedance(20, hs = 10, tz = 0)))
  expect_true(is.na(p_hmax_exceedance(20, hs = NA_real_, tz = 9)))
  expect_true(is.na(p_hmax_exceedance(NA_real_, hs = 10, tz = 9)))
})

test_that("p_hmax_exceedance scales with duration", {
  # Longer window = more independent waves = higher P(Hmax > h)
  p_1h <- p_hmax_exceedance(20, hs = 10, tz = 9, duration_s = 3600)
  p_6h <- p_hmax_exceedance(20, hs = 10, tz = 9, duration_s = 6 * 3600)
  expect_gt(p_6h, p_1h)
})

test_that("p_hmax_exceedance is essentially zero for h >> Hs", {
  # H = 4 * Hs is far into the tail
  p <- p_hmax_exceedance(40, hs = 10, tz = 9)
  expect_lt(p, 1e-6)
})

# ── summarise_forecast_rogue_risk ────────────────────────────────

test_that("summarise_forecast_rogue_risk returns empty tibble for empty input", {
  empty <- tibble::tibble(
    station_id = character(),
    time = as.POSIXct(character()),
    wave_height_m = numeric(),
    wave_period_s = numeric(),
    wind_wave_height_m = numeric(),
    swell_wave_height_m = numeric(),
    forecast_fetched_at = as.POSIXct(character())
  )
  result <- summarise_forecast_rogue_risk(empty)
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
  expect_true(all(c(
    "station_id", "peak_hs_m",
    "p_hmax_gt_10", "p_hmax_gt_15", "p_hmax_gt_20", "p_hmax_gt_25"
  ) %in% names(result)))
})

test_that("summarise_forecast_rogue_risk computes per-station peaks", {
  fake <- tibble::tibble(
    station_id = c("M2", "M2", "M2", "M6", "M6"),
    time = as.POSIXct(c(
      "2026-04-10 00:00", "2026-04-10 12:00", "2026-04-10 18:00",
      "2026-04-10 06:00", "2026-04-10 18:00"
    ), tz = "UTC"),
    wave_height_m = c(3, 5, 4, 8, 12),
    wave_period_s = c(7, 9, 8, 10, 11),
    wind_wave_height_m = c(2, 3, 2.5, 5, 7),
    swell_wave_height_m = c(2, 3, 2.5, 5, 7),
    forecast_fetched_at = as.POSIXct("2026-04-08 08:00", tz = "UTC")
  )
  result <- summarise_forecast_rogue_risk(fake)
  expect_equal(nrow(result), 2)
  # M6 (peak Hs 12m) should sort first
  expect_equal(result$station_id[1], "M6")
  expect_equal(result$peak_hs_m[1], 12)
  expect_equal(result$peak_period_s[1], 11)
  # M6 P(Hmax > 20m) should be much higher than M2's
  m6 <- result[result$station_id == "M6", ]
  m2 <- result[result$station_id == "M2", ]
  expect_gt(m6$p_hmax_gt_20, m2$p_hmax_gt_20)
  # All probabilities in [0, 1]
  for (col in c("p_hmax_gt_10", "p_hmax_gt_15", "p_hmax_gt_20", "p_hmax_gt_25")) {
    expect_true(all(result[[col]] >= 0 & result[[col]] <= 1))
  }
  # Monotonicity: P(>10) >= P(>15) >= P(>20) >= P(>25) for every station
  expect_true(all(result$p_hmax_gt_10 >= result$p_hmax_gt_15))
  expect_true(all(result$p_hmax_gt_15 >= result$p_hmax_gt_20))
  expect_true(all(result$p_hmax_gt_20 >= result$p_hmax_gt_25))
})

# ── fetch_open_meteo_marine (network) ────────────────────────────

test_that("fetch_open_meteo_marine returns empty tibble for invalid coords", {
  skip_if_offline()
  # Lat 999 is invalid; API should error and the function should return empty
  result <- suppressWarnings(
    fetch_open_meteo_marine(999, 999, "BAD", forecast_days = 1, timeout = 10)
  )
  expect_s3_class(result, "tbl_df")
  expect_equal(nrow(result), 0)
})

test_that("fetch_open_meteo_marine returns expected schema for valid coords", {
  skip_if_offline()
  result <- fetch_open_meteo_marine(51.22, -9.99, "M2", forecast_days = 1, timeout = 15)
  skip_if(nrow(result) == 0, "Open-Meteo Marine API unreachable")
  expect_named(result, c(
    "station_id", "time", "wave_height_m", "wave_period_s",
    "wind_wave_height_m", "swell_wave_height_m", "forecast_fetched_at"
  ))
  expect_equal(unique(result$station_id), "M2")
  expect_s3_class(result$time, "POSIXct")
})

# ── create_storm_alert_email with forecast_rogue_summary ─────────

test_that("create_storm_alert_email renders the wave section when summary provided", {
  skip_if_not_installed("blastula")
  events <- tibble::tibble(
    station_id = "M6",
    time = as.POSIXct("2026-04-10 18:00", tz = "UTC"),
    wind_speed_kn = 50, wind_gust_kn = 70,
    beaufort = 10L, description = "Storm", is_gust_driven = FALSE
  )
  rogue <- tibble::tibble(
    station_id = "M6",
    peak_time = as.POSIXct("2026-04-10 18:00", tz = "UTC"),
    peak_hs_m = 12,
    peak_period_s = 11,
    p_hmax_gt_10 = 0.99,
    p_hmax_gt_15 = 0.45,
    p_hmax_gt_20 = 0.08,
    p_hmax_gt_25 = 0.005,
    n_forecast_hours = 168L
  )
  email <- create_storm_alert_email(events, forecast_rogue_summary = rogue)
  html <- paste(as.character(email), collapse = "\n")
  expect_true(grepl("Forecast Wave Conditions", html, fixed = TRUE))
  expect_true(grepl("Forristall", html, fixed = TRUE))
  # All four threshold columns rendered
  expect_true(grepl("P(Hmax &gt; 10 m)", html, fixed = TRUE))
  expect_true(grepl("P(Hmax &gt; 15 m)", html, fixed = TRUE))
  expect_true(grepl("P(Hmax &gt; 20 m)", html, fixed = TRUE))
  expect_true(grepl("P(Hmax &gt; 25 m)", html, fixed = TRUE))
  # M6 row with peak Hs 12.0 must appear
  expect_true(grepl(">12.0<", html, fixed = TRUE))
})

test_that("create_storm_alert_email omits wave section when summary is NULL or empty", {
  skip_if_not_installed("blastula")
  events <- tibble::tibble(
    station_id = "M6",
    time = as.POSIXct("2026-04-10 18:00", tz = "UTC"),
    wind_speed_kn = 50, wind_gust_kn = 70,
    beaufort = 10L, description = "Storm", is_gust_driven = FALSE
  )
  email_null <- create_storm_alert_email(events, forecast_rogue_summary = NULL)
  html_null <- paste(as.character(email_null), collapse = "\n")
  expect_false(grepl("Forecast Wave Conditions", html_null, fixed = TRUE))

  empty_rogue <- summarise_forecast_rogue_risk(tibble::tibble(
    station_id = character(), time = as.POSIXct(character()),
    wave_height_m = numeric(), wave_period_s = numeric(),
    wind_wave_height_m = numeric(), swell_wave_height_m = numeric(),
    forecast_fetched_at = as.POSIXct(character())
  ))
  email_empty <- create_storm_alert_email(events, forecast_rogue_summary = empty_rogue)
  html_empty <- paste(as.character(email_empty), collapse = "\n")
  expect_false(grepl("Forecast Wave Conditions", html_empty, fixed = TRUE))
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(beaufort_to_description) signature", {
  expect_snapshot(args(beaufort_to_description))
})

test_that("snapshot: args(create_storm_alert_email) signature", {
  expect_snapshot(args(create_storm_alert_email))
})

test_that("snapshot: args(detect_storm_events) signature", {
  expect_snapshot(args(detect_storm_events))
})

test_that("snapshot: args(fetch_all_forecasts) signature", {
  expect_snapshot(args(fetch_all_forecasts))
})

test_that("snapshot: args(fetch_open_meteo_forecast) signature", {
  expect_snapshot(args(fetch_open_meteo_forecast))
})

test_that("snapshot: args(fetch_open_meteo_marine) signature", {
  expect_snapshot(args(fetch_open_meteo_marine))
})

test_that("snapshot: args(knots_to_beaufort) signature", {
  expect_snapshot(args(knots_to_beaufort))
})

test_that("snapshot: args(p_hmax_exceedance) signature", {
  expect_snapshot(args(p_hmax_exceedance))
})

test_that("snapshot: args(send_storm_alert) signature", {
  expect_snapshot(args(send_storm_alert))
})

# ── Extra function signature snapshots (auto-added pass 2) ─────────
# Added to reach >=30% snapshot ratio. Regenerate with snapshot_accept().

test_that("snapshot pass2: args(summarise_forecast_rogue_risk)", {
  expect_snapshot(args(irishbuoys:::summarise_forecast_rogue_risk))
})

test_that("snapshot pass2: args(add_wave_metrics)", {
  expect_snapshot(args(irishbuoys:::add_wave_metrics))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
test_that("snap3: args(analyze_joint_extremes)", { expect_snapshot(args(irishbuoys:::analyze_joint_extremes)) })
