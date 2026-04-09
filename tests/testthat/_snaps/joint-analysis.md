# snapshot: args(analyze_joint_extremes) signature

    Code
      args(analyze_joint_extremes)
    Output
      function (data, variable = "wave_height", threshold_quantile = 0.95) 
      NULL

# snapshot: args(compute_extremal_dependence) signature

    Code
      args(compute_extremal_dependence)
    Output
      function (data, variable = "wave_height", threshold_quantile = seq(0.9, 
          0.99, by = 0.01), n_bootstrap = 100, boot_subsample = 5000, 
          station_info = NULL) 
      NULL

# snapshot: args(cross_correlation_stations) signature

    Code
      args(cross_correlation_stations)
    Output
      function (data, station1, station2, variable = "wave_height", 
          max_lag = 48) 
      NULL

# snapshot: args(get_station_info) signature

    Code
      args(get_station_info)
    Output
      function () 
      NULL

# snapshot: args(haversine_distance) signature

    Code
      args(haversine_distance)
    Output
      function (lat1, lon1, lat2, lon2) 
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

# snap3: args(analyze_parquet_storage)

    Code
      args(irishbuoys:::analyze_parquet_storage)
    Output
      function (data_path = "inst/extdata/parquet") 
      NULL

