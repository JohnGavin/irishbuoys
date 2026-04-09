# snapshot: args(calculate_gpd_return_levels) signature

    Code
      args(calculate_gpd_return_levels)
    Output
      function (gpd_fit, return_periods = c(1, 5, 10), n_obs_per_year = 8760, 
          n_total = NULL, exceedance_rate = NULL, conf_level = 0.95) 
      NULL

# snapshot: args(calculate_return_levels) signature

    Code
      args(calculate_return_levels)
    Output
      function (fit, return_periods = c(10, 50, 100), conf_level = 0.95) 
      NULL

# snapshot: args(connect_duckdb) signature

    Code
      args(connect_duckdb)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", create_new = FALSE) 
      NULL

# snapshot: args(create_email_summary) signature

    Code
      args(create_email_summary)
    Output
      function (summary) 
      NULL

# snapshot: args(create_validation_summary) signature

    Code
      args(create_validation_summary)
    Output
      function (...) 
      NULL

# snap3: args(fit_gev_annual_maxima)

    Code
      args(irishbuoys:::fit_gev_annual_maxima)
    Output
      function (data, variable = "wave_height", time_col = "time", 
          min_years = 5) 
      NULL

# snap3: args(fit_gpd_threshold)

    Code
      args(irishbuoys:::fit_gpd_threshold)
    Output
      function (data, variable = "wave_height", threshold = NULL, decluster = TRUE, 
          decluster_hours = 48) 
      NULL

# snap3: args(generate_validation_reports)

    Code
      args(irishbuoys:::generate_validation_reports)
    Output
      function (analysis_data, rogue_events, output_dir = "docs/articles") 
      NULL

