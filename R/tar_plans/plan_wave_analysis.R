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

  # Load all historical data from DuckDB (filtered for analysis)
  # Uses dplyr verbs translated to SQL for efficient DuckDB execution
  targets::tar_target(
    analysis_data,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      data <- buoy_tbl(con) |>
        dplyr::filter(
          !is.na(.data$wave_height),
          !is.na(.data$qc_flag)
        ) |>
        dplyr::select(
          "station_id", "time", "wave_height", "hmax", "wave_period", "tp",
          "wind_speed", "wind_direction", "gust", "atmospheric_pressure",
          "sea_temperature", "qc_flag"
        ) |>
        dplyr::arrange(.data$station_id, .data$time) |>
        dplyr::collect()

      # Convert time
      data$time <- as.POSIXct(data$time, tz = "UTC")

      cli::cli_alert_success("Loaded {nrow(data)} QC-passed observations")
      data
    }
  ),

  # Load ALL 22 columns for data glimpse (sample for display)
  # Uses dplyr verbs for efficient DuckDB execution
  targets::tar_target(
    full_data,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      # Get sample of all columns for glimpse
      data <- buoy_tbl(con) |>
        utils::head(10000) |>
        dplyr::collect()
      data$time <- as.POSIXct(data$time, tz = "UTC")

      cli::cli_alert_success("Loaded sample of {nrow(data)} rows (all 22 columns)")
      data
    }
  ),

  # Missing data grid: daily observation counts by station
  targets::tar_target(
    missing_data_grid,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      # Count observations per day per station for key variables
      DBI::dbGetQuery(con, "
        SELECT
          station_id,
          DATE_TRUNC('day', time) AS date,
          COUNT(*) AS n_obs,
          COUNT(wave_height) AS n_wave_height,
          COUNT(hmax) AS n_hmax,
          COUNT(wind_speed) AS n_wind_speed,
          COUNT(gust) AS n_gust,
          COUNT(atmospheric_pressure) AS n_pressure,
          COUNT(sea_temperature) AS n_sea_temp
        FROM buoy_data
        GROUP BY station_id, DATE_TRUNC('day', time)
        ORDER BY station_id, date
      ")
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
  # Extreme Value Analysis - GPD Per-Station (using mev package)
  # ========================================

  # GPD per-station wave height using mev::fit.gpd() directly
  targets::tar_target(
    gpd_wave_per_station,
    {
      stations <- unique(analysis_data$station_id)
      thresholds <- c(low = 0.90, medium = 0.95, high = 0.99)

      results <- lapply(stations, function(st) {
        d <- analysis_data[analysis_data$station_id == st & !is.na(analysis_data$wave_height), ]

        station_results <- lapply(names(thresholds), function(thr_name) {
          u <- stats::quantile(d$wave_height, thresholds[thr_name])
          exceedances <- d$wave_height[d$wave_height > u]

          if (length(exceedances) < 30) {
            return(list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances), error = "Insufficient exceedances (<30)"
            ))
          }

          tryCatch({
            # Use mev::fit.gpd() which returns scale and shape parameters
            fit <- mev::fit.gpd(xdat = exceedances, threshold = as.numeric(u))
            list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances),
              scale = fit$estimate["scale"],
              shape = fit$estimate["shape"],
              se_scale = fit$std.err["scale"],
              se_shape = fit$std.err["shape"]
            )
          }, error = function(e) {
            list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances), error = e$message
            )
          })
        })
        names(station_results) <- names(thresholds)
        station_results
      })
      names(results) <- stations
      results
    }
  ),

  # GPD per-station wind speed using mev::fit.gpd()
  targets::tar_target(
    gpd_wind_per_station,
    {
      stations <- unique(analysis_data$station_id)
      thresholds <- c(low = 0.90, medium = 0.95, high = 0.99)

      results <- lapply(stations, function(st) {
        d <- analysis_data[analysis_data$station_id == st & !is.na(analysis_data$wind_speed), ]

        station_results <- lapply(names(thresholds), function(thr_name) {
          u <- stats::quantile(d$wind_speed, thresholds[thr_name])
          exceedances <- d$wind_speed[d$wind_speed > u]

          if (length(exceedances) < 30) {
            return(list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances), error = "Insufficient exceedances (<30)"
            ))
          }

          tryCatch({
            fit <- mev::fit.gpd(xdat = exceedances, threshold = as.numeric(u))
            list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances),
              scale = fit$estimate["scale"],
              shape = fit$estimate["shape"],
              se_scale = fit$std.err["scale"],
              se_shape = fit$std.err["shape"]
            )
          }, error = function(e) {
            list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances), error = e$message
            )
          })
        })
        names(station_results) <- names(thresholds)
        station_results
      })
      names(results) <- stations
      results
    }
  ),

  # GPD per-station Hmax using mev::fit.gpd()
  targets::tar_target(
    gpd_hmax_per_station,
    {
      stations <- unique(analysis_data$station_id)
      thresholds <- c(low = 0.90, medium = 0.95, high = 0.99)

      results <- lapply(stations, function(st) {
        d <- analysis_data[analysis_data$station_id == st & !is.na(analysis_data$hmax), ]

        station_results <- lapply(names(thresholds), function(thr_name) {
          u <- stats::quantile(d$hmax, thresholds[thr_name])
          exceedances <- d$hmax[d$hmax > u]

          if (length(exceedances) < 30) {
            return(list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances), error = "Insufficient exceedances (<30)"
            ))
          }

          tryCatch({
            fit <- mev::fit.gpd(xdat = exceedances, threshold = as.numeric(u))
            list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances),
              scale = fit$estimate["scale"],
              shape = fit$estimate["shape"],
              se_scale = fit$std.err["scale"],
              se_shape = fit$std.err["shape"]
            )
          }, error = function(e) {
            list(
              station = st, threshold = thr_name, u = as.numeric(u),
              n_exceed = length(exceedances), error = e$message
            )
          })
        })
        names(station_results) <- names(thresholds)
        station_results
      })
      names(results) <- stations
      results
    }
  ),

  # ========================================
  # GEV Pooled Analysis (illustrative, n=8 years only)
  # ========================================

  # Fit GEV to annual maximum wave heights (all stations combined)
  # NOTE: Limited to ~8 annual maxima - illustrative only
  targets::tar_target(
    gev_wave_pooled,
    {
      wave_data <- analysis_data[!is.na(analysis_data$wave_height), ]
      fit_gev_annual_maxima(wave_data, variable = "wave_height")
    }
  ),

  # GEV return levels (pooled, illustrative)
  targets::tar_target(
    return_levels_wave_pooled,
    calculate_return_levels(gev_wave_pooled, c(10, 50, 100))
  ),

  # Fit GEV to annual maximum wind speeds (pooled)
  targets::tar_target(
    gev_wind_pooled,
    {
      wind_data <- analysis_data[!is.na(analysis_data$wind_speed), ]
      fit_gev_annual_maxima(wind_data, variable = "wind_speed")
    }
  ),

  targets::tar_target(
    return_levels_wind_pooled,
    calculate_return_levels(gev_wind_pooled, c(10, 50, 100))
  ),

  # Fit GEV to annual maximum Hmax (pooled)
  targets::tar_target(
    gev_hmax_pooled,
    {
      hmax_data <- analysis_data[!is.na(analysis_data$hmax), ]
      fit_gev_annual_maxima(hmax_data, variable = "hmax")
    }
  ),

  targets::tar_target(
    return_levels_hmax_pooled,
    calculate_return_levels(gev_hmax_pooled, c(10, 50, 100))
  ),

  # Return level plot data for visualization (pooled GEV)
  targets::tar_target(
    return_level_curves_wave,
    create_return_level_plot_data(gev_wave_pooled, max_return_period = 200)
  ),

  targets::tar_target(
    return_level_curves_wind,
    create_return_level_plot_data(gev_wind_pooled, max_return_period = 200)
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
          gpd_wave = gpd_wave_per_station,
          gpd_wind = gpd_wind_per_station,
          gpd_hmax = gpd_hmax_per_station,
          gev_wave_pooled = return_levels_wave_pooled,
          gev_wind_pooled = return_levels_wind_pooled,
          gev_hmax_pooled = return_levels_hmax_pooled
        ),
        gev_pooled_fits = list(
          wave_height = list(
            parameters = gev_wave_pooled$parameters,
            n_years = gev_wave_pooled$n_years,
            annual_maxima = gev_wave_pooled$annual_maxima
          ),
          hmax = list(
            parameters = gev_hmax_pooled$parameters,
            n_years = gev_hmax_pooled$n_years,
            annual_maxima = gev_hmax_pooled$annual_maxima
          ),
          wind_speed = list(
            parameters = gev_wind_pooled$parameters,
            n_years = gev_wind_pooled$n_years,
            annual_maxima = gev_wind_pooled$annual_maxima
          )
        ),
        gust_analysis = gust_factor_analysis,
        rogue_comparison = rogue_comparison,
        generated = Sys.time()
      )
    }
  ),

  # ========================================
  # Pre-computed Plots (for vignettes)
  # ========================================

  # All stations rogue wave scatter plot
  # Sample to max 2000 events to reduce HTML size (keep most extreme)
  targets::tar_target(
    plot_rogue_all,
    {
      events <- rogue_wave_events
      if (nrow(events) > 2000) {
        events <- events[order(-events$rogue_ratio), ][1:2000, ]
      }
      create_plot_rogue_all(events)
    }
  ),

  # Rogue waves by station subplot with rangeslider
  # Sample to max 500 events per station to reduce HTML size
  targets::tar_target(
    plot_rogue_by_station,
    {
      events <- rogue_wave_events
      if (nrow(events) > 2500) {
        # Keep top events per station
        events <- events |>
          dplyr::group_by(station_id) |>
          dplyr::slice_max(order_by = rogue_ratio, n = 500) |>
          dplyr::ungroup()
      }
      create_plot_rogue_by_station(events)
    }
  ),

  # Wind speed by Beaufort scale
  targets::tar_target(
    plot_wind_beaufort,
    create_plot_wind_beaufort(rogue_wave_conditions)
  ),

  # Week of year stacked bar
  targets::tar_target(
    plot_week_of_year,
    create_plot_week_of_year(rogue_wave_conditions)
  ),

  # Time of day bar plot
  targets::tar_target(
    plot_time_of_day,
    create_plot_time_of_day(rogue_wave_conditions)
  ),

  # Monthly wave height bar plot
  targets::tar_target(
    plot_monthly_wave,
    create_plot_monthly_wave(seasonal_means_wave)
  ),

  # Monthly wind speed bar plot
  targets::tar_target(
    plot_monthly_wind,
    create_plot_monthly_wind(seasonal_means_wind)
  ),

  # Annual trends line plot
  targets::tar_target(
    plot_annual_trends,
    create_plot_annual_trends(annual_trends_wave)
  ),

  # Return levels plots
  targets::tar_target(
    plot_return_levels_wave,
    create_plot_return_levels(return_levels_wave_pooled, variable = "wave")
  ),

  targets::tar_target(
    plot_return_levels_wind,
    create_plot_return_levels(return_levels_wind_pooled, variable = "wind")
  ),

  targets::tar_target(
    plot_return_levels_hmax,
    create_plot_return_levels(return_levels_hmax_pooled, variable = "hmax")
  ),

  # Gust factor plots
  targets::tar_target(
    plot_gust_by_category,
    create_plot_gust_by_category(gust_factor_analysis)
  ),

  targets::tar_target(
    plot_rogue_gusts,
    create_plot_rogue_gusts(gust_factor_analysis)
  ),

  # STL decomposition plot (pre-computed)
  targets::tar_target(
    plot_stl,
    create_plot_stl(wave_height_seasonal)
  ),

  # Rogue gust events (gust_ratio > 1.5)
  targets::tar_target(
    rogue_gust_events,
    analysis_data |>
      dplyr::filter(!is.na(.data$gust), !is.na(.data$wind_speed), .data$wind_speed > 0) |>
      dplyr::mutate(gust_ratio = .data$gust / .data$wind_speed) |>
      dplyr::filter(.data$gust_ratio > 1.5) |>
      dplyr::select(.data$time, .data$station_id, .data$wind_speed, .data$gust,
                    .data$gust_ratio, .data$wave_height, .data$hmax)
  ),

  # Rogue gusts plots (new Rogue Gusts page)
  targets::tar_target(
    plot_rogue_gusts_all,
    create_plot_rogue_gusts_all(rogue_gust_events)
  ),

  targets::tar_target(
    plot_rogue_gusts_by_station,
    create_plot_rogue_gusts_by_station(rogue_gust_events)
  ),

  targets::tar_target(
    plot_gusts_vs_waves,
    create_plot_gusts_vs_waves(analysis_data)
  )
)
