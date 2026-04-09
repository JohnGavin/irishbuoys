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

