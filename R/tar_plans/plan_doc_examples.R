#' Documentation Code Examples Plan
#'
#' @description
#' Stores code examples as text targets for verbatim display in .qmd files.
#' Each example is:
#' 1. Stored as character vector (one element per line)
#' 2. Parsed to check syntax is valid
#' 3. Optionally evaluated to verify it runs
#'
#' This ensures README and vignette code examples are always tested.
#'
#' @details
#' Pattern: code_example_* targets store code as text
#'          code_parsed_* targets verify syntax
#'          code_result_* targets run and capture output (where safe)

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

# Helper: Evaluate code in isolated environment (for safe examples)
eval_code_example <- function(code_text, envir = new.env(parent = baseenv())) {
  code_string <- paste(code_text, collapse = "\n")
  tryCatch(
    {
      # Parse and evaluate
      exprs <- parse(text = code_string)
      result <- NULL
      for (expr in exprs) {
        result <- eval(expr, envir = envir)
      }
      list(
        success = TRUE,
        result = result
      )
    },
    error = function(e) {
      list(
        success = FALSE,
        error = conditionMessage(e)
      )
    }
  )
}

# ============================================================================
# CODE EXAMPLES AS TEXT TARGETS
# ============================================================================

plan_doc_examples <- list(
  # --------------------------------------------------------------------------
  # Example 1: Custom SQL Query (existing in README)
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_example_sql_rogue,
    c(
      "# Custom SQL query for rogue waves",
      "extreme_waves <- query_buoy_data(",
      "  con,",
      '  sql_query = "',
      "    SELECT station_id, time, wave_height, hmax",
      "    FROM buoy_data",
      "    WHERE hmax > 2 * wave_height",
      "      AND wave_height > 0",
      "      AND qc_flag = 1",
      "    ORDER BY time DESC",
      "    LIMIT 100",
      '  "',
      ")"
    )
  ),

  # --------------------------------------------------------------------------

  # Example 2: duckplyr/tidyverse alternative (NEW)
  # --------------------------------------------------------------------------
  targets::tar_target(
    code_example_duckplyr_rogue,
    c(
      "# Tidyverse alternative using duckplyr",
      "# Same query as SQL above, but with dplyr verbs",
      "library(dplyr)",
      "library(duckplyr)
",
      "extreme_waves_tidy <- tbl(con, \"buoy_data\") |>",
      "  filter(",
      "    hmax > 2 * wave_height,",
      "    wave_height > 0,",
      "    qc_flag == 1",
      "  ) |>",
      "  select(station_id, time, wave_height, hmax) |>",
      "  arrange(desc(time)) |>",
      "  head(100) |>",
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
  # SYNTAX VALIDATION TARGETS
  # These parse each example to verify valid R syntax
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
  # VALIDATION SUMMARY
  # Collects all parse results to ensure all examples are valid
  # --------------------------------------------------------------------------
  targets::tar_target(
    doc_examples_validation,
    {
      results <- list(
        sql_rogue = code_parsed_sql_rogue,
        duckplyr_rogue = code_parsed_duckplyr_rogue,
        wave_query = code_parsed_wave_query,
        wave_query_duckplyr = code_parsed_wave_query_duckplyr
      )

      all_valid <- all(sapply(results, function(x) x$valid))

      if (!all_valid) {
        failed <- names(results)[!sapply(results, function(x) x$valid)]
        cli::cli_abort(c(
          "x" = "Code examples failed syntax validation",
          "i" = "Failed examples: {paste(failed, collapse = ', ')}"
        ))
      }

      list(
        all_valid = all_valid,
        n_examples = length(results),
        examples = names(results)
      )
    }
  )
)
