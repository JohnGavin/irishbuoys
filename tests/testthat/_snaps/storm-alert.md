# snapshot: args(beaufort_to_description) signature

    Code
      args(beaufort_to_description)
    Output
      function (beaufort) 
      NULL

# snapshot: args(create_storm_alert_email) signature

    Code
      args(create_storm_alert_email)
    Output
      function (storm_events, station_info = get_station_info(), all_forecasts = NULL, 
          threshold_knots = 41, met_warnings = NULL, forecast_rogue_summary = NULL) 
      NULL

# snapshot: args(detect_storm_events) signature

    Code
      args(detect_storm_events)
    Output
      function (forecasts, threshold_knots = NULL, use_gusts = FALSE) 
      NULL

# snapshot: args(fetch_all_forecasts) signature

    Code
      args(fetch_all_forecasts)
    Output
      function (station_info = get_station_info(), forecast_days = 7, 
          timeout = 30) 
      NULL

# snapshot: args(fetch_open_meteo_forecast) signature

    Code
      args(fetch_open_meteo_forecast)
    Output
      function (lat, lon, station_id, forecast_days = 7, timeout = 30) 
      NULL

# snapshot: args(fetch_open_meteo_marine) signature

    Code
      args(fetch_open_meteo_marine)
    Output
      function (lat, lon, station_id, forecast_days = 7, timeout = 30) 
      NULL

# snapshot: args(knots_to_beaufort) signature

    Code
      args(knots_to_beaufort)
    Output
      function (wind_speed_kn) 
      NULL

# snapshot: args(p_hmax_exceedance) signature

    Code
      args(p_hmax_exceedance)
    Output
      function (h, hs, tz, duration_s = 3600, alpha = 0.681, beta = 2.126) 
      NULL

# snapshot: args(send_storm_alert) signature

    Code
      args(send_storm_alert)
    Output
      function (threshold_knots = NULL, recipient = Sys.getenv("GMAIL_USERNAME"), 
          sender = Sys.getenv("GMAIL_USERNAME"), dry_run = FALSE) 
      NULL

# snapshot pass2: args(summarise_forecast_rogue_risk)

    Code
      args(irishbuoys:::summarise_forecast_rogue_risk)
    Output
      function (marine_forecasts, thresholds = c(10, 15, 20, 25), duration_s = 3600) 
      NULL

# snapshot pass2: args(add_wave_metrics)

    Code
      args(irishbuoys:::add_wave_metrics)
    Output
      function (data, rogue_threshold = 2) 
      NULL

# snap3: args(analyze_gust_factor)

    Code
      args(irishbuoys:::analyze_gust_factor)
    Output
      function (data, min_wind_speed = 5) 
      NULL

# snap3: args(analyze_joint_extremes)

    Code
      args(irishbuoys:::analyze_joint_extremes)
    Output
      function (data, variable = "wave_height", threshold_quantile = 0.95) 
      NULL

