#' Generate Weekly Summary Statistics
#'
#' @description
#' Compares recent data against historical averages to identify trends
#' and anomalies.
#'
#' @param db_path Path to DuckDB database
#' @param lookback_days Number of days to analyze (default: 7)
#'
#' @return List containing summary statistics and comparisons
#'
#' @export
generate_weekly_summary <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 7
) {

  con <- connect_duckdb(db_path = db_path)
  on.exit(DBI::dbDisconnect(con))

  current_date <- Sys.Date()
  start_date <- current_date - lookback_days

  # Current week statistics
  current_week <- DBI::dbGetQuery(con, glue::glue("
    SELECT
      station_id,
      AVG(wave_height) as avg_wave_height,
      MAX(wave_height) as max_wave_height,
      AVG(wind_speed) as avg_wind_speed,
      MAX(wind_speed) as max_wind_speed,
      AVG(air_temperature) as avg_air_temp,
      AVG(sea_temperature) as avg_sea_temp,
      COUNT(*) as n_observations
    FROM buoy_data
    WHERE time >= '{start_date}'
      AND time < '{current_date}'
      AND qc_flag = 1
    GROUP BY station_id
  "))

  # Previous week comparison
  prev_week <- DBI::dbGetQuery(con, glue::glue("
    SELECT
      station_id,
      AVG(wave_height) as avg_wave_height,
      MAX(wave_height) as max_wave_height,
      AVG(wind_speed) as avg_wind_speed,
      MAX(wind_speed) as max_wind_speed,
      AVG(air_temperature) as avg_air_temp
    FROM buoy_data
    WHERE time >= '{start_date - 7}'
      AND time < '{start_date}'
      AND qc_flag = 1
    GROUP BY station_id
  "))

  # Historical averages for this time of year
  historical <- DBI::dbGetQuery(con, glue::glue("
    SELECT
      station_id,
      AVG(wave_height) as hist_avg_wave_height,
      PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY wave_height) as p95_wave_height,
      AVG(wind_speed) as hist_avg_wind_speed,
      PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY wind_speed) as p95_wind_speed,
      AVG(air_temperature) as hist_avg_air_temp,
      AVG(sea_temperature) as hist_avg_sea_temp
    FROM buoy_data
    WHERE EXTRACT(WEEK FROM time) = EXTRACT(WEEK FROM TIMESTAMP '{current_date}')
      AND time < '{start_date}'
      AND qc_flag = 1
    GROUP BY station_id
  "))

  # Check for extreme events
  extremes <- DBI::dbGetQuery(con, glue::glue("
    SELECT
      station_id,
      time,
      'High Waves' as event_type,
      wave_height as value
    FROM buoy_data
    WHERE time >= '{start_date}'
      AND wave_height > 8
      AND qc_flag = 1

    UNION ALL

    SELECT
      station_id,
      time,
      'Storm Winds' as event_type,
      wind_speed as value
    FROM buoy_data
    WHERE time >= '{start_date}'
      AND wind_speed > 48
      AND qc_flag = 1

    UNION ALL

    SELECT
      station_id,
      time,
      'Rogue Wave' as event_type,
      hmax as value
    FROM buoy_data
    WHERE time >= '{start_date}'
      AND hmax > 2 * wave_height
      AND wave_height > 2
      AND qc_flag = 1

    ORDER BY time DESC
  "))

  # Combine results
  summary <- list(
    current_week = current_week,
    previous_week = prev_week,
    historical = historical,
    extreme_events = extremes,
    report_date = current_date,
    period = list(start = start_date, end = current_date - 1)
  )

  # Calculate changes
  if (nrow(current_week) > 0 && nrow(prev_week) > 0) {
    comparison <- merge(current_week, prev_week,
                       by = "station_id", suffixes = c("_current", "_prev"))

    comparison$wave_change_pct <- round(
      100 * (comparison$avg_wave_height_current - comparison$avg_wave_height_prev) /
        comparison$avg_wave_height_prev, 1)

    comparison$wind_change_pct <- round(
      100 * (comparison$avg_wind_speed_current - comparison$avg_wind_speed_prev) /
        comparison$avg_wind_speed_prev, 1)

    summary$week_over_week <- comparison
  }

  return(summary)
}

#' Create HTML Email Summary
#'
#' @description
#' Formats the weekly summary as an HTML email using blastula.
#'
#' @param summary Summary object from generate_weekly_summary()
#'
#' @return blastula email object
#'
#' @export
create_email_summary <- function(summary) {

  # Format extreme events table
  extreme_text <- if (nrow(summary$extreme_events) > 0) {
    paste0(
      "<h3>⚠️ Extreme Events This Week</h3>",
      "<table border='1' style='border-collapse: collapse;'>",
      "<tr><th>Station</th><th>Time</th><th>Event</th><th>Value</th></tr>",
      paste(apply(summary$extreme_events, 1, function(row) {
        paste0("<tr><td>", paste(row, collapse = "</td><td>"), "</td></tr>")
      }), collapse = ""),
      "</table>"
    )
  } else {
    "<p>No extreme events detected this week.</p>"
  }

  # Format station statistics
  station_stats <- paste(apply(summary$current_week, 1, function(row) {
    paste0(
      "<h3>Station ", row["station_id"], "</h3>",
      "<ul>",
      "<li>Average Wave Height: ", round(as.numeric(row["avg_wave_height"]), 2), " m</li>",
      "<li>Maximum Wave Height: ", round(as.numeric(row["max_wave_height"]), 2), " m</li>",
      "<li>Average Wind Speed: ", round(as.numeric(row["avg_wind_speed"]), 1), " knots</li>",
      "<li>Air Temperature: ", round(as.numeric(row["avg_air_temp"]), 1), "°C</li>",
      "<li>Sea Temperature: ", round(as.numeric(row["avg_sea_temp"]), 1), "°C</li>",
      "<li>Observations: ", row["n_observations"], "</li>",
      "</ul>"
    )
  }), collapse = "")

  # Create email body
  email_body <- paste0(
    "<h1>📊 Irish Weather Buoy Network - Weekly Summary</h1>",
    "<p><strong>Report Period:</strong> ",
    summary$period$start, " to ", summary$period$end, "</p>",

    "<h2>📈 This Week's Statistics</h2>",
    station_stats,

    extreme_text,

    "<h2>📊 Week-over-Week Changes</h2>",
    if (!is.null(summary$week_over_week)) {
      paste0(
        "<table border='1' style='border-collapse: collapse;'>",
        "<tr><th>Station</th><th>Wave Height Change</th><th>Wind Speed Change</th></tr>",
        paste(apply(summary$week_over_week[, c("station_id", "wave_change_pct", "wind_change_pct")], 1,
          function(row) {
            wave_color <- if(as.numeric(row[2]) > 0) "red" else "green"
            wind_color <- if(as.numeric(row[3]) > 0) "red" else "green"
            paste0(
              "<tr><td>", row[1], "</td>",
              "<td style='color:", wave_color, "'>", row[2], "%</td>",
              "<td style='color:", wind_color, "'>", row[3], "%</td></tr>"
            )
          }), collapse = ""),
        "</table>"
      )
    } else {
      "<p>Previous week data not available for comparison.</p>"
    },

    "<hr>",
    "<p><small>Generated on ", Sys.Date(), " by irishbuoys package</small></p>",
    "<p><small>Data source: Marine Institute ERDDAP Server</small></p>"
  )

  # Create email using blastula
  email <- blastula::compose_email(
    body = blastula::md(email_body),
    footer = blastula::md("This is an automated report from the Irish Weather Buoy Network monitoring system.")
  )

  return(email)
}

#' Generate and Send Summary Email
#'
#' @description
#' Main function to generate summary and send via email.
#' Requires environment variables for SMTP configuration.
#'
#' @param recipient Email recipient (default from EMAIL_TO env var)
#' @param sender Email sender (default from EMAIL_FROM env var)
#'
#' @export
generate_and_send_summary <- function(
    recipient = Sys.getenv("EMAIL_TO"),
    sender = Sys.getenv("EMAIL_FROM")
) {

  cli::cli_h1("Generating Weekly Summary")

  # Generate summary
  summary <- generate_weekly_summary()

  # Create email
  email <- create_email_summary(summary)

  # Add subject line
  subject <- paste0(
    "Irish Buoy Network Weekly Report - ",
    format(Sys.Date(), "%B %d, %Y")
  )

  # Check if we have email credentials
  if (nzchar(recipient) && nzchar(sender)) {
    cli::cli_alert_info("Sending email to {recipient}")

    # Create SMTP credentials
    creds <- blastula::creds(
      host = Sys.getenv("EMAIL_SMTP_HOST", "smtp.gmail.com"),
      port = as.numeric(Sys.getenv("EMAIL_SMTP_PORT", "587")),
      user = Sys.getenv("EMAIL_SMTP_USER"),
      pass = Sys.getenv("EMAIL_SMTP_PASS"),
      use_ssl = TRUE
    )

    # Send email
    tryCatch({
      blastula::smtp_send(
        email = email,
        to = recipient,
        from = sender,
        subject = subject,
        credentials = creds
      )
      cli::cli_alert_success("Email sent successfully")
    }, error = function(e) {
      cli::cli_alert_danger("Failed to send email: {e$message}")
      # Save email to file as backup
      html_file <- paste0("email_summary_", Sys.Date(), ".html")
      blastula::save_email(email, html_file)
      cli::cli_alert_info("Email saved to {html_file}")
    })
  } else {
    cli::cli_alert_warning("Email credentials not configured")
    # Save to file instead
    html_file <- paste0("email_summary_", Sys.Date(), ".html")
    blastula::save_email(email, html_file)
    cli::cli_alert_info("Summary saved to {html_file}")
  }

  return(invisible(summary))
}