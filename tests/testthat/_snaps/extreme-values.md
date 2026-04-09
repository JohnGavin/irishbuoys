# snapshot: args(analyze_gust_factor) signature

    Code
      args(analyze_gust_factor)
    Output
      function (data, min_wind_speed = 5) 
      NULL

# snapshot: args(calculate_gpd_return_levels) signature

    Code
      args(calculate_gpd_return_levels)
    Output
      function (gpd_fit, return_periods = c(1, 5, 10), n_obs_per_year = 8760, 
          n_total = NULL, exceedance_rate = NULL, conf_level = 0.95) 
      NULL

# snapshot: args(calculate_return_levels) signature

    Code
      args(calculate_return_levels)
    Output
      function (fit, return_periods = c(10, 50, 100), conf_level = 0.95) 
      NULL

# snapshot: args(compare_rogue_wave_gust) signature

    Code
      args(compare_rogue_wave_gust)
    Output
      function (data) 
      NULL

# snap3: args(create_return_level_plot_data)

    Code
      args(irishbuoys:::create_return_level_plot_data)
    Output
      function (fit, max_return_period = 200, n_points = 100) 
      NULL

# snap3: args(fit_gev_annual_maxima)

    Code
      args(irishbuoys:::fit_gev_annual_maxima)
    Output
      function (data, variable = "wave_height", time_col = "time", 
          min_years = 5) 
      NULL

# snap3: args(fit_gpd_threshold)

    Code
      args(irishbuoys:::fit_gpd_threshold)
    Output
      function (data, variable = "wave_height", threshold = NULL, decluster = TRUE, 
          decluster_hours = 48) 
      NULL

