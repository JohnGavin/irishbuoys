# snapshot: args(validate_buoy_data) signature

    Code
      args(validate_buoy_data)
    Output
      function (data, target_name = "analysis_data", min_rows = 100, 
          report_path = NULL) 
      NULL

# snapshot: args(validate_rogue_events) signature

    Code
      args(validate_rogue_events)
    Output
      function (data, target_name = "rogue_wave_events", min_rows = 1, 
          report_path = NULL) 
      NULL

# snap3: args(create_validation_summary)

    Code
      args(irishbuoys:::create_validation_summary)
    Output
      function (...) 
      NULL

# snap3: args(generate_validation_reports)

    Code
      args(irishbuoys:::generate_validation_reports)
    Output
      function (analysis_data, rogue_events, output_dir = "docs/articles") 
      NULL

