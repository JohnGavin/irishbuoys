# snapshot: args(evaluate_wave_model) signature

    Code
      args(evaluate_wave_model)
    Output
      function (model_result, data, target = "wave_height") 
      NULL

# snapshot: args(predict_wave_height) signature

    Code
      args(predict_wave_height)
    Output
      function (model_result, new_data) 
      NULL

# snapshot: args(prepare_wave_features) signature

    Code
      args(prepare_wave_features)
    Output
      function (data, lags = 1:3) 
      NULL

# snapshot: args(train_wave_model) signature

    Code
      args(train_wave_model)
    Output
      function (data, target = "wave_height", predictors = NULL, train_fraction = 0.7, 
          seed = 42, ...) 
      NULL

# snapshot: args(wave_model_report) signature

    Code
      args(wave_model_report)
    Output
      function (model_result, eval_result) 
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

# snap3: args(calculate_gpd_return_levels)

    Code
      args(irishbuoys:::calculate_gpd_return_levels)
    Output
      function (gpd_fit, return_periods = c(1, 5, 10), n_obs_per_year = 8760, 
          n_total = NULL, exceedance_rate = NULL, conf_level = 0.95) 
      NULL

# snap3: args(calculate_hs_from_elevation)

    Code
      args(irishbuoys:::calculate_hs_from_elevation)
    Output
      function (elevations) 
      NULL

# snap3: args(calculate_return_levels)

    Code
      args(irishbuoys:::calculate_return_levels)
    Output
      function (fit, return_periods = c(10, 50, 100), conf_level = 0.95) 
      NULL

# snap3: args(calculate_rms_wave_height)

    Code
      args(irishbuoys:::calculate_rms_wave_height)
    Output
      function (wave_heights) 
      NULL

