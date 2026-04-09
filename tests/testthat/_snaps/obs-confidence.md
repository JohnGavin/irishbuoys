# snapshot: args(compute_obs_confidence) signature

    Code
      args(compute_obs_confidence)
    Output
      function (age_hours) 
      NULL

# snapshot: args(obs_status_label) signature

    Code
      args(obs_status_label)
    Output
      function (confidence) 
      NULL

# snapshot: args(widen_ci) signature

    Code
      args(widen_ci)
    Output
      function (point, lower, upper, confidence) 
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

