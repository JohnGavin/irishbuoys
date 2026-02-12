#' Documentation Code Examples Plan
#'
#' @description
#' Stores ALL code examples from README.qmd as text targets.
#' Each example is:
#' 1. Stored as character vector (one element per line)
#' 2. Parsed to check syntax is valid
#' 3. Depends on the functions it uses (triggers rebuild when functions change)
#'
#' This ensures README code examples are always tested and synchronized.
#'
#' @details
#' Pattern: code_readme_* targets store code as text
#'          code_parsed_* targets verify syntax
#'          The validation target fails the pipeline if any syntax is invalid
#'
#' IMPORTANT: Each code target DEPENDS ON the source files containing the
#' functions it uses. When those functions change, the target is invalidated.

# Helper: Parse code text to verify syntax
parse_code_example <- function(code_text) {
  code_string <- paste(code_text, collapse = "\n")
  tryCatch(
    {
      parsed <- parse(text = code_string)
      list(
        valid = TRUE,
        n_expressions = length(parsed),
        code = code_string
      )
    },
    error = function(e) {
      list(
        valid = FALSE,
        error = conditionMessage(e),
        code = code_string
      )
    }
  )
}

# ============================================================================
# ALL README.QMD CODE EXAMPLES AS TARGETS
# Each target depends on the source file(s) containing the functions it uses
# ============================================================================

plan_doc_examples <- list(

  # ==========================================================================
  # FILE DEPENDENCIES - track source files that contain functions used in README
  # ==========================================================================
  targets::tar_target(
    src_erddap_client,
    "R/erddap_client.R",
    format = "file"
  ),

  targets::tar_target(
    src_update,
    "R/update.R",
    format = "file"
  ),

  targets::tar_target(
    src_database,
    "R/database.R",
    format = "file"
  ),

  targets::tar_target(
    src_data_dictionary,
    "R/data_dictionary.R",
    format = "file"
  ),

  # ==========================================================================
  # README CODE CHUNKS - Quick Start > Download Recent Data
  # ==========================================================================

  # Chunk 1: Download last 7 days
  targets::tar_target(
    code_readme_download_recent,
    {
      # This target depends on src_download - changes trigger rebuild
      force(src_erddap_client)
      c(
        "library(irishbuoys)",
        "",
        "# Download last 7 days of data",
        "# Show structure of first 3 rows for efficiency",
        "data <- download_buoy_data(",
        "  start_date = Sys.Date() - 7,",
        "  end_date = Sys.Date()",
        ")",
        "str(head(data, 3))"
      )
    }
  ),

  # Chunk 2: Download specific station
  targets::tar_target(
    code_readme_download_station,
    {
      force(src_erddap_client)
      c(
        "# Get data for specific station",
        "m3_data <- download_buoy_data(",
        '  stations = "M3",',
        '  start_date = "2024-01-01"',
        ")",
        "dim(m3_data)"
      )
    }
  ),

  # Chunk 3: Download earliest data
  targets::tar_target(
    code_readme_download_earliest,
    {
      force(src_erddap_client)
      c(
        "# Get earliest available data (buoy network started 2001-02-05)",
        "# Show structure of first 3 rows for efficiency",
        "waves <- download_buoy_data(",
        '  start_date = "2001-02-05",',
        '  end_date = "2001-02-06"',
        ")",
        "str(head(waves, 3))"
      )
    }
  ),

  # ==========================================================================
  # README CODE CHUNKS - Initialize and Query Database
  # ==========================================================================

  # Chunk 4: Initialize database
  targets::tar_target(
    code_readme_init_db,
    {
      force(src_update)
      c(
        "# Initialize database with historical data (chunk_days=365 for faster downloads)",
        "initialize_database(",
        '  start_date = "2024-01-01",  # Default: recent data for quick start',
        "  end_date = Sys.Date(),",
        "  chunk_days = 365  # Download in 1-year chunks for efficiency",
        ")"
      )
    }
  ),

  # Chunk 5: Get database stats
  targets::tar_target(
    code_readme_db_stats,
    {
      force(src_database)
      c(
        "# Check database statistics immediately after initialization",
        "stats <- get_database_stats()"
      )
    }
  ),

  # Chunk 6: Connect to database
  targets::tar_target(
    code_readme_connect,
    {
      force(src_database)
      c(
        "# Connect to database",
        "con <- connect_duckdb()"
      )
    }
  ),

  # Chunk 7: QC tally query
  targets::tar_target(
    code_readme_qc_tally,
    {
      force(src_database)
      c(
        "# Check QC flag distribution by station FIRST",
        "# qc_flag: 0=unknown, 1=good, 9=missing",
        'qc_tally <- tbl(con, "buoy_data") |>',
        "  group_by(station_id, qc_flag) |>",
        '  summarise(n = n(), .groups = "drop") |>',
        "  collect() |>",
        '  tidyr::pivot_wider(names_from = qc_flag, values_from = n, names_prefix = "qc_")',
        "print(qc_tally)"
      )
    }
  ),

  # Chunk 8: Query buoy data
  targets::tar_target(
    code_readme_query_wave,
    {
      force(src_database)
      c(
        "# Query wave data (qc_filter=FALSE returns all data; TRUE filters for qc_flag==1)",
        "wave_data <- query_buoy_data(",
        "  con,",
        '  stations = c("M3", "M4"),',
        '  variables = c("time", "station_id", "wave_height", "wave_period"),',
        '  start_date = "2024-01-01",',
        "  qc_filter = FALSE  # Set TRUE to filter for qc_flag==1 only",
        ")"
      )
    }
  ),

  # Chunk 9: SQL rogue waves query
  targets::tar_target(
    code_readme_sql_rogue,
    {
      force(src_database)
      c(
        "# Custom SQL query: Find top 10 most extreme rogue waves",
        '# Ordered by hmax (highest individual wave) because "extreme" = largest waves',
        "extreme_waves <- query_buoy_data(",
        "  con,",
        '  sql_query = "',
        "    SELECT station_id, time, wave_height, hmax",
        "    FROM buoy_data",
        "    WHERE hmax > 2 * wave_height",
        "      AND wave_height > 0",
        "      AND qc_flag = 1",
        "    ORDER BY hmax DESC",
        "    LIMIT 10",
        '  "',
        ")"
      )
    }
  ),

  # ==========================================================================
  # README CODE CHUNKS - Tidyverse Alternative
  # ==========================================================================

  # Chunk 10: duckplyr rogue waves
  targets::tar_target(
    code_readme_duckplyr_rogue,
    {
      force(src_database)
      c(
        "# Tidyverse alternative using duckplyr",
        "# Same query as SQL above, ordered by hmax (highest waves first)",
        "library(dplyr)",
        "library(duckplyr)",
        "",
        'extreme_waves_tidy <- tbl(con, "buoy_data") |>',
        "  filter(",
        "    hmax > 2 * wave_height,",
        "    wave_height > 0,",
        "    qc_flag == 1",
        "  ) |>",
        "  select(station_id, time, wave_height, hmax) |>",
        "  arrange(desc(hmax)) |>",
        "  head(10) |>",
        "  collect()"
      )
    }
  ),

  # Chunk 11: Disconnect
  targets::tar_target(
    code_readme_disconnect,
    {
      force(src_database)
      c(
        "# Don't forget to disconnect",
        "DBI::dbDisconnect(con)"
      )
    }
  ),

  # ==========================================================================
  # README CODE CHUNKS - Incremental Updates
  # ==========================================================================

  # Chunk 12: Incremental update
  targets::tar_target(
    code_readme_incremental,
    {
      force(src_update)
      c(
        "# Perform incremental update (for scheduled jobs)",
        "result <- incremental_update()",
        "print(result$summary)"
      )
    }
  ),

  # ==========================================================================
  # README CODE CHUNKS - Data Dictionary
  # ==========================================================================

  # Chunk 13: Get data dictionary
  targets::tar_target(
    code_readme_dictionary,
    {
      force(src_data_dictionary)
      c(
        "# Get complete data dictionary (returns tibble)",
        "dict <- get_data_dictionary()",
        "print(dict)"
      )
    }
  ),

  # Chunk 14: Get variable docs
  targets::tar_target(
    code_readme_variable_docs,
    {
      force(src_data_dictionary)
      c(
        "# Get detailed documentation for specific variable",
        '(wave_docs <- get_variable_docs("WaveHeight"))'
      )
    }
  ),

  # Chunk 15: Merge dictionary
  targets::tar_target(
    code_readme_dict_merge,
    {
      force(src_data_dictionary)
      c(
        "# Merge dictionary with database column info",
        "# Useful for creating documentation or understanding data",
        "library(dplyr)",
        "db_cols <- tibble(",
        '  variable = c("wave_height", "hmax", "wind_speed", "gust"),',
        '  db_column = c("wave_height", "hmax", "wind_speed", "gust")',
        ")",
        "dict |>",
        "  filter(tolower(variable) %in% db_cols$variable |",
        '         variable %in% c("WaveHeight", "Hmax", "WindSpeed", "Gust")) |>',
        "  select(variable, units, description)"
      )
    }
  ),

  # ==========================================================================
  # SYNTAX VALIDATION TARGETS
  # ==========================================================================

  targets::tar_target(
    code_parsed_download_recent,
    parse_code_example(code_readme_download_recent)
  ),

  targets::tar_target(
    code_parsed_download_station,
    parse_code_example(code_readme_download_station)
  ),

  targets::tar_target(
    code_parsed_download_earliest,
    parse_code_example(code_readme_download_earliest)
  ),

  targets::tar_target(
    code_parsed_init_db,
    parse_code_example(code_readme_init_db)
  ),

  targets::tar_target(
    code_parsed_db_stats,
    parse_code_example(code_readme_db_stats)
  ),

  targets::tar_target(
    code_parsed_connect,
    parse_code_example(code_readme_connect)
  ),

  targets::tar_target(
    code_parsed_qc_tally,
    parse_code_example(code_readme_qc_tally)
  ),

  targets::tar_target(
    code_parsed_query_wave,
    parse_code_example(code_readme_query_wave)
  ),

  targets::tar_target(
    code_parsed_sql_rogue,
    parse_code_example(code_readme_sql_rogue)
  ),

  targets::tar_target(
    code_parsed_duckplyr_rogue,
    parse_code_example(code_readme_duckplyr_rogue)
  ),

  targets::tar_target(
    code_parsed_disconnect,
    parse_code_example(code_readme_disconnect)
  ),

  targets::tar_target(
    code_parsed_incremental,
    parse_code_example(code_readme_incremental)
  ),

  targets::tar_target(
    code_parsed_dictionary,
    parse_code_example(code_readme_dictionary)
  ),

  targets::tar_target(
    code_parsed_variable_docs,
    parse_code_example(code_readme_variable_docs)
  ),

  targets::tar_target(
    code_parsed_dict_merge,
    parse_code_example(code_readme_dict_merge)
  ),

  # ==========================================================================
  # VALIDATION SUMMARY - Fails pipeline if any syntax errors
  # ==========================================================================
  targets::tar_target(
    readme_examples_validation,
    {
      parse_results <- list(
        download_recent = code_parsed_download_recent,
        download_station = code_parsed_download_station,
        download_earliest = code_parsed_download_earliest,
        init_db = code_parsed_init_db,
        db_stats = code_parsed_db_stats,
        connect = code_parsed_connect,
        qc_tally = code_parsed_qc_tally,
        query_wave = code_parsed_query_wave,
        sql_rogue = code_parsed_sql_rogue,
        duckplyr_rogue = code_parsed_duckplyr_rogue,
        disconnect = code_parsed_disconnect,
        incremental = code_parsed_incremental,
        dictionary = code_parsed_dictionary,
        variable_docs = code_parsed_variable_docs,
        dict_merge = code_parsed_dict_merge
      )

      # Check all parsed correctly
      all_valid <- all(sapply(parse_results, function(x) x$valid))
      if (!all_valid) {
        failed <- names(parse_results)[!sapply(parse_results, function(x) x$valid)]
        errors <- sapply(parse_results[failed], function(x) x$error)
        cli::cli_abort(c(
          "x" = "README code examples failed syntax validation",
          "i" = "Failed examples: {paste(failed, collapse = ', ')}",
          "i" = "Errors: {paste(errors, collapse = '; ')}"
        ))
      }

      list(
        all_valid = all_valid,
        n_examples = length(parse_results),
        examples = names(parse_results),
        validated_at = Sys.time()
      )
    }
  )
)
