# plan_email_report.R - Weekly email report pipeline
# Generates and optionally sends weekly summary email via Gmail.
# Requires GMAIL_USERNAME and GMAIL_APP_PASSWORD secrets in CI.

plan_email_report <- list(
  # Generate weekly summary data
  # data_update dependency ensures fresh data before email generation
  targets::tar_target(
    email_summary_data,
    generate_weekly_summary(
      db_path = "inst/extdata/irish_buoys.duckdb",
      lookback_days = 7,
      update_result = data_update
    )
  ),

  # Create HTML email from summary
  targets::tar_target(
    email_html,
    withCallingHandlers(
      create_email_summary(email_summary_data),
      error = function(e) {
        message("email_html traceback:")
        message(paste(capture.output(traceback()), collapse = "\n"))
      }
    )
  ),

  # Send email or save preview
  # Freshness check HERE (not in email_summary_data) because this target

  # always runs even when email_summary_data is cached from targets-runs.
  targets::tar_target(
    email_sent,
    {
      # Gate: refuse to send stale emails
      stats <- email_summary_data$ingestion_stats
      if (!is.null(stats) && nrow(stats) > 0) {
        validate_email_freshness(stats, max_stale_hours = 96)
      } else {
        cli::cli_abort(c(
          "x" = "Refusing to send email: no ingestion data available.",
          "i" = "The data_update target may have failed or returned cached stale data."
        ))
      }

      gmail_user <- Sys.getenv("GMAIL_USERNAME")
      gmail_pass <- Sys.getenv("GMAIL_APP_PASSWORD")

      subject <- paste0(
        "Irish Buoy Network Weekly Report - ",
        format(Sys.Date(), "%B %d, %Y")
      )

      if (nzchar(gmail_user) && nzchar(gmail_pass)) {
        cli::cli_alert_info("Sending email to {gmail_user}")

        creds <- blastula::creds_envvar(
          user = gmail_user,
          pass_envvar = "GMAIL_APP_PASSWORD",
          host = "smtp.gmail.com",
          port = 465,
          use_ssl = TRUE
        )

        tryCatch({
          blastula::smtp_send(
            email = email_html,
            to = gmail_user,
            from = gmail_user,
            subject = subject,
            credentials = creds
          )
          cli::cli_alert_success("Email sent successfully")
          list(status = "sent", to = gmail_user, time = Sys.time())
        }, error = function(e) {
          cli::cli_alert_danger("Failed to send email: {e$message}")
          preview_file <- file.path(tempdir(), paste0("email_preview_", Sys.Date(), ".html"))
          writeLines(as.character(email_html), preview_file)
          list(status = "error", error = e$message, preview = preview_file, time = Sys.time())
        })
      } else {
        cli::cli_alert_info("No Gmail credentials - saving preview")
        preview_file <- file.path(tempdir(), paste0("email_preview_", Sys.Date(), ".html"))
        writeLines(as.character(email_html), preview_file)
        cli::cli_alert_success("Preview saved to {preview_file}")
        list(status = "preview", preview = preview_file, time = Sys.time())
      }
    }
  )
)
