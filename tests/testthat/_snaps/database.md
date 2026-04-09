# snapshot: args(buoy_tbl) signature

    Code
      args(buoy_tbl)
    Output
      function (con, table_name = "buoy_data") 
      NULL

# snapshot: args(connect_duckdb) signature

    Code
      args(connect_duckdb)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", create_new = FALSE) 
      NULL

# snapshot: args(create_buoy_schema) signature

    Code
      args(create_buoy_schema)
    Output
      function (con) 
      NULL

# snapshot: args(get_database_stats) signature

    Code
      args(get_database_stats)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb") 
      NULL

# snapshot: args(load_to_duckdb) signature

    Code
      args(load_to_duckdb)
    Output
      function (data, con, update_metadata = TRUE) 
      NULL

# snapshot pass2: args(query_buoy_data)

    Code
      args(irishbuoys:::query_buoy_data)
    Output
      function (con, stations = NULL, start_date = NULL, end_date = NULL, 
          variables = NULL, qc_filter = TRUE) 
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

