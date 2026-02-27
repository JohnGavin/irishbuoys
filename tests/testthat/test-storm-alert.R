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

  # Default (34 kn) — should not detect
  withr::with_envvar(c(STORM_ALERT_THRESHOLD_KNOTS = NA), {
    result <- detect_storm_events(forecasts)
    expect_equal(nrow(result), 0)
  })
})

test_that("detect_storm_events handles invalid env var gracefully", {
  forecasts <- tibble::tibble(
    station_id = "M2",
    time = Sys.time() + 3600,
    wind_speed_kn = 35,
    wind_gust_kn = 40
  )

  # Invalid env var falls back to 34
  withr::with_envvar(c(STORM_ALERT_THRESHOLD_KNOTS = "not_a_number"), {
    expect_warning(
      detect_storm_events(forecasts),
      "Invalid"
    )
    # Run again to check the actual result (warning already tested above)
    result <- suppressWarnings(detect_storm_events(forecasts))
    expect_equal(nrow(result), 1)  # 35 >= 34 (default)
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
  expect_true(nrow(result) > 0)
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
  expect_true(nrow(result) > 100)  # 5 stations * ~24 hours
  stations <- unique(result$station_id)
  expect_true(all(c("M2", "M3", "M4", "M5", "M6") %in% stations))
})

test_that("send_storm_alert dry_run with high threshold returns no_storms", {
  skip_if_offline()

  result <- send_storm_alert(threshold_knots = 999, dry_run = TRUE)
  expect_type(result, "list")
  expect_equal(result$status, "no_storms")
  expect_equal(result$n_storms, 0)
})

test_that("send_storm_alert dry_run with low threshold produces preview", {
  skip_if_offline()
  skip_if_not_installed("blastula")

  result <- send_storm_alert(threshold_knots = 5, dry_run = TRUE)
  expect_type(result, "list")
  # With threshold 5 kn, almost certainly storms detected
  if (result$status == "preview") {
    expect_true(result$n_storms > 0)
    expect_true(file.exists(result$preview_file))
  }
  # Could also be no_storms in very rare calm conditions
  expect_true(result$status %in% c("preview", "no_storms"))
})
