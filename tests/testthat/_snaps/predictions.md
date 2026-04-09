# snapshot: args(compute_calibration) signature

    Code
      args(compute_calibration)
    Output
      function (predictions) 
      NULL

# snapshot: args(read_predictions) signature

    Code
      args(read_predictions)
    Output
      function (project_slug = NULL) 
      NULL

# snapshot pass2: args(empty_predictions_tibble)

    Code
      args(irishbuoys:::empty_predictions_tibble)
    Output
      function () 
      NULL

# snapshot pass2: args(prediction_jsonl_path)

    Code
      args(irishbuoys:::prediction_jsonl_path)
    Output
      function (project_slug) 
      NULL

# snapshot pass2: args(read_single_jsonl)

    Code
      args(irishbuoys:::read_single_jsonl)
    Output
      function (path) 
      NULL

# snapshot pass2: args(store_predictions_duckdb)

    Code
      args(irishbuoys:::store_predictions_duckdb)
    Output
      function (predictions, db_path) 
      NULL

# snap3: args(add_wave_metrics)

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

# snap3: args(analyze_parquet_storage)

    Code
      args(irishbuoys:::analyze_parquet_storage)
    Output
      function (data_path = "inst/extdata/parquet") 
      NULL

