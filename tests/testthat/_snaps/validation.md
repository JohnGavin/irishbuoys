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

# validate_buoy_data error messages are stable

    Code
      validate_buoy_data(NULL)
    Condition
      Error in `validate_buoy_data()`:
      x `data` cannot be NULL
      i Provide a data frame with buoy measurements

---

    Code
      validate_buoy_data("string")
    Condition
      Error in `validate_buoy_data()`:
      x `data` must be a data frame
      i You provided <character>

# validate_buoy_data output structure is stable

    Code
      sort(names(result))
    Output
      [1] "qc_flag"     "station_id"  "time"        "wave_height" "wind_speed" 

# validate_buoy_data output structure is stable with complete data

    Code
      sort(names(result))
    Output
      [1] "atmospheric_pressure" "gust"                 "hmax"                
      [4] "qc_flag"              "station_id"           "time"                
      [7] "wave_height"          "wind_speed"          

