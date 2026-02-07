#' Targets Plan: Dashboard Data Preparation
#'
#' This plan prepares compressed data files for the static dashboard vignette.
#' All data is pre-computed and saved to inst/extdata/ as compressed RDS files.

plan_dashboard <- list(

  # ========================================
  # Dashboard Data Preparation
  # ========================================

  # Prepare main buoy data for dashboard (compressed)
  # Uses dplyr verbs translated to SQL for efficient DuckDB execution
  targets::tar_target(
    dashboard_buoy_data,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      data <- buoy_tbl(con) |>
        dplyr::select(
          "station_id", "time", "wave_height", "hmax", "wave_period",
          "wind_speed", "gust", "wind_direction", "atmospheric_pressure",
          "air_temperature", "sea_temperature"
        ) |>
        dplyr::arrange(.data$station_id, .data$time) |>
        dplyr::collect()

      # Convert time
      data$time <- as.POSIXct(data$time, tz = "UTC")

      cli::cli_alert_success("Prepared {nrow(data)} records for dashboard")
      data
    }
  ),

  # Calculate dashboard statistics
  targets::tar_target(
    dashboard_stats,
    {
      data <- dashboard_buoy_data

      # Station-level statistics
      station_stats <- data |>
        dplyr::group_by(station_id) |>
        dplyr::summarise(
          n_records = dplyr::n(),
          first_date = min(time, na.rm = TRUE),
          last_date = max(time, na.rm = TRUE),
          mean_wave_height = mean(wave_height, na.rm = TRUE),
          max_wave_height = max(wave_height, na.rm = TRUE),
          max_hmax = max(hmax, na.rm = TRUE),
          mean_wind_speed = mean(wind_speed, na.rm = TRUE),
          max_wind_speed = max(wind_speed, na.rm = TRUE),
          max_gust = max(gust, na.rm = TRUE),
          .groups = "drop"
        )

      # Overall statistics
      overall_stats <- list(
        total_records = nrow(data),
        date_range = range(data$time, na.rm = TRUE),
        stations = unique(data$station_id),
        wind_wave_correlation = cor(data$wind_speed, data$wave_height, use = "complete.obs"),
        wave_hmax_correlation = cor(data$wave_height, data$hmax, use = "complete.obs")
      )

      list(
        station = station_stats,
        overall = overall_stats
      )
    }
  ),

  # Prepare time series data for dygraphs (wide format)
  targets::tar_target(
    dashboard_timeseries,
    {
      data <- dashboard_buoy_data

      # Wave height by station (wide format for dygraphs)
      wave_wide <- data |>
        dplyr::select(time, station_id, wave_height) |>
        tidyr::pivot_wider(
          names_from = station_id,
          values_from = wave_height
        ) |>
        dplyr::arrange(time)

      # Wind speed by station (wide format for dygraphs)
      wind_wide <- data |>
        dplyr::select(time, station_id, wind_speed) |>
        tidyr::pivot_wider(
          names_from = station_id,
          values_from = wind_speed
        ) |>
        dplyr::arrange(time)

      list(
        wave_height = wave_wide,
        wind_speed = wind_wide
      )
    }
  ),

  # Save dashboard data to inst/extdata
  targets::tar_target(
    save_dashboard_data,
    {
      # Create directory if needed
      dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

      # Save main buoy data (compressed)
      saveRDS(dashboard_buoy_data, "inst/extdata/dashboard_buoy_data.rds", compress = "xz")

      # Save statistics
      saveRDS(dashboard_stats, "inst/extdata/dashboard_stats.rds", compress = "xz")

      # Save time series data for dygraphs
      saveRDS(dashboard_timeseries, "inst/extdata/dashboard_timeseries.rds", compress = "xz")

      # Get file sizes
      files <- c(
        "inst/extdata/dashboard_buoy_data.rds",
        "inst/extdata/dashboard_stats.rds",
        "inst/extdata/dashboard_timeseries.rds"
      )

      sizes <- file.info(files)$size
      total_size <- sum(sizes)

      cli::cli_alert_success("Saved dashboard data to inst/extdata/")
      cli::cli_alert_info("Total size: {round(total_size / 1024, 1)} KB")

      list(
        files = files,
        sizes = sizes,
        total_size = total_size
      )
    }
  )
)
