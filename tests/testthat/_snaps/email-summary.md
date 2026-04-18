# snapshot: args(create_email_summary) signature

    Code
      args(create_email_summary)
    Output
      function (summary) 
      NULL

# snapshot: args(generate_and_send_summary) signature

    Code
      args(generate_and_send_summary)
    Output
      function (recipient = Sys.getenv("GMAIL_USERNAME"), sender = Sys.getenv("GMAIL_USERNAME")) 
      NULL

# snapshot: args(generate_weekly_summary) signature

    Code
      args(generate_weekly_summary)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", lookback_days = 7, 
          qc_filter = NULL, update_result = NULL) 
      NULL

# snapshot: args(get_database_stats) signature

    Code
      args(get_database_stats)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb") 
      NULL

# snapshot: args(validate_email_freshness) signature

    Code
      args(validate_email_freshness)
    Output
      function (ingestion_stats, max_stale_hours = 96) 
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

# generate_weekly_summary field names are stable

    Code
      sort(names(result))
    Output
       [1] "current_week"    "data_coverage"   "db_stats"        "extreme_events" 
       [5] "historical"      "ingestion_stats" "period"          "previous_week"  
       [9] "report_date"     "update_result"  

---

    Code
      sort(names(result$current_week))
    Output
      [1] "avg_air_temp"    "avg_sea_temp"    "avg_wave_height" "avg_wind_speed" 
      [5] "max_wave_height" "max_wind_speed"  "n_observations"  "station_id"     
      [9] "status"         

---

    Code
      sort(names(result$ingestion_stats))
    Output
      [1] "earliest"        "latest"          "new_records"     "report_composed"
      [5] "staleness_alert" "staleness_hours" "station_id"      "status"         

# get_station_info output is stable

    Code
      sort(names(info))
    Output
      [1] "depth_m"     "distance_km" "lat"         "location"    "lon"        
      [6] "station_id" 

