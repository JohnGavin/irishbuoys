#' Generate Weekly Summary Statistics
#'
#' @description
#' Compares recent data against historical averages to identify trends
#' and anomalies. Optionally includes data ingestion statistics.
#'
#' @param db_path Path to DuckDB database
#' @param lookback_days Number of days to analyze (default: 7)
#' @param qc_filter QC flag filter: 1 = good only, 0 = include unverified, NULL = no filter
#' @param update_result Optional result from incremental_update() containing ingestion stats
#'
#' @return List containing summary statistics and comparisons
#'
#' @export
generate_weekly_summary <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    lookback_days = 7,
    qc_filter = NULL,
    update_result = NULL
) {

  con <- connect_duckdb(db_path = db_path)

  on.exit(DBI::dbDisconnect(con))

  current_date <- Sys.Date()
  start_date <- current_date - lookback_days

  # Build QC filter clause
  qc_clause <- if (!is.null(qc_filter)) {
    glue::glue("AND qc_flag = {qc_filter}")
  } else {
    "AND qc_flag != 9"
  }

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
      {qc_clause}
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
      {qc_clause}
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
    WHERE strftime(time, '%W') = strftime(TIMESTAMP '{current_date}', '%W')
      AND time < '{start_date}'
      {qc_clause}
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
      {qc_clause}

    UNION ALL

    SELECT
      station_id,
      time,
      'Storm Winds' as event_type,
      wind_speed as value
    FROM buoy_data
    WHERE time >= '{start_date}'
      AND wind_speed > 48
      {qc_clause}

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
      {qc_clause}

    ORDER BY time DESC
  "))

  # Ingestion stats: new records per station this week
  ingestion_stats <- DBI::dbGetQuery(con, glue::glue("
    SELECT
      station_id,
      COUNT(*) as new_records,
      MIN(time) as earliest,
      MAX(time) as latest
    FROM buoy_data
    WHERE time >= '{start_date}'
      AND time < '{current_date}'
    GROUP BY station_id
    ORDER BY station_id
  "))

  # Database totals
  db_stats <- tryCatch(
    get_database_stats(con),
    error = function(e) NULL
  )

  # Combine results
  summary <- list(
    current_week = current_week,
    previous_week = prev_week,
    historical = historical,
    extreme_events = extremes,
    ingestion_stats = ingestion_stats,
    db_stats = db_stats,
    update_result = update_result,
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
      "<h3>[!] Extreme Events This Week</h3>",
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
      "<li>Air Temperature: ", round(as.numeric(row["avg_air_temp"]), 1), " C</li>",
      "<li>Sea Temperature: ", round(as.numeric(row["avg_sea_temp"]), 1), " C</li>",
      "<li>Observations: ", row["n_observations"], "</li>",
      "</ul>"
    )
  }), collapse = "")

  # Format ingestion stats table
  ingestion_text <- if (!is.null(summary$ingestion_stats) && nrow(summary$ingestion_stats) > 0) {
    paste0(
      "<h2>Data Ingestion This Week</h2>",
      "<table border='1' style='border-collapse: collapse;'>",
      "<tr><th>Station</th><th>New Records</th><th>Earliest</th><th>Latest</th></tr>",
      paste(apply(summary$ingestion_stats, 1, function(row) {
        paste0("<tr><td>", row["station_id"], "</td>",
               "<td>", format(as.numeric(row["new_records"]), big.mark = ","), "</td>",
               "<td>", row["earliest"], "</td>",
               "<td>", row["latest"], "</td></tr>")
      }), collapse = ""),
      "</table>"
    )
  } else {
    "<h2>Data Ingestion This Week</h2><p>No new records ingested.</p>"
  }

  # Format database totals
  db_totals_text <- if (!is.null(summary$db_stats)) {
    stats <- summary$db_stats
    paste0(
      "<p><strong>Dataset Totals:</strong> ",
      format(stats$total_records, big.mark = ","), " records, ",
      round(stats$db_size_mb, 1), " MB</p>"
    )
  } else {
    ""
  }

  # Create email body
  email_body <- paste0(
    "<h1>Irish Weather Buoy Network - Weekly Summary</h1>",
    "<p><strong>Report Period:</strong> ",
    summary$period$start, " to ", summary$period$end, "</p>",

    ingestion_text,
    db_totals_text,

    "<h2>This Week's Statistics</h2>",
    station_stats,

    extreme_text,

    "<h2>Week-over-Week Changes</h2>",
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
    "<p><small>Generated on ", Sys.Date(), " by the ",
    "<a href='https://johngavin.github.io/irishbuoys/'>irishbuoys</a> R package ",
    "(<a href='https://github.com/JohnGavin/irishbuoys'>source on GitHub</a>).</small></p>",
    "<p><small>Data source: <a href='https://erddap.marine.ie/'>Marine Institute ERDDAP Server</a></small></p>",
    "<p><small><em>Disclaimer: irishbuoys is an independent open-source project. ",
    "It is not affiliated with, endorsed by, or part of the Marine Institute ",
    "or the Irish Weather Buoy Network.</em></small></p>"
  )

  # Create email using blastula
  email <- blastula::compose_email(
    body = blastula::md(email_body),
    footer = blastula::md(paste0(
      "Automated report from the ",
      "[irishbuoys](https://johngavin.github.io/irishbuoys/) R package ",
      "([GitHub](https://github.com/JohnGavin/irishbuoys)). ",
      "This is an independent open-source project, not affiliated with the Marine Institute ",
      "or the Irish Weather Buoy Network."
    ))
  )

  return(email)
}

#' Generate and Send Summary Email
#'
#' @description
#' Main function to generate summary and send via email.
#' Requires GMAIL_USERNAME and GMAIL_APP_PASSWORD environment variables.
#'
#' @param recipient Email recipient (default from GMAIL_USERNAME env var)
#' @param sender Email sender (default from GMAIL_USERNAME env var)
#'
#' @export
generate_and_send_summary <- function(
    recipient = Sys.getenv("GMAIL_USERNAME"),
    sender = Sys.getenv("GMAIL_USERNAME")
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

  # Check if we have Gmail credentials
  gmail_user <- Sys.getenv("GMAIL_USERNAME")
  gmail_pass <- Sys.getenv("GMAIL_APP_PASSWORD")

  if (nzchar(gmail_user) && nzchar(gmail_pass)) {
    cli::cli_alert_info("Sending email to {recipient}")

    # Create SMTP credentials for Gmail
    creds <- blastula::creds_envvar(
      user = gmail_user,
      pass_envvar = "GMAIL_APP_PASSWORD",
      host = "smtp.gmail.com",
      port = 465,
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
      html_file <- file.path(tempdir(), paste0("email_summary_", Sys.Date(), ".html"))
      writeLines(as.character(email), html_file)
      cli::cli_alert_info("Email saved to {html_file}")
    })
  } else {
    cli::cli_alert_warning("Gmail credentials not configured (set GMAIL_USERNAME and GMAIL_APP_PASSWORD)")
    # Save to file instead
    html_file <- file.path(tempdir(), paste0("email_summary_", Sys.Date(), ".html"))
    writeLines(as.character(email), html_file)
    cli::cli_alert_info("Summary saved to {html_file}")
  }

  return(invisible(summary))
}