# snapshot: args(generate_api_decomposition) signature

    Code
      args(generate_api_decomposition)
    Output
      function (decomp_per_station) 
      NULL

# snapshot: args(generate_api_extremes) signature

    Code
      args(generate_api_extremes)
    Output
      function (return_levels_per_station, ci_comparison_per_station) 
      NULL

# snapshot: args(generate_api_gust_factors) signature

    Code
      args(generate_api_gust_factors)
    Output
      function (gust_analysis) 
      NULL

# snapshot: args(generate_api_index) signature

    Code
      args(generate_api_index)
    Output
      function (base_url = "https://johngavin.github.io/irishbuoys/api/v1/", 
          endpoints = NULL) 
      NULL

# snapshot: args(generate_api_methods) signature

    Code
      args(generate_api_methods)
    Output
      function () 
      NULL

# snapshot: args(generate_api_sources) signature

    Code
      args(generate_api_sources)
    Output
      function (update_frequency = NULL) 
      NULL

# snapshot pass2: args(generate_api_spatial)

    Code
      args(irishbuoys:::generate_api_spatial)
    Output
      function (pair_wave, pair_wind, pair_hmax) 
      NULL

# snap3: args(generate_api_status)

    Code
      args(irishbuoys:::generate_api_status)
    Output
      function (dashboard_stats) 
      NULL

# snap3: args(generate_api_trends)

    Code
      args(irishbuoys:::generate_api_trends)
    Output
      function (mann_kendall_per_station, annual_trends_wave, annual_trends_wind) 
      NULL

