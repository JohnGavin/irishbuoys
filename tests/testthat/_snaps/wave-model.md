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

# prepare_wave_features output columns are stable

    Code
      sort(names(result))
    Output
       [1] "atmospheric_pressure" "gust"                 "gust_factor"         
       [4] "hour"                 "month"                "pressure_change"     
       [7] "station_id"           "time"                 "wave_height"         
      [10] "wave_height_lag1"     "wave_height_lag2"     "wave_height_lag3"    
      [13] "wave_period"          "wave_steepness"       "wind_dir_cos"        
      [16] "wind_dir_sin"         "wind_direction"       "wind_speed"          
      [19] "wind_speed_lag1"     

# prepare_wave_features error on missing columns

    Code
      prepare_wave_features(bad_data)
    Condition
      Error in `prepare_wave_features()`:
      x Missing required columns: "wave_height"
      i Data must contain: "station_id", "time", and "wave_height"

