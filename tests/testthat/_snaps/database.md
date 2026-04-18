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

# buoy_data table schema is stable

    Code
      cols
    Output
       [1] "air_temperature"      "atmospheric_pressure" "call_sign"           
       [4] "dew_point"            "gust"                 "hmax"                
       [7] "latitude"             "longitude"            "mean_wave_direction" 
      [10] "qc_flag"              "relative_humidity"    "salinity"            
      [13] "sea_temperature"      "sprtp"                "station_id"          
      [16] "thtp"                 "time"                 "tp"                  
      [19] "wave_height"          "wave_period"          "wind_direction"      
      [22] "wind_speed"          

# get_database_stats output structure is stable

    Code
      sort(names(stats))
    Output
      [1] "by_station"     "completeness"   "db_size_mb"     "overall"       
      [5] "recent_updates"

---

    Code
      sort(names(stats$overall))
    Output
      [1] "earliest_date" "latest_date"   "n_days"        "n_stations"   
      [5] "total_records"

---

    Code
      sort(names(stats$by_station))
    Output
      [1] "first_observation" "last_observation"  "n_records"        
      [4] "pct_good_quality"  "station_id"       

# query_buoy_data column names are stable

    Code
      sort(names(result))
    Output
       [1] "air_temperature"      "atmospheric_pressure" "call_sign"           
       [4] "dew_point"            "gust"                 "hmax"                
       [7] "latitude"             "longitude"            "mean_wave_direction" 
      [10] "qc_flag"              "relative_humidity"    "salinity"            
      [13] "sea_temperature"      "sprtp"                "station_id"          
      [16] "thtp"                 "time"                 "tp"                  
      [19] "wave_height"          "wave_period"          "wind_direction"      
      [22] "wind_speed"          

