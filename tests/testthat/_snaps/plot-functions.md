# snapshot: args(create_plot_annual_trends) signature

    Code
      args(create_plot_annual_trends)
    Output
      function (annual_trends, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_gust_by_category) signature

    Code
      args(create_plot_gust_by_category)
    Output
      function (gust_analysis, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_gusts_vs_waves) signature

    Code
      args(create_plot_gusts_vs_waves)
    Output
      function (analysis_data) 
      NULL

# snapshot: args(create_plot_monthly_wave) signature

    Code
      args(create_plot_monthly_wave)
    Output
      function (seasonal_means_wave, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_monthly_wind) signature

    Code
      args(create_plot_monthly_wind)
    Output
      function (seasonal_means_wind, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_return_levels) signature

    Code
      args(create_plot_return_levels)
    Output
      function (return_levels, variable = "wave", date_caption = NULL) 
      NULL

# snapshot: args(create_plot_return_levels_per_station) signature

    Code
      args(create_plot_return_levels_per_station)
    Output
      function (return_levels_df, variable_filter) 
      NULL

# snapshot: args(create_plot_rogue_all) signature

    Code
      args(create_plot_rogue_all)
    Output
      function (rogue_events) 
      NULL

# snapshot: args(create_plot_rogue_by_station) signature

    Code
      args(create_plot_rogue_by_station)
    Output
      function (rogue_events, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_rogue_gusts) signature

    Code
      args(create_plot_rogue_gusts)
    Output
      function (gust_analysis) 
      NULL

# snapshot: args(create_plot_rogue_gusts_all) signature

    Code
      args(create_plot_rogue_gusts_all)
    Output
      function (rogue_gust_events) 
      NULL

# snapshot: args(create_plot_rogue_gusts_by_station) signature

    Code
      args(create_plot_rogue_gusts_by_station)
    Output
      function (rogue_gust_events, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_stl) signature

    Code
      args(create_plot_stl)
    Output
      function (wave_stl, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_time_of_day) signature

    Code
      args(create_plot_time_of_day)
    Output
      function (rogue_conditions, date_caption = NULL) 
      NULL

# snapshot: args(create_plot_week_of_year) signature

    Code
      args(create_plot_week_of_year)
    Output
      function (rogue_conditions, date_caption = NULL) 
      NULL

# snapshot pass2: args(create_plot_wind_beaufort)

    Code
      args(irishbuoys:::create_plot_wind_beaufort)
    Output
      function (rogue_conditions, date_caption = NULL) 
      NULL

# snapshot pass2: args(add_wave_metrics)

    Code
      args(irishbuoys:::add_wave_metrics)
    Output
      function (data, rogue_threshold = 2) 
      NULL

# snapshot pass2: args(analyze_gust_factor)

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

