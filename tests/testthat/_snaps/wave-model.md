# snapshot: args(prepare_wave_features) signature

    Code
      args(prepare_wave_features)
    Output
      function (data, lags = 1:3) 
      NULL

# snap3: args(add_wave_metrics)

    Code
      args(irishbuoys:::add_wave_metrics)
    Output
      function (data, rogue_threshold = 2) 
      NULL

# snap3: args(calculate_rms_wave_height)

    Code
      args(irishbuoys:::calculate_rms_wave_height)
    Output
      function (wave_heights) 
      NULL

# snap3: args(calculate_wave_steepness)

    Code
      args(irishbuoys:::calculate_wave_steepness)
    Output
      function (wave_height, wave_period) 
      NULL

# snap3: args(compare_rogue_wave_gust)

    Code
      args(irishbuoys:::compare_rogue_wave_gust)
    Output
      function (data) 
      NULL

# snap3: args(create_plot_gusts_vs_waves)

    Code
      args(irishbuoys:::create_plot_gusts_vs_waves)
    Output
      function (analysis_data) 
      NULL

# snap3: args(create_plot_monthly_wave)

    Code
      args(irishbuoys:::create_plot_monthly_wave)
    Output
      function (seasonal_means_wave, date_caption = NULL) 
      NULL

