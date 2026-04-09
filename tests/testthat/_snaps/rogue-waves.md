# snapshot: args(add_wave_metrics) signature

    Code
      args(add_wave_metrics)
    Output
      function (data, rogue_threshold = 2) 
      NULL

# snapshot: args(analyze_rogue_statistics) signature

    Code
      args(analyze_rogue_statistics)
    Output
      function (con, threshold = 2, min_wave_height = 2) 
      NULL

# snapshot: args(calculate_wave_steepness) signature

    Code
      args(calculate_wave_steepness)
    Output
      function (wave_height, wave_period) 
      NULL

# snapshot: args(compare_rogue_wave_gust) signature

    Code
      args(compare_rogue_wave_gust)
    Output
      function (data) 
      NULL

# snapshot: args(connect_duckdb) signature

    Code
      args(connect_duckdb)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", create_new = FALSE) 
      NULL

# snapshot: args(detect_rogue_waves) signature

    Code
      args(detect_rogue_waves)
    Output
      function (con, threshold = 2, min_wave_height = 2, start_date = NULL, 
          end_date = NULL, stations = NULL) 
      NULL

# snapshot: args(load_to_duckdb) signature

    Code
      args(load_to_duckdb)
    Output
      function (data, con, update_metadata = TRUE) 
      NULL

# snapshot: args(rogue_wave_report) signature

    Code
      args(rogue_wave_report)
    Output
      function (con, days = 30) 
      NULL

# snapshot: args(test_rogue_propagation) signature

    Code
      args(test_rogue_propagation)
    Output
      function (data, rogue_threshold = 2, min_wave_height = 2, station_pairs = NULL, 
          propagation_speed_kmh = 30, n_permutations = 500, station_info = NULL) 
      NULL

# snapshot pass2: args(analyze_gust_factor)

    Code
      args(irishbuoys:::analyze_gust_factor)
    Output
      function (data, min_wind_speed = 5) 
      NULL

# snapshot pass2: args(analyze_joint_extremes)

    Code
      args(irishbuoys:::analyze_joint_extremes)
    Output
      function (data, variable = "wave_height", threshold_quantile = 0.95) 
      NULL

# snap3: args(create_plot_rogue_all)

    Code
      args(irishbuoys:::create_plot_rogue_all)
    Output
      function (rogue_events) 
      NULL

# snap3: args(create_plot_rogue_by_station)

    Code
      args(irishbuoys:::create_plot_rogue_by_station)
    Output
      function (rogue_events, date_caption = NULL) 
      NULL

