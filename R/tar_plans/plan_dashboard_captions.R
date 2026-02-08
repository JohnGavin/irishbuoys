#' Targets Plan: Dashboard Captions
#'
#' This plan generates dynamic captions with actual dates and links
#' for use in dashboard and vignette visualizations.

plan_dashboard_captions <- list(

  # Caption for wave statistics table
  targets::tar_target(
    caption_wave_stats,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      dates <- buoy_tbl(con) |>
        dplyr::summarise(
          min_time = min(.data$time, na.rm = TRUE),
          max_time = max(.data$time, na.rm = TRUE),
          n_hours = dplyr::n()
        ) |>
        dplyr::collect()

      glue::glue(
        "Station statistics from {format(dates$min_time, '%Y-%m-%d')} to ",
        "{format(dates$max_time, '%Y-%m-%d')} ({dates$n_hours} hourly measurements). ",
        "Max Wave (m): largest individual wave per 17.5-min hourly measurement. ",
        "Signif Wave (m): mean of top 1/3 of waves per 17.5-min measurement. ",
        "See [Measurement Window](#reference-measurement-window). ",
        "Max Wave / Signif Wave > 2.0 indicates rogue wave conditions."
      )
    }
  ),

  # Caption for max wave time series
  targets::tar_target(
    caption_max_wave_ts,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      dates <- buoy_tbl(con) |>
        dplyr::summarise(
          min_time = min(.data$time, na.rm = TRUE),
          max_time = max(.data$time, na.rm = TRUE)
        ) |>
        dplyr::collect()

      glue::glue(
        "Hourly Max Wave (m) for all stations from {format(dates$min_time, '%Y-%m-%d %H:%M')} to ",
        "{format(dates$max_time, '%Y-%m-%d %H:%M')}. ",
        "Each point is the tallest individual wave from one 17.5-min measurement. ",
        "See [Column Definitions](#reference-column-names). ",
        "Storm events visible as sharp peaks across multiple stations."
      )
    }
  ),

  # Caption for signif wave time series
  targets::tar_target(
    caption_signif_wave_ts,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      dates <- buoy_tbl(con) |>
        dplyr::summarise(
          min_time = min(.data$time, na.rm = TRUE),
          max_time = max(.data$time, na.rm = TRUE)
        ) |>
        dplyr::collect()

      glue::glue(
        "Hourly Signif Wave (m) for all stations from {format(dates$min_time, '%Y-%m-%d %H:%M')} to ",
        "{format(dates$max_time, '%Y-%m-%d %H:%M')}. ",
        "Signif Wave = mean of highest 1/3 of waves from each 17.5-min measurement. ",
        "See [Column Definitions](#reference-column-names)."
      )
    }
  ),

  # Caption for wind speed time series
  targets::tar_target(
    caption_wind_ts,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      dates <- buoy_tbl(con) |>
        dplyr::summarise(
          min_time = min(.data$time, na.rm = TRUE),
          max_time = max(.data$time, na.rm = TRUE)
        ) |>
        dplyr::collect()

      glue::glue(
        "Hourly Wind Speed (knots) for all stations from {format(dates$min_time, '%Y-%m-%d %H:%M')} to ",
        "{format(dates$max_time, '%Y-%m-%d %H:%M')}. ",
        "Wind Speed is the 10-minute average measured each hour. ",
        "See [Wind Measurement](#reference-wind-measurement)."
      )
    }
  ),

  # Worked example: How Signif Wave is calculated
  targets::tar_target(
    worked_signif_wave_example,
    {
      set.seed(42)
      # Simulate 100 individual wave heights from one 17.5-min measurement
      # Using realistic distribution based on Rayleigh distribution
      individual_waves <- tibble::tibble(
        wave_number = 1:100,
        wave_height_m = round(sort(abs(rnorm(100, mean = 2.5, sd = 0.8)), decreasing = TRUE), 2)
      )

      # Mark top 1/3
      n_top_third <- ceiling(100 / 3)  # = 34
      individual_waves <- individual_waves |>
        dplyr::mutate(in_top_third = wave_number <= n_top_third)

      # Calculate Signif Wave = mean of top 1/3
      signif_wave <- round(mean(individual_waves$wave_height_m[individual_waves$in_top_third]), 2)

      # Max Wave = largest individual wave
      max_wave <- max(individual_waves$wave_height_m)

      # Ratio
      ratio <- round(max_wave / signif_wave, 2)

      list(
        waves_table = individual_waves,
        n_top_third = n_top_third,
        signif_wave = signif_wave,
        max_wave = max_wave,
        ratio = ratio,
        caption = glue::glue(
          "Step-by-step Signif Wave calculation. ",
          "During each 17.5-min measurement, the buoy records ~300 waves (100 shown here). ",
          "'in_top_third' marks the highest {n_top_third} waves. ",
          "Signif Wave = mean(top 1/3) = {signif_wave} m. ",
          "Max Wave = tallest single wave = {max_wave} m. ",
          "Ratio = {ratio} (normal range 1.5-1.9; >2.0 = rogue wave). ",
          "See [Ratios](#reference-ratios)."
        )
      )
    }
  ),

  # Dataset date range for use in all captions
  targets::tar_target(
    dataset_date_range,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      buoy_tbl(con) |>
        dplyr::summarise(
          min_time = min(.data$time, na.rm = TRUE),
          max_time = max(.data$time, na.rm = TRUE),
          n_records = dplyr::n(),
          n_stations = dplyr::n_distinct(.data$station_id)
        ) |>
        dplyr::collect()
    }
  )
)
