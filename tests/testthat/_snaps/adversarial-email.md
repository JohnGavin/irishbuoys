# snapshot: args(connect_duckdb) signature

    Code
      args(connect_duckdb)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", create_new = FALSE) 
      NULL

# snapshot: args(create_email_summary) signature

    Code
      args(create_email_summary)
    Output
      function (summary) 
      NULL

# snapshot: args(generate_and_send_summary) signature

    Code
      args(generate_and_send_summary)
    Output
      function (recipient = Sys.getenv("GMAIL_USERNAME"), sender = Sys.getenv("GMAIL_USERNAME")) 
      NULL

# snapshot: args(generate_weekly_summary) signature

    Code
      args(generate_weekly_summary)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", lookback_days = 7, 
          qc_filter = NULL, update_result = NULL) 
      NULL

# snapshot: args(validate_email_freshness) signature

    Code
      args(validate_email_freshness)
    Output
      function (ingestion_stats, max_stale_hours = 96) 
      NULL

# snapshot pass2: args(add_wave_metrics)

    Code
      args(irishbuoys:::add_wave_metrics)
    Output
      function (data, rogue_threshold = 2) 
      NULL

# snapshot pass2: args(analyze_gust_factor)

    Code
      args(irishbuoys:::analyze_gust_factor)
    Output
      function (data, min_wind_speed = 5) 
      NULL

# snapshot pass2: args(analyze_joint_extremes)

    Code
      args(irishbuoys:::analyze_joint_extremes)
    Output
      function (data, variable = "wave_height", threshold_quantile = 0.95) 
      NULL

# snapshot pass2: args(analyze_parquet_storage)

    Code
      args(irishbuoys:::analyze_parquet_storage)
    Output
      function (data_path = "inst/extdata/parquet") 
      NULL

# snapshot pass2: args(analyze_rogue_statistics)

    Code
      args(irishbuoys:::analyze_rogue_statistics)
    Output
      function (con, threshold = 2, min_wave_height = 2) 
      NULL

# snapshot pass2: args(analyze_station_pairs)

    Code
      args(irishbuoys:::analyze_station_pairs)
    Output
      function (data, variable = "wave_height", max_lag = 48) 
      NULL

# snapshot pass2: args(beaufort_to_description)

    Code
      args(irishbuoys:::beaufort_to_description)
    Output
      function (beaufort) 
      NULL

# snapshot pass2: args(buoy_tbl)

    Code
      args(irishbuoys:::buoy_tbl)
    Output
      function (con, table_name = "buoy_data") 
      NULL

# snapshot pass2: args(calculate_annual_trends)

    Code
      args(irishbuoys:::calculate_annual_trends)
    Output
      function (data, variable = "wave_height", time_col = "time") 
      NULL

# snapshot pass2: args(calculate_gpd_return_levels)

    Code
      args(irishbuoys:::calculate_gpd_return_levels)
    Output
      function (gpd_fit, return_periods = c(1, 5, 10), n_obs_per_year = 8760, 
          n_total = NULL, exceedance_rate = NULL, conf_level = 0.95) 
      NULL

# snapshot pass2: args(calculate_hs_from_elevation)

    Code
      args(irishbuoys:::calculate_hs_from_elevation)
    Output
      function (elevations) 
      NULL

# snapshot pass2: args(calculate_return_levels)

    Code
      args(irishbuoys:::calculate_return_levels)
    Output
      function (fit, return_periods = c(10, 50, 100), conf_level = 0.95) 
      NULL

# snapshot pass2: args(calculate_rms_wave_height)

    Code
      args(irishbuoys:::calculate_rms_wave_height)
    Output
      function (wave_heights) 
      NULL

# snap3: args(calculate_seasonal_means)

    Code
      args(irishbuoys:::calculate_seasonal_means)
    Output
      function (data, variable = "wave_height", time_col = "time") 
      NULL

# snap3: args(calculate_wave_steepness)

    Code
      args(irishbuoys:::calculate_wave_steepness)
    Output
      function (wave_height, wave_period) 
      NULL

# snap3: args(ci_bootstrap_return_levels)

    Code
      args(irishbuoys:::ci_bootstrap_return_levels)
    Output
      function (data, variable, return_periods = c(1, 5, 10), n_boot = 500, 
          conf_level = 0.95, block_size = NULL, threshold_quantile = 0.95, 
          n_obs_per_year = 8760, seed = 42) 
      NULL

# snap3: args(ci_order_statistics)

    Code
      args(irishbuoys:::ci_order_statistics)
    Output
      function (x, probs, conf_level = 0.95) 
      NULL

# snap3: args(ci_parametric_bootstrap)

    Code
      args(irishbuoys:::ci_parametric_bootstrap)
    Output
      function (gpd_fit, n_boot = 500, return_periods = c(1, 5, 10), 
          conf_level = 0.95, n_obs_per_year = 8760, seed = 42) 
      NULL

# snap3: args(compare_rogue_wave_gust)

    Code
      args(irishbuoys:::compare_rogue_wave_gust)
    Output
      function (data) 
      NULL

