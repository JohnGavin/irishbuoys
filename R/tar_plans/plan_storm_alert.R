# plan_storm_alert.R - Daily storm alert pipeline
# Fetches wind forecasts from Open-Meteo, detects gale-force events,
# and sends an email alert when storms are forecast.
# Requires GMAIL_USERNAME and GMAIL_APP_PASSWORD secrets in CI.

plan_storm_alert <- list(
  # Station info for forecast queries
  targets::tar_target(
    storm_station_info,
    get_station_info()
  ),

  # Fetch wind forecasts for all stations
  targets::tar_target(
    storm_forecasts,
    fetch_all_forecasts(station_info = storm_station_info, forecast_days = 7)
  ),

  # Detect storm events above threshold
  targets::tar_target(
    storm_events,
    detect_storm_events(storm_forecasts)
  ),

  # Fetch Met Eireann marine warnings (best-effort)
  targets::tar_target(
    met_warnings,
    fetch_met_eireann_warnings()
  ),

  # Create and send storm alert email (only if storms detected)
  targets::tar_target(
    storm_alert_sent,
    {
      if (nrow(storm_events) == 0) {
        cli::cli_alert_success("No storms detected - skipping email")
        return(list(status = "no_storms", n_storms = 0, time = Sys.time()))
      }

      email <- create_storm_alert_email(
        storm_events,
        station_info = storm_station_info,
        met_warnings = met_warnings
      )

      gmail_user <- Sys.getenv("GMAIL_USERNAME")
      gmail_pass <- Sys.getenv("GMAIL_APP_PASSWORD")

      subject <- paste0(
        "STORM ALERT: Beaufort ", max(storm_events$beaufort),
        " forecast at ", paste(unique(storm_events$station_id), collapse = "/"),
        " - ", format(Sys.Date(), "%d %b %Y")
      )

      if (nzchar(gmail_user) && nzchar(gmail_pass)) {
        cli::cli_alert_info("Sending storm alert to {gmail_user}")

        creds <- blastula::creds_envvar(
          user = gmail_user,
          pass_envvar = "GMAIL_APP_PASSWORD",
          host = "smtp.gmail.com",
          port = 465,
          use_ssl = TRUE
        )

        tryCatch({
          blastula::smtp_send(
            email = email,
            to = gmail_user,
            from = gmail_user,
            subject = subject,
            credentials = creds
          )
          cli::cli_alert_success("Storm alert sent successfully")
          list(
            status = "sent",
            n_storms = nrow(storm_events),
            stations = unique(storm_events$station_id),
            to = gmail_user,
            time = Sys.time()
          )
        }, error = function(e) {
          cli::cli_alert_danger("Failed to send storm alert: {e$message}")
          preview_file <- file.path(tempdir(), paste0("storm_alert_", Sys.Date(), ".html"))
          writeLines(as.character(email), preview_file)
          list(status = "error", error = e$message, preview = preview_file, time = Sys.time())
        })
      } else {
        cli::cli_alert_info("No Gmail credentials - saving preview")
        preview_file <- file.path(tempdir(), paste0("storm_alert_", Sys.Date(), ".html"))
        writeLines(as.character(email), preview_file)
        cli::cli_alert_success("Preview saved to {preview_file}")
        list(status = "preview", preview = preview_file, time = Sys.time())
      }
    }
  )
)
