# snapshot: args(analyze_parquet_storage) signature

    Code
      args(analyze_parquet_storage)
    Output
      function (data_path = "inst/extdata/parquet") 
      NULL

# snapshot: args(convert_duckdb_to_parquet) signature

    Code
      args(convert_duckdb_to_parquet)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", data_path = "inst/extdata/parquet") 
      NULL

# snapshot: args(incremental_update_parquet) signature

    Code
      args(incremental_update_parquet)
    Output
      function (new_data, data_path = "inst/extdata/parquet") 
      NULL

# snapshot: args(init_parquet_storage) signature

    Code
      args(init_parquet_storage)
    Output
      function (data_path = "inst/extdata/parquet", db_path = "inst/extdata/metadata.duckdb") 
      NULL

# snap3: args(get_database_stats)

    Code
      args(irishbuoys:::get_database_stats)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb") 
      NULL

# snap3: args(initialize_database)

    Code
      args(irishbuoys:::initialize_database)
    Output
      function (db_path = "inst/extdata/irish_buoys.duckdb", start_date = Sys.Date() - 
          365, end_date = Sys.Date(), chunk_days = 365) 
      NULL

# snap3: args(query_parquet)

    Code
      args(irishbuoys:::query_parquet)
    Output
      function (query = NULL, data_path = "inst/extdata/parquet/by_year_month", 
          stations = NULL, date_range = NULL) 
      NULL

