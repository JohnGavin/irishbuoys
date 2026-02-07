#' Documentation Code Examples Plan
#'
#' @description
#' Stores code examples as text targets for verbatim display in .qmd files.
#' Each example is:
#' 1. Stored as character vector (one element per line)
#' 2. Parsed to check syntax is valid
#' 3. Evaluated in isolated environment to verify it runs
#'
#' This ensures README and vignette code examples are always tested.
#'
#' @details
#' Pattern: code_example_* targets store code as text
#'          code_parsed_* targets verify syntax
#'          code_eval_* targets run code with mock data

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

# Helper: Evaluate code in isolated environment with mock DuckDB
eval_code_with_mock_db <- function(code_text) {
  # Create isolated environment

  env <- new.env(parent = globalenv())

  # Set up mock database connection
  env$con <- DBI::dbConnect(duckdb::duckdb(), ":memory:")

  # Create mock buoy_data table with realistic structure

  mock_data <- data.frame(
    station_id = rep(c("M3", "M4", "M5"), each = 100),
    time = seq(as.POSIXct("2024-01-01"), by = "hour", length.out = 300),
    wave_height = runif(300, 1, 5),
    hmax = runif(300, 2, 12),
    wave_period = runif(300, 5, 15),
    wind_speed = runif(300, 5, 25),
    gust = runif(300, 8, 35),
    qc_flag = sample(c(0, 1, 1, 1), 300, replace = TRUE),
    stringsAsFactors = FALSE
  )
  DBI::dbWriteTable(env$con, "buoy_data", mock_data)

  # Mock query_buoy_data function
  env$query_buoy_data <- function(con, sql_query = NULL, ...) {
    if (!is.null(sql_query)) {
      DBI::dbGetQuery(con, sql_query)
    } else {
      DBI::dbReadTable(con, "buoy_data")
    }
  }

  code_string <- paste(code_text, collapse = "\n")
  result <- tryCatch(
    {
      exprs <- parse(text = code_string)
      last_result <- NULL
      for (expr in exprs) {
        last_result <- eval(expr, envir = env)
      }
      list(
        success = TRUE,
        result_class = class(last_result),
        result_nrow = if (is.data.frame(last_result)) nrow(last_result) else NA
      )
    },
    error = function(e) {
      list(
        success = FALSE,
        error = conditionMessage(e)
      )
    },
    finally = {
      DBI::dbDisconnect(env$con)
    }
  )

  result
}

# ============================================================================
# CODE EXAMPLES AS TEXT TARGETS
# ============================================================================

plan_doc_examples <- list(
  # --------------------------------------------------------------------------
  # Example 1: Custom SQL Query - Top 10 extreme rogue waves
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_example_sql_rogue,
    c(
      "# Custom SQL query: Find top 10 most extreme rogue waves",
      "# Ordered by hmax (highest individual wave) because 'extreme' = largest",
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
  ),

  # --------------------------------------------------------------------------
  # Example 2: duckplyr/tidyverse alternative
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_example_duckplyr_rogue,
    c(
      "# Tidyverse alternative using duckplyr",
      "# Same query as SQL above, ordered by hmax (highest waves first)",
      "library(dplyr)",
      "library(duckplyr)",
      "",
      "extreme_waves_tidy <- tbl(con, \"buoy_data\") |>",
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
  ),

  # --------------------------------------------------------------------------
  # Example 3: Quick database query
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_example_wave_query,
    c(
      "# Query wave data for specific stations",
      "wave_data <- query_buoy_data(",
      "  con,",
      '  stations = c("M3", "M4"),',
      '  variables = c("time", "station_id", "wave_height", "wave_period"),',
      '  start_date = "2024-01-01",',
      "  qc_filter = TRUE  # Only good quality data",
      ")"
    )
  ),

  # --------------------------------------------------------------------------
  # Example 4: duckplyr version of wave query
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_example_wave_query_duckplyr,
    c(
      "# Tidyverse alternative for wave query",
      "wave_data_tidy <- tbl(con, \"buoy_data\") |>",
      '  filter(station_id %in% c("M3", "M4")) |>',
      "  filter(time >= as.POSIXct(\"2024-01-01\")) |>",
      "  filter(qc_flag == 1) |>",
      "  select(time, station_id, wave_height, wave_period) |>",
      "  collect()"
    )
  ),

  # --------------------------------------------------------------------------
  # SYNTAX VALIDATION TARGETS (Parse only)
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_parsed_sql_rogue,
    parse_code_example(code_example_sql_rogue)
  ),

  targets::tar_target(
    code_parsed_duckplyr_rogue,
    parse_code_example(code_example_duckplyr_rogue)
  ),

  targets::tar_target(
    code_parsed_wave_query,
    parse_code_example(code_example_wave_query)
  ),

  targets::tar_target(
    code_parsed_wave_query_duckplyr,
    parse_code_example(code_example_wave_query_duckplyr)
  ),

  # --------------------------------------------------------------------------
  # EVALUATION TARGETS (Run with mock data)
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_eval_sql_rogue,
    eval_code_with_mock_db(code_example_sql_rogue)
  ),

  targets::tar_target(
    code_eval_duckplyr_rogue,
    eval_code_with_mock_db(code_example_duckplyr_rogue)
  ),

  # --------------------------------------------------------------------------
  # VALIDATION SUMMARY
  # Collects all parse AND eval results
  # --------------------------------------------------------------------------
  targets::tar_target(
    doc_examples_validation,
    {
      parse_results <- list(
        sql_rogue = code_parsed_sql_rogue,
        duckplyr_rogue = code_parsed_duckplyr_rogue,
        wave_query = code_parsed_wave_query,
        wave_query_duckplyr = code_parsed_wave_query_duckplyr
      )

      eval_results <- list(
        sql_rogue = code_eval_sql_rogue,
        duckplyr_rogue = code_eval_duckplyr_rogue
      )

      # Check parsing
      all_parsed <- all(sapply(parse_results, function(x) x$valid))
      if (!all_parsed) {
        failed <- names(parse_results)[!sapply(parse_results, function(x) x$valid)]
        cli::cli_abort(c(
          "x" = "Code examples failed syntax validation",
          "i" = "Failed examples: {paste(failed, collapse = ', ')}"
        ))
      }

      # Check evaluation
      all_eval <- all(sapply(eval_results, function(x) x$success))
      if (!all_eval) {
        failed <- names(eval_results)[!sapply(eval_results, function(x) x$success)]
        errors <- sapply(eval_results[failed], function(x) x$error)
        cli::cli_abort(c(
          "x" = "Code examples failed execution",
          "i" = "Failed examples: {paste(failed, collapse = ', ')}",
          "i" = "Errors: {paste(errors, collapse = '; ')}"
        ))
      }

      list(
        all_valid = all_parsed && all_eval,
        n_examples = length(parse_results),
        n_evaluated = length(eval_results),
        examples = names(parse_results)
      )
    }
  )
)
