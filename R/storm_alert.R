#' Storm Alert Functions
#'
#' @description
#' Functions for fetching wind forecasts from Open-Meteo, detecting storm events,
#' and sending email alerts when gale-force winds (Beaufort 8+) are forecast.
#'
#' @name storm_alert
#' @keywords internal
NULL

#' Convert Wind Speed in Knots to Beaufort Scale
#'
#' @description
#' Vectorized conversion from wind speed in knots to the Beaufort scale (0-12).
#'
#' @param wind_speed_kn Numeric vector of wind speeds in knots.
#'
#' @return Integer vector of Beaufort numbers (0-12).
#' @export
#' @family storm-alert
#' @examples
#' knots_to_beaufort(c(0, 5, 20, 34, 48, 64))
knots_to_beaufort <- function(wind_speed_kn) {
  dplyr::case_when(
    wind_speed_kn < 1 ~ 0L,
    wind_speed_kn < 4 ~ 1L,
    wind_speed_kn < 7 ~ 2L,
    wind_speed_kn < 11 ~ 3L,
    wind_speed_kn < 17 ~ 4L,
    wind_speed_kn < 22 ~ 5L,
    wind_speed_kn < 28 ~ 6L,
    wind_speed_kn < 34 ~ 7L,
    wind_speed_kn < 41 ~ 8L,
    wind_speed_kn < 48 ~ 9L,
    wind_speed_kn < 56 ~ 10L,
    wind_speed_kn < 64 ~ 11L,
    .default = 12L
  )
}

#' Convert Beaufort Number to Description
#'
#' @description
#' Maps Beaufort scale integers (0-12) to standard descriptions.
#'
#' @param beaufort Integer vector of Beaufort numbers (0-12).
#'
#' @return Character vector of Beaufort descriptions.
#' @export
#' @family storm-alert
#' @examples
#' beaufort_to_description(0:12)
beaufort_to_description <- function(beaufort) {
  labels <- c(
    "Calm", "Light Air", "Light Breeze", "Gentle Breeze",
    "Moderate Breeze", "Fresh Breeze", "Strong Breeze",
    "Near Gale", "Gale", "Strong Gale", "Storm",
    "Violent Storm", "Hurricane Force"
  )
  # Clamp to valid range and index (1-based)
  idx <- pmin(pmax(as.integer(beaufort), 0L), 12L) + 1L
  labels[idx]
}

#' Fetch Wind Forecast from Open-Meteo for a Single Station
#'
#' @description
#' Queries the Open-Meteo API for hourly wind speed and gust forecasts
#' at a given latitude/longitude. Returns an empty tibble on error.
#'
#' @param lat Latitude in decimal degrees.
#' @param lon Longitude in decimal degrees.
#' @param station_id Character station identifier (e.g. "M2").
#' @param forecast_days Integer number of forecast days (1-16, default 7).
#' @param timeout Numeric request timeout in seconds (default 30).
#'
#' @return Tibble with columns: station_id, time, wind_speed_kn, wind_gust_kn,
#'   forecast_fetched_at. Empty tibble on error.
#' @export
#' @family storm-alert
#' @examples
#' \dontrun{
#' fetch_open_meteo_forecast(51.22, -9.99, "M2", forecast_days = 1)
#' }
fetch_open_meteo_forecast <- function(lat, lon, station_id,
                                      forecast_days = 7, timeout = 30) {
  empty_result <- tibble::tibble(
    station_id = character(),
    time = as.POSIXct(character()),
    wind_speed_kn = numeric(),
    wind_gust_kn = numeric(),
    forecast_fetched_at = as.POSIXct(character())
  )

  tryCatch({
    resp <- httr2::request("https://api.open-meteo.com/v1/forecast") |>
      httr2::req_url_query(
        latitude = lat,
        longitude = lon,
        hourly = "wind_speed_10m,wind_gusts_10m",
        wind_speed_unit = "kn",
        forecast_days = forecast_days,
        timezone = "UTC"
      ) |>
      httr2::req_timeout(timeout) |>
      httr2::req_retry(max_tries = 3, backoff = ~ 5) |>
      httr2::req_perform()

    body <- httr2::resp_body_json(resp)

    if (is.null(body$hourly) || is.null(body$hourly$time)) {
      cli::cli_warn("No hourly data returned for station {station_id}")
      return(empty_result)
    }

    times <- as.POSIXct(unlist(body$hourly$time), format = "%Y-%m-%dT%H:%M", tz = "UTC")
    wind_speed <- as.numeric(unlist(body$hourly$wind_speed_10m))
    wind_gust <- as.numeric(unlist(body$hourly$wind_gusts_10m))

    tibble::tibble(
      station_id = station_id,
      time = times,
      wind_speed_kn = wind_speed,
      wind_gust_kn = wind_gust,
      forecast_fetched_at = Sys.time()
    )
  }, error = function(e) {
    cli::cli_warn("Failed to fetch forecast for station {station_id}: {e$message}")
    empty_result
  })
}

#' Fetch Forecasts for All Buoy Stations
#'
#' @description
#' Loops over all stations from [get_station_info()] and fetches wind forecasts.
#'
#' @param station_info Data frame with station_id, lat, lon columns
#'   (default from [get_station_info()]).
#' @param forecast_days Integer number of forecast days (default 7).
#' @param timeout Numeric request timeout in seconds (default 30).
#'
#' @return Combined tibble of all station forecasts.
#' @export
#' @family storm-alert
#' @examples
#' \dontrun{
#' fetch_all_forecasts()
#' }
fetch_all_forecasts <- function(station_info = get_station_info(),
                                forecast_days = 7, timeout = 30) {
  results <- lapply(seq_len(nrow(station_info)), function(i) {
    row <- station_info[i, ]
    cli::cli_alert_info("Fetching forecast for {row$station_id} ({row$lat}, {row$lon})")
    fetch_open_meteo_forecast(
      lat = row$lat,
      lon = row$lon,
      station_id = row$station_id,
      forecast_days = forecast_days,
      timeout = timeout
    )
  })
  dplyr::bind_rows(results)
}

#' Detect Storm Events from Forecast Data
#'
#' @description
#' Filters forecast data for wind speeds at or above the storm threshold.
#' Threshold is resolved in order: `threshold_knots` parameter, then
#' `STORM_ALERT_THRESHOLD_KNOTS` env var, then default of 34 knots (Beaufort 8).
#'
#' @param forecasts Tibble from [fetch_all_forecasts()] or [fetch_open_meteo_forecast()].
#' @param threshold_knots Numeric threshold in knots (default NULL, uses env var or 34).
#' @param use_gusts Logical; if TRUE (default), also flag rows where gusts exceed threshold.
#'
#' @return Tibble with columns: station_id, time, wind_speed_kn, wind_gust_kn,
#'   beaufort, description, is_gust_driven. Empty tibble if no storms detected.
#' @export
#' @family storm-alert
#' @examples
#' forecasts <- tibble::tibble(
#'   station_id = "M2",
#'   time = Sys.time() + 3600 * 1:3,
#'   wind_speed_kn = c(20, 38, 50),
#'   wind_gust_kn = c(25, 45, 60)
#' )
#' detect_storm_events(forecasts)
detect_storm_events <- function(forecasts, threshold_knots = NULL,
                                use_gusts = TRUE) {
  empty_result <- tibble::tibble(
    station_id = character(),
    time = as.POSIXct(character()),
    wind_speed_kn = numeric(),
    wind_gust_kn = numeric(),
    beaufort = integer(),
    description = character(),
    is_gust_driven = logical()
  )

  if (nrow(forecasts) == 0) return(empty_result)

  # Resolve threshold: param > env var > default 34

if (is.null(threshold_knots)) {
    env_val <- Sys.getenv("STORM_ALERT_THRESHOLD_KNOTS", unset = "")
    if (nzchar(env_val)) {
      threshold_knots <- suppressWarnings(as.numeric(env_val))
      if (is.na(threshold_knots)) {
        cli::cli_warn(
          "Invalid STORM_ALERT_THRESHOLD_KNOTS={.val {env_val}}, using default 34 knots"
        )
        threshold_knots <- 34
      }
    } else {
      threshold_knots <- 34
    }
  }

  # Filter for storm conditions
  storms <- forecasts |>
    dplyr::mutate(
      wind_exceeds = .data$wind_speed_kn >= threshold_knots,
      gust_exceeds = if (use_gusts) .data$wind_gust_kn >= threshold_knots else FALSE,
      is_storm = .data$wind_exceeds | .data$gust_exceeds
    ) |>
    dplyr::filter(.data$is_storm) |>
    dplyr::mutate(
      beaufort = knots_to_beaufort(.data$wind_speed_kn),
      description = beaufort_to_description(.data$beaufort),
      is_gust_driven = !.data$wind_exceeds & .data$gust_exceeds
    ) |>
    dplyr::select(
      "station_id", "time", "wind_speed_kn", "wind_gust_kn",
      "beaufort", "description", "is_gust_driven"
    )

  storms
}

#' Fetch Met Eireann Marine Warnings
#'
#' @description
#' Fetches the latest marine forecast/warning text from Met Eireann's open data.
#' Returns NULL on any error (best-effort supplementary info).
#'
#' @param timeout Numeric request timeout in seconds (default 10).
#'
#' @return Character vector of warning lines, or NULL if unavailable.
#' @export
#' @family storm-alert
#' @examples
#' \dontrun{
#' fetch_met_eireann_warnings()
#' }
fetch_met_eireann_warnings <- function(timeout = 10) {
  tryCatch({
    resp <- httr2::request("https://www.met.ie/Open_Data/xml/fcom.xml") |>
      httr2::req_timeout(timeout) |>
      httr2::req_retry(max_tries = 2, backoff = ~ 3) |>
      httr2::req_perform()

    text <- httr2::resp_body_string(resp)
    lines <- strsplit(text, "\n")[[1]]
    warning_lines <- grep("(gale|storm|warning|severe|wind)", lines,
                          ignore.case = TRUE, value = TRUE)
    warning_lines <- trimws(gsub("<[^>]+>", "", warning_lines))
    warning_lines <- warning_lines[nzchar(warning_lines)]

    if (length(warning_lines) == 0) return(NULL)
    warning_lines
  }, error = function(e) {
    cli::cli_warn("Failed to fetch Met Eireann warnings: {e$message}")
    NULL
  })
}

#' Create Storm Alert Email
#'
#' @description
#' Composes an HTML email with storm event details for all affected stations.
#'
#' @param storm_events Tibble from [detect_storm_events()].
#' @param station_info Data frame from [get_station_info()] (default).
#' @param met_warnings Character vector from [fetch_met_eireann_warnings()], or NULL.
#'
#' @return A blastula email object.
#' @export
#' @family storm-alert
#' @examples
#' \dontrun{
#' events <- tibble::tibble(
#'   station_id = "M2", time = Sys.time(),
#'   wind_speed_kn = 40, wind_gust_kn = 55,
#'   beaufort = 8L, description = "Gale", is_gust_driven = FALSE
#' )
#' create_storm_alert_email(events)
#' }
create_storm_alert_email <- function(storm_events,
                                     station_info = get_station_info(),
                                     met_warnings = NULL) {
  rlang::check_installed("blastula", reason = "to compose storm alert emails")

  # Build per-station summary
  station_summary <- storm_events |>
    dplyr::group_by(.data$station_id) |>
    dplyr::summarise(
      first_storm = min(.data$time),
      max_wind_kn = max(.data$wind_speed_kn),
      max_gust_kn = max(.data$wind_gust_kn),
      max_beaufort = max(.data$beaufort),
      hours_affected = dplyr::n(),
      .groups = "drop"
    ) |>
    dplyr::left_join(
      station_info[, c("station_id", "location")],
      by = "station_id"
    )

  # Station table rows (avoid apply which coerces POSIXct)
  table_rows <- paste(vapply(seq_len(nrow(station_summary)), function(i) {
    r <- station_summary[i, ]
    bf_color <- if (r$max_beaufort >= 10) "color:darkred;" else "color:darkorange;"
    paste0(
      "<tr>",
      "<td style='padding:6px;border:1px solid #ddd;'><strong>", r$station_id, "</strong></td>",
      "<td style='padding:6px;border:1px solid #ddd;'>", r$location, "</td>",
      "<td style='padding:6px;border:1px solid #ddd;'>",
      format(r$first_storm, "%a %d %b %H:%M UTC"), "</td>",
      "<td style='padding:6px;border:1px solid #ddd;text-align:center;'>",
      round(r$max_wind_kn, 1), "</td>",
      "<td style='padding:6px;border:1px solid #ddd;text-align:center;'>",
      round(r$max_gust_kn, 1), "</td>",
      "<td style='padding:6px;border:1px solid #ddd;text-align:center;font-weight:bold;",
      bf_color,
      "'>", r$max_beaufort, " (", beaufort_to_description(r$max_beaufort), ")</td>",
      "<td style='padding:6px;border:1px solid #ddd;text-align:center;'>", r$hours_affected, "</td>",
      "</tr>"
    )
  }, character(1)), collapse = "")

  # Met Eireann section
  met_section <- if (!is.null(met_warnings) && length(met_warnings) > 0) {
    paste0(
      "<h2 style='color:#333;'>Met Eireann Marine Warnings</h2>",
      "<div style='background:#fff3cd;padding:12px;border-left:4px solid #ffc107;'>",
      paste0("<p>", met_warnings, "</p>", collapse = ""),
      "</div>"
    )
  } else {
    ""
  }

  n_stations <- nrow(station_summary)
  max_beaufort <- max(station_summary$max_beaufort)

  email_body <- paste0(
    "<div style='font-family:Arial,sans-serif;max-width:700px;margin:auto;'>",
    "<div style='background:#d32f2f;color:white;padding:16px;text-align:center;'>",
    "<h1 style='margin:0;'>Storm Alert: Gale Force Winds Forecast</h1>",
    "<p style='margin:4px 0 0;font-size:1.1em;'>",
    n_stations, " station", if (n_stations > 1) "s", " affected | ",
    "Max Beaufort ", max_beaufort, " (",
    beaufort_to_description(max_beaufort), ")</p>",
    "</div>",

    "<h2 style='color:#333;margin-top:20px;'>Station Summary</h2>",
    "<table style='border-collapse:collapse;width:100%;'>",
    "<tr style='background:#f5f5f5;'>",
    "<th style='padding:8px;border:1px solid #ddd;'>Station</th>",
    "<th style='padding:8px;border:1px solid #ddd;'>Location</th>",
    "<th style='padding:8px;border:1px solid #ddd;'>First Storm</th>",
    "<th style='padding:8px;border:1px solid #ddd;'>Max Wind (kn)</th>",
    "<th style='padding:8px;border:1px solid #ddd;'>Max Gust (kn)</th>",
    "<th style='padding:8px;border:1px solid #ddd;'>Max Beaufort</th>",
    "<th style='padding:8px;border:1px solid #ddd;'>Hours</th>",
    "</tr>",
    table_rows,
    "</table>",

    met_section,

    "<hr style='margin-top:20px;'>",
    "<p style='color:#666;font-size:0.85em;'>",
    "Generated on ", format(Sys.time(), "%Y-%m-%d %H:%M UTC"), " by irishbuoys package<br>",
    "Forecast source: <a href='https://open-meteo.com/'>Open-Meteo</a> | ",
    "Observations: <a href='https://erddap.marine.ie/'>Marine Institute ERDDAP</a>",
    "</p>",
    "</div>"
  )

  blastula::compose_email(
    body = blastula::md(email_body),
    footer = blastula::md(
      "Automated storm alert from the Irish Weather Buoy Network monitoring system."
    )
  )
}

#' Send Storm Alert Email
#'
#' @description
#' Main orchestrator: fetches forecasts, detects storms, and sends an email alert
#' if gale-force winds are forecast. If no storms are detected, no email is sent.
#' Uses the same Gmail SMTP pattern as the weekly email report.
#'
#' @param threshold_knots Numeric threshold in knots (default NULL, uses env var or 34).
#' @param recipient Email recipient (default from `GMAIL_USERNAME` env var).
#' @param sender Email sender (default from `GMAIL_USERNAME` env var).
#' @param dry_run Logical; if TRUE, saves HTML preview to tempdir instead of sending.
#'
#' @return List with: status ("sent", "no_storms", "preview", "error"),
#'   n_storms, stations_affected, preview_file (if dry_run), error (if failed).
#' @export
#' @family storm-alert
#' @examples
#' \dontrun{
#' # Check with very high threshold (likely no storms)
#' send_storm_alert(threshold_knots = 999)
#'
#' # Dry run with low threshold (likely produces alert)
#' send_storm_alert(threshold_knots = 20, dry_run = TRUE)
#' }
send_storm_alert <- function(threshold_knots = NULL,
                             recipient = Sys.getenv("GMAIL_USERNAME"),
                             sender = Sys.getenv("GMAIL_USERNAME"),
                             dry_run = FALSE) {
  cli::cli_h1("Storm Alert Check")

  # Step 1: Fetch forecasts
  cli::cli_alert_info("Fetching forecasts for all stations...")
  forecasts <- fetch_all_forecasts()

  if (nrow(forecasts) == 0) {
    cli::cli_alert_warning("No forecast data retrieved")
    return(list(status = "error", n_storms = 0, error = "No forecast data"))
  }
  cli::cli_alert_success("Retrieved {nrow(forecasts)} forecast hours across {length(unique(forecasts$station_id))} stations")

  # Step 2: Detect storms
  storm_events <- detect_storm_events(forecasts, threshold_knots = threshold_knots)

  if (nrow(storm_events) == 0) {
    cli::cli_alert_success("No storms detected - no alert needed")
    return(list(status = "no_storms", n_storms = 0, stations_affected = character()))
  }

  n_storms <- nrow(storm_events)
  stations_affected <- unique(storm_events$station_id)
  cli::cli_alert_warning(
    "{n_storms} storm hours detected at {length(stations_affected)} station(s): {paste(stations_affected, collapse = ', ')}"
  )

  # Step 3: Fetch Met Eireann warnings (best-effort)
  met_warnings <- fetch_met_eireann_warnings()

  # Step 4: Create email
  rlang::check_installed("blastula", reason = "to send storm alert emails")
  email <- create_storm_alert_email(storm_events, met_warnings = met_warnings)

  subject <- paste0(
    "STORM ALERT: Beaufort ", max(storm_events$beaufort),
    " forecast at ", paste(stations_affected, collapse = "/"),
    " - ", format(Sys.Date(), "%d %b %Y")
  )

  # Step 5: Send or preview
  if (dry_run) {
    preview_file <- file.path(tempdir(), paste0("storm_alert_", Sys.Date(), ".html"))
    writeLines(as.character(email), preview_file)
    cli::cli_alert_success("Preview saved to {preview_file}")
    return(list(
      status = "preview",
      n_storms = n_storms,
      stations_affected = stations_affected,
      preview_file = preview_file
    ))
  }

  if (!nzchar(recipient) || !nzchar(sender)) {
    cli::cli_alert_warning("No Gmail credentials - saving preview")
    preview_file <- file.path(tempdir(), paste0("storm_alert_", Sys.Date(), ".html"))
    writeLines(as.character(email), preview_file)
    return(list(
      status = "preview",
      n_storms = n_storms,
      stations_affected = stations_affected,
      preview_file = preview_file
    ))
  }

  tryCatch({
    creds <- blastula::creds_envvar(
      user = sender,
      pass_envvar = "GMAIL_APP_PASSWORD",
      host = "smtp.gmail.com",
      port = 465,
      use_ssl = TRUE
    )

    blastula::smtp_send(
      email = email,
      to = recipient,
      from = sender,
      subject = subject,
      credentials = creds
    )

    cli::cli_alert_success("Storm alert sent to {recipient}")
    list(
      status = "sent",
      n_storms = n_storms,
      stations_affected = stations_affected
    )
  }, error = function(e) {
    cli::cli_alert_danger("Failed to send storm alert: {e$message}")
    preview_file <- file.path(tempdir(), paste0("storm_alert_", Sys.Date(), ".html"))
    writeLines(as.character(email), preview_file)
    list(
      status = "error",
      n_storms = n_storms,
      stations_affected = stations_affected,
      error = e$message,
      preview_file = preview_file
    )
  })
}
