# snapshot: args(ci_bootstrap_return_levels) signature

    Code
      args(ci_bootstrap_return_levels)
    Output
      function (data, variable, return_periods = c(1, 5, 10), n_boot = 500, 
          conf_level = 0.95, block_size = NULL, threshold_quantile = 0.95, 
          n_obs_per_year = 8760, seed = 42) 
      NULL

# snapshot: args(ci_order_statistics) signature

    Code
      args(ci_order_statistics)
    Output
      function (x, probs, conf_level = 0.95) 
      NULL

# snapshot: args(ci_parametric_bootstrap) signature

    Code
      args(ci_parametric_bootstrap)
    Output
      function (gpd_fit, n_boot = 500, return_periods = c(1, 5, 10), 
          conf_level = 0.95, n_obs_per_year = 8760, seed = 42) 
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

