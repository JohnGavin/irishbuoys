# snapshot: args(calculate_annual_trends) signature

    Code
      args(calculate_annual_trends)
    Output
      function (data, variable = "wave_height", time_col = "time") 
      NULL

# snapshot: args(calculate_seasonal_means) signature

    Code
      args(calculate_seasonal_means)
    Output
      function (data, variable = "wave_height", time_col = "time") 
      NULL

# snapshot: args(compute_acf_summary) signature

    Code
      args(compute_acf_summary)
    Output
      function (data, variable = "wave_height", max_lag = 48) 
      NULL

# snapshot: args(decompose_stl) signature

    Code
      args(decompose_stl)
    Output
      function (data, variable = "wave_height", time_col = "time", 
          frequency = "daily") 
      NULL

# snapshot: args(detect_anomalies) signature

    Code
      args(detect_anomalies)
    Output
      function (data, variable = "wave_height", time_col = "time", 
          threshold = 3) 
      NULL

# snap3: args(detect_outliers_iqr)

    Code
      args(irishbuoys:::detect_outliers_iqr)
    Output
      function (data, variable = "wave_height", multiplier = 1.5) 
      NULL

# snap3: args(mann_kendall_test)

    Code
      args(irishbuoys:::mann_kendall_test)
    Output
      function (data, variable = "wave_height", time_col = "time") 
      NULL

# snap3: args(trend_summary_report)

    Code
      args(irishbuoys:::trend_summary_report)
    Output
      function (seasonal_means, annual_trends, anomalies = NULL) 
      NULL

