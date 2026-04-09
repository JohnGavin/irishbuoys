# snapshot: args(add_wave_metrics) signature

    Code
      args(add_wave_metrics)
    Output
      function (data, rogue_threshold = 2) 
      NULL

# snapshot: args(calculate_wave_steepness) signature

    Code
      args(calculate_wave_steepness)
    Output
      function (wave_height, wave_period) 
      NULL

# snapshot: args(detect_rogue_waves) signature

    Code
      args(detect_rogue_waves)
    Output
      function (con, threshold = 2, min_wave_height = 2, start_date = NULL, 
          end_date = NULL, stations = NULL) 
      NULL

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

# snapshot: args(validate_buoy_data) signature

    Code
      args(validate_buoy_data)
    Output
      function (data, target_name = "analysis_data", min_rows = 100, 
          report_path = NULL) 
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

# snap3: args(analyze_parquet_storage)

    Code
      args(irishbuoys:::analyze_parquet_storage)
    Output
      function (data_path = "inst/extdata/parquet") 
      NULL

# snap3: args(analyze_rogue_statistics)

    Code
      args(irishbuoys:::analyze_rogue_statistics)
    Output
      function (con, threshold = 2, min_wave_height = 2) 
      NULL

# snap3: args(analyze_station_pairs)

    Code
      args(irishbuoys:::analyze_station_pairs)
    Output
      function (data, variable = "wave_height", max_lag = 48) 
      NULL

# snap3: args(beaufort_to_description)

    Code
      args(irishbuoys:::beaufort_to_description)
    Output
      function (beaufort) 
      NULL

# snap3: args(buoy_tbl)

    Code
      args(irishbuoys:::buoy_tbl)
    Output
      function (con, table_name = "buoy_data") 
      NULL

