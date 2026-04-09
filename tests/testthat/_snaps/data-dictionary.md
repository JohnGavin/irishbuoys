# snapshot: args(get_data_dictionary) signature

    Code
      args(get_data_dictionary)
    Output
      function () 
      NULL

# snapshot: args(get_variable_docs) signature

    Code
      args(get_variable_docs)
    Output
      function (variable = NULL) 
      NULL

# snap3: args(compute_data_coverage)

    Code
      args(irishbuoys:::compute_data_coverage)
    Output
      function (con, start_date, end_date) 
      NULL

# snap3: args(create_return_level_plot_data)

    Code
      args(irishbuoys:::create_return_level_plot_data)
    Output
      function (fit, max_return_period = 200, n_points = 100) 
      NULL

# snap3: args(download_buoy_data)

    Code
      args(irishbuoys:::download_buoy_data)
    Output
      function (start_date = Sys.Date() - 30, end_date = Sys.Date(), 
          stations = NULL, variables = NULL, format = "csv") 
      NULL

