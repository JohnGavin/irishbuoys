# snapshot: args(download_buoy_data) signature

    Code
      args(download_buoy_data)
    Output
      function (start_date = Sys.Date() - 30, end_date = Sys.Date(), 
          stations = NULL, variables = NULL, format = "csv") 
      NULL

# snapshot: args(get_latest_timestamp) signature

    Code
      args(get_latest_timestamp)
    Output
      function (station = NULL) 
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

