#' Targets Plan: Wave Analysis
#'
#' This plan performs comprehensive wave analysis including:
#' - Rogue wave detection and analysis
#' - Trend decomposition (seasonal and long-term)
#' - Extreme value analysis with return levels
#' - Gust factor analysis
#'
#' Uses crew for parallel execution where beneficial.

plan_wave_analysis <- list(


  # ========================================
  # Data Loading
  # ========================================

  # Load all historical data from DuckDB
  targets::tar_target(
    analysis_data,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      data <- DBI::dbGetQuery(con, "
        SELECT
          station_id,
          time,
          wave_height,
          hmax,
          wave_period,
          tp,
          wind_speed,
          wind_direction,
          gust,
          atmospheric_pressure,
          sea_temperature,
          qc_flag
        FROM buoy_data
        WHERE wave_height IS NOT NULL
          AND qc_flag IS NOT NULL
        ORDER BY station_id, time
      ")

      # Convert time
      data$time <- as.POSIXct(data$time, tz = "UTC")

      cli::cli_alert_success("Loaded {nrow(data)} QC-passed observations")
      data
    }
  ),

  # ========================================
  # Rogue Wave Analysis
  # ========================================

  # Detect rogue waves across all data
  targets::tar_target(
    rogue_wave_events,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      detect_rogue_waves(con, threshold = 2.0, min_wave_height = 2.0)
    }
  ),

  # Analyze rogue wave statistics
  targets::tar_target(
    rogue_wave_statistics,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      analyze_rogue_statistics(con, threshold = 2.0, min_wave_height = 2.0)
    }
  ),

  # Analyze conditions associated with rogue waves
  targets::tar_target(
    rogue_wave_conditions,
    {
      # Add weather condition categories
      rogues <- rogue_wave_events

      if (nrow(rogues) > 0) {
        # Wind speed categories
        rogues$wind_category <- dplyr::case_when(
          rogues$wind_speed < 5 ~ "Calm (<5 m/s)",
          rogues$wind_speed < 10 ~ "Light (5-10 m/s)",
          rogues$wind_speed < 15 ~ "Moderate (10-15 m/s)",
          rogues$wind_speed < 20 ~ "Fresh (15-20 m/s)",
          TRUE ~ "Strong (>20 m/s)"
        )

        # Station depth categories (approximate)
        # M2, M3, M4, M5 are deep water; M6 is shelf edge
        rogues$depth_category <- dplyr::case_when(
          rogues$station_id %in% c("M2", "M3", "M4", "M5") ~ "Deep Water",
          rogues$station_id == "M6" ~ "Shelf Edge",
          TRUE ~ "Unknown"
        )

        # Time of day
        rogues$hour <- as.integer(format(rogues$time, "%H"))
        rogues$time_of_day <- dplyr::case_when(
          rogues$hour >= 6 & rogues$hour < 12 ~ "Morning",
          rogues$hour >= 12 & rogues$hour < 18 ~ "Afternoon",
          rogues$hour >= 18 & rogues$hour < 22 ~ "Evening",
          TRUE ~ "Night"
        )

        # Season
        rogues$month <- as.integer(format(rogues$time, "%m"))
        rogues$season <- dplyr::case_when(
          rogues$month %in% c(12, 1, 2) ~ "Winter",
          rogues$month %in% c(3, 4, 5) ~ "Spring",
          rogues$month %in% c(6, 7, 8) ~ "Summer",
          rogues$month %in% c(9, 10, 11) ~ "Autumn"
        )
      }

      rogues
    }
  ),

  # ========================================
  # Trend Analysis
  # ========================================

  # Seasonal decomposition of wave heights
  targets::tar_target(
    wave_height_seasonal,
    {
      # Use M3 as representative station (longest continuous record)
      m3_data <- analysis_data[analysis_data$station_id == "M3", ]

      if (nrow(m3_data) >= 168) {  # At least 1 week
        decompose_stl(m3_data, variable = "wave_height", frequency = "daily")
      } else {
        cli::cli_alert_warning("Insufficient M3 data for STL decomposition")
        NULL
      }
    }
  ),

  # Seasonal means by variable
  targets::tar_target(
    seasonal_means_wave,
    calculate_seasonal_means(analysis_data, variable = "wave_height")
  ),

  targets::tar_target(
    seasonal_means_wind,
    calculate_seasonal_means(analysis_data, variable = "wind_speed")
  ),

  # Annual trends
  targets::tar_target(
    annual_trends_wave,
    calculate_annual_trends(analysis_data, variable = "wave_height")
  ),

  targets::tar_target(
    annual_trends_wind,
    calculate_annual_trends(analysis_data, variable = "wind_speed")
  ),

  # Anomaly detection
  targets::tar_target(
    wave_anomalies,
    detect_anomalies(analysis_data, variable = "wave_height", threshold = 3)
  ),

  # ========================================
  # Extreme Value Analysis
  # ========================================

  # Fit GEV to annual maximum wave heights (all stations combined)
  targets::tar_target(
    gev_wave_height,
    {
      # Filter for valid wave heights
      wave_data <- analysis_data[!is.na(analysis_data$wave_height), ]
      fit_gev_annual_maxima(wave_data, variable = "wave_height")
    }
  ),

  # Calculate wave height return levels
  targets::tar_target(
    return_levels_wave,
    calculate_return_levels(gev_wave_height, c(10, 50, 100))
  ),

  # Fit GEV to annual maximum wind speeds
  targets::tar_target(
    gev_wind_speed,
    {
      wind_data <- analysis_data[!is.na(analysis_data$wind_speed), ]
      fit_gev_annual_maxima(wind_data, variable = "wind_speed")
    }
  ),

  # Calculate wind speed return levels
  targets::tar_target(
    return_levels_wind,
    calculate_return_levels(gev_wind_speed, c(10, 50, 100))
  ),

  # Fit GEV to annual maximum Hmax
  targets::tar_target(
    gev_hmax,
    {
      hmax_data <- analysis_data[!is.na(analysis_data$hmax), ]
      fit_gev_annual_maxima(hmax_data, variable = "hmax")
    }
  ),

  targets::tar_target(
    return_levels_hmax,
    calculate_return_levels(gev_hmax, c(10, 50, 100))
  ),

  # Return level plot data for visualization
  targets::tar_target(
    return_level_curves_wave,
    create_return_level_plot_data(gev_wave_height, max_return_period = 200)
  ),

  targets::tar_target(
    return_level_curves_wind,
    create_return_level_plot_data(gev_wind_speed, max_return_period = 200)
  ),

  # ========================================
  # Gust Factor Analysis ("Rogue Wind")
  # ========================================

  targets::tar_target(
    gust_factor_analysis,
    analyze_gust_factor(analysis_data, min_wind_speed = 5)
  ),

  # Compare rogue wave vs rogue gust occurrence
  targets::tar_target(
    rogue_comparison,
    compare_rogue_wave_gust(analysis_data)
  ),

  # ========================================
  # Summary Reports
  # ========================================

  # Comprehensive analysis summary
  targets::tar_target(
    analysis_summary,
    {
      list(
        data_summary = list(
          n_observations = nrow(analysis_data),
          stations = unique(analysis_data$station_id),
          date_range = range(analysis_data$time),
          variables = names(analysis_data)
        ),
        rogue_waves = list(
          n_events = nrow(rogue_wave_events),
          statistics = rogue_wave_statistics
        ),
        trends = list(
          seasonal_wave = seasonal_means_wave,
          seasonal_wind = seasonal_means_wind,
          annual_wave = annual_trends_wave,
          annual_wind = annual_trends_wind
        ),
        extremes = list(
          wave_return_levels = return_levels_wave,
          wind_return_levels = return_levels_wind,
          hmax_return_levels = return_levels_hmax
        ),
        gev_fits = list(
          wave_height = list(
            parameters = gev_wave_height$parameters,
            n_years = gev_wave_height$n_years,
            annual_maxima = gev_wave_height$annual_maxima
          ),
          hmax = list(
            parameters = gev_hmax$parameters,
            n_years = gev_hmax$n_years,
            annual_maxima = gev_hmax$annual_maxima
          ),
          wind_speed = list(
            parameters = gev_wind_speed$parameters,
            n_years = gev_wind_speed$n_years,
            annual_maxima = gev_wind_speed$annual_maxima
          )
        ),
        gust_analysis = gust_factor_analysis,
        rogue_comparison = rogue_comparison,
        generated = Sys.time()
      )
    }
  ),

  # Save key results to inst/extdata for vignette
  targets::tar_target(
    save_vignette_data,
    {
      # Create directory if needed
      dir.create("inst/extdata", recursive = TRUE, showWarnings = FALSE)

      # Save analysis summary
      saveRDS(analysis_summary, "inst/extdata/wave_analysis_summary.rds")

      # Save rogue wave events
      saveRDS(rogue_wave_conditions, "inst/extdata/rogue_wave_events.rds")

      # Save return level data
      saveRDS(
        list(
          wave = return_levels_wave,
          wind = return_levels_wind,
          hmax = return_levels_hmax,
          wave_curve = return_level_curves_wave,
          wind_curve = return_level_curves_wind
        ),
        "inst/extdata/return_levels.rds"
      )

      # Save seasonal data
      saveRDS(
        list(
          wave = seasonal_means_wave,
          wind = seasonal_means_wind,
          stl = wave_height_seasonal
        ),
        "inst/extdata/seasonal_analysis.rds"
      )

      cli::cli_alert_success("Saved vignette data to inst/extdata/")

      TRUE
    }
  )
)
