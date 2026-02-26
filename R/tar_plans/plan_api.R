#' Static API Targets Plan
#'
#' @description
#' Generates static JSON files for the GitHub Pages API at `docs/api/v1/`.
#' Updated weekly by CI (weekly-update.yml).
#'
#' Base URL: https://johngavin.github.io/irishbuoys/api/v1/
#'
#' @details
#' Targets:
#' - api_stations       : Station metadata (stations.json)
#' - api_stats          : Dashboard statistics (stats.json)
#' - api_rogue_waves    : Rogue wave events (rogue-waves.json)
#' - api_return_levels  : GEV return levels (return-levels.json)
#' - api_data_dictionary: Variable metadata (data-dictionary.json)
#' - api_latest         : Most recent observation per station (latest.json)
#' - api_index          : Endpoint catalogue (index.json)
#' - save_api_files     : Writes all JSON to docs/api/v1/
#'
#' Vignette display targets:
#' - api_vignette_endpoints_dt     : DT::datatable of endpoints
#' - api_vignette_example_response : Sample JSON snippet

plan_api <- list(

  # ==========================================================================
  # API DATA TARGETS
  # ==========================================================================

  # Station metadata
  targets::tar_target(
    api_stations,
    {
      stations <- get_stations()
      # Remove ERDDAP header row artifacts if present
      stations <- stations[!grepl("^String$|^degrees", stations$station_id), ]
      stations
    }
  ),

  # Summary statistics (reuses dashboard_stats target)
  targets::tar_target(
    api_stats,
    {
      stats <- dashboard_stats
      list(
        updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        station_stats = stats$station,
        overall = list(
          total_records = stats$overall$total_records,
          date_range = as.character(stats$overall$date_range),
          stations = stats$overall$stations,
          wind_wave_correlation = round(stats$overall$wind_wave_correlation, 4),
          wave_hmax_correlation = round(stats$overall$wave_hmax_correlation, 4)
        )
      )
    }
  ),

  # Rogue wave events
  targets::tar_target(
    api_rogue_waves,
    {
      events <- rogue_wave_events
      list(
        updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        n_events = nrow(events),
        events = events
      )
    }
  ),

  # Return levels (per-station GPD)
  targets::tar_target(
    api_return_levels,
    {
      rl <- return_levels_per_station
      rl <- rl[!is.na(rl$return_level), ]

      # Build nested by_station structure
      stations <- unique(rl$station)
      by_station <- lapply(stats::setNames(stations, stations), function(st) {
        st_data <- rl[rl$station == st, ]
        vars <- unique(st_data$variable)
        lapply(stats::setNames(vars, vars), function(v) {
          v_data <- st_data[st_data$variable == v, ]
          vals <- stats::setNames(
            round(v_data$return_level, 2),
            paste0(v_data$return_period, "yr")
          )
          as.list(vals)
        })
      })

      list(
        updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        method = "GPD",
        threshold = "95th percentile",
        return_periods = c(1, 5, 10),
        by_station = by_station
      )
    }
  ),

  # Data dictionary
  targets::tar_target(
    api_data_dictionary,
    {
      dict <- get_data_dictionary()
      list(
        updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        n_variables = nrow(dict),
        variables = dict
      )
    }
  ),

  # Latest observation per station
  targets::tar_target(
    api_latest,
    {
      latest <- generate_api_latest(n = 1L)
      list(
        updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
        n_stations = dplyr::n_distinct(latest$station_id),
        observations = latest
      )
    }
  ),

  # API index (catalogue of all endpoints)
  targets::tar_target(
    api_index,
    generate_api_index()
  ),

  # ==========================================================================
  # WRITE ALL JSON FILES TO docs/api/v1/
  # ==========================================================================

  targets::tar_target(
    save_api_files,
    {
      api_dir <- "docs/api/v1"
      dir.create(api_dir, recursive = TRUE, showWarnings = FALSE)

      # Define file -> data mapping
      api_files <- list(
        "index.json" = api_index,
        "stations.json" = api_stations,
        "stats.json" = api_stats,
        "rogue-waves.json" = api_rogue_waves,
        "return-levels.json" = api_return_levels,
        "data-dictionary.json" = api_data_dictionary,
        "latest.json" = api_latest
      )

      # Write each file
      results <- lapply(names(api_files), function(filename) {
        path <- file.path(api_dir, filename)
        json <- jsonlite::toJSON(
          api_files[[filename]],
          pretty = TRUE,
          auto_unbox = TRUE,
          POSIXt = "ISO8601",
          Date = "ISO8601",
          na = "null"
        )
        writeLines(json, path)

        size <- file.info(path)$size
        cli::cli_alert_success("{filename}: {round(size / 1024, 1)} KB")

        tibble::tibble(
          file = filename,
          path = path,
          size_bytes = size,
          size_kb = round(size / 1024, 1)
        )
      })

      result <- dplyr::bind_rows(results)
      cli::cli_alert_success(
        "Wrote {nrow(result)} API files to {api_dir} ({round(sum(result$size_kb), 1)} KB total)"
      )
      result
    }
  ),

  # ==========================================================================
  # VIGNETTE DISPLAY TARGETS
  # ==========================================================================

  # Endpoints table for the API usage vignette
  targets::tar_target(
    api_vignette_endpoints_dt,
    {
      idx <- api_index
      endpoints_df <- dplyr::bind_rows(idx$endpoints)
      DT::datatable(
        endpoints_df,
        caption = "Available API Endpoints",
        options = list(
          pageLength = 10,
          dom = "Bfrtip",
          buttons = c("csv", "print"),
          columnDefs = list(
            list(width = "120px", targets = 0),
            list(width = "300px", targets = 1)
          )
        ),
        rownames = FALSE,
        class = "display compact"
      )
    }
  ),

  # Sample JSON response for vignette display
  targets::tar_target(
    api_vignette_example_response,
    {
      # Show first station from latest.json as example
      example <- api_latest
      example$observations <- head(example$observations, 1)
      jsonlite::toJSON(
        example,
        pretty = TRUE,
        auto_unbox = TRUE,
        POSIXt = "ISO8601",
        na = "null"
      )
    }
  ),

  # ==========================================================================
  # API CODE EXAMPLES (for vignette, following plan_doc_examples pattern)
  # ==========================================================================

  targets::tar_target(
    src_api_static,
    "R/api_static.R",
    format = "file"
  ),

  # Example: curl latest
  targets::tar_target(
    code_api_curl_latest,
    {
      force(src_api_static)
      c(
        "# Fetch latest observations (one per station)",
        "curl https://johngavin.github.io/irishbuoys/api/v1/latest.json"
      )
    }
  ),

  # Example: R jsonlite
  targets::tar_target(
    code_api_r_jsonlite,
    {
      force(src_api_static)
      c(
        "# R: Read the API index",
        "library(jsonlite)",
        'index <- fromJSON("https://johngavin.github.io/irishbuoys/api/v1/index.json")',
        "index$endpoints",
        "",
        "# Read latest observations",
        'latest <- fromJSON("https://johngavin.github.io/irishbuoys/api/v1/latest.json")',
        "latest$observations"
      )
    }
  ),

  # Example: Python requests
  targets::tar_target(
    code_api_python_requests,
    {
      force(src_api_static)
      c(
        "# Python: Read the API",
        "import requests",
        "import pandas as pd",
        "",
        'base = "https://johngavin.github.io/irishbuoys/api/v1/"',
        "",
        "# Get latest observations",
        'latest = requests.get(base + "latest.json").json()',
        'df = pd.DataFrame(latest["observations"])',
        "print(df.head())"
      )
    }
  ),

  # Parse validation for code examples
  targets::tar_target(
    code_parsed_api_r_jsonlite,
    parse_code_example(code_api_r_jsonlite)
  ),

  targets::tar_target(
    api_examples_validation,
    {
      result <- code_parsed_api_r_jsonlite
      if (!result$valid) {
        cli::cli_abort(c(
          "x" = "API code example failed syntax validation",
          "i" = "Error: {result$error}"
        ))
      }
      list(
        all_valid = TRUE,
        n_examples = 3L,
        validated_at = Sys.time()
      )
    }
  )
)
