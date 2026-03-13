#' Static API Targets Plan
#'
#' @description
#' Generates static JSON files for the GitHub Pages API at `docs/api/v1/`.
#' Updated 6-hourly by CI (data-update.yml).
#'
#' Base URL: https://johngavin.github.io/irishbuoys/api/v1/
#'
#' @details
#' Targets (16 endpoints + write step):
#' - api_stations       : Station metadata (stations.json)
#' - api_stats          : Dashboard statistics (stats.json)
#' - api_rogue_waves    : Rogue wave events (rogue-waves.json)
#' - api_return_levels  : GEV return levels (return-levels.json)
#' - api_seasonal       : Monthly/seasonal means + annual trends (seasonal.json)
#' - api_correlations   : Inter-station correlations (correlations.json)
#' - api_data_dictionary: Variable metadata (data-dictionary.json)
#' - api_latest         : Most recent observation per station (latest.json)
#' - api_sources        : Data provenance constants (sources.json)
#' - api_status         : Per-station operational status (status.json)
#' - api_trends         : Mann-Kendall trends per station (trends.json)
#' - api_extremes       : GPD + CI comparison combined (extremes.json)
#' - api_decomposition  : STL decomposition per station (decomposition.json)
#' - api_spatial         : Cross-station correlations (spatial.json)
#' - api_gust_factors   : Gust factor analysis (gust-factors.json)
#' - api_methods        : Statistical methods docs (methods.json)
#' - api_index          : Endpoint catalogue (index.json)
#' - save_api_files     : Writes all JSON to docs/api/v1/
#'
#' Intermediate targets:
#' - mk_per_station     : Mann-Kendall tests per station/variable
#' - decomp_per_station : STL decomposition per station
#'
#' Dynamic schedule targets:
#' - src_ci_workflow               : File dep on data-update.yml
#' - api_update_schedule           : Human-readable schedule from CI YAML
#'
#' Bulk data targets:
#' - api_bulk_parquet              : Parquet export of full dataset
#' - api_bulk_validate             : Validates parquet row/column counts
#'
#' Vignette display targets:
#' - api_vignette_endpoints_dt     : DT::datatable of endpoints (clickable URLs)
#' - api_vignette_example_response : Sample JSON snippet
#' - api_vignette_stations_dt      : DT::datatable of station metadata
#' - api_vignette_stats_dt         : DT::datatable of per-station statistics
#' - api_vignette_return_levels_dt : DT::datatable of return levels (wide, with units)
#' - api_vignette_rogue_waves_dt   : DT::datatable of top rogue wave events
#' - api_vignette_data_dict_dt     : DT::datatable of variable definitions
#' - api_derived_metadata          : Derived statistics metadata tibble
#' - api_vignette_derived_dict_dt  : DT::datatable of derived statistics

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
      .api_wrap(stations, "stations",
        "All buoy station metadata (ID, call sign, coordinates)")
    }
  ),

  # Summary statistics (reuses dashboard_stats target)
  targets::tar_target(
    api_stats,
    {
      stats <- dashboard_stats
      .api_wrap(
        list(
          station_stats = stats$station,
          overall = list(
            total_records = stats$overall$total_records,
            date_range = as.character(stats$overall$date_range),
            stations = stats$overall$stations,
            wind_wave_correlation = round(stats$overall$wind_wave_correlation, 4),
            wave_hmax_correlation = round(stats$overall$wave_hmax_correlation, 4)
          )
        ),
        "stats", "Summary statistics per station and overall"
      )
    }
  ),

  # Rogue wave events
  targets::tar_target(
    api_rogue_waves,
    {
      events <- rogue_wave_events
      .api_wrap(
        list(n_events = nrow(events), events = events),
        "rogue-waves",
        "Detected rogue wave events (Hmax > 2x significant wave height)"
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

      # Build ci_methods from ci_comparison if available
      ci_methods <- tryCatch({
        ci_comp <- ci_comparison_per_station
        if (is.null(ci_comp) || nrow(ci_comp) == 0) return(NULL)
        ci_comp <- ci_comp[!is.na(ci_comp$return_level), ]
        ci_stations <- unique(ci_comp$station)
        lapply(stats::setNames(ci_stations, ci_stations), function(st) {
          st_data <- ci_comp[ci_comp$station == st, ]
          ci_vars <- unique(st_data$variable)
          lapply(stats::setNames(ci_vars, ci_vars), function(v) {
            v_data <- st_data[st_data$variable == v, ]
            methods <- unique(v_data$method)
            lapply(stats::setNames(methods, methods), function(m) {
              m_data <- v_data[v_data$method == m, ]
              as.list(stats::setNames(
                round(m_data$return_level, 2),
                paste0(m_data$return_period, "yr")
              ))
            })
          })
        })
      }, error = function(e) NULL)

      .api_wrap(
        list(
          method = "GPD",
          threshold = "95th percentile",
          return_periods = c(1, 5, 10),
          by_station = by_station,
          ci_methods = ci_methods
        ),
        "return-levels",
        "GPD return levels per station for 1, 5, 10-year periods"
      )
    }
  ),

  # Seasonal statistics (monthly/seasonal means + annual trends)
  targets::tar_target(
    api_seasonal,
    {
      .api_wrap(
        list(
          wave = list(
            monthly = seasonal_means_wave$monthly,
            seasonal = seasonal_means_wave$seasonal
          ),
          wind = list(
            monthly = seasonal_means_wind$monthly,
            seasonal = seasonal_means_wind$seasonal
          ),
          annual_trends = list(
            wave = list(
              annual_stats = annual_trends_wave$annual_stats,
              trend_per_decade = round(annual_trends_wave$trend_per_decade, 4),
              p_value = round(annual_trends_wave$p_value, 4),
              r_squared = round(annual_trends_wave$r_squared, 4)
            ),
            wind = list(
              annual_stats = annual_trends_wind$annual_stats,
              trend_per_decade = round(annual_trends_wind$trend_per_decade, 4),
              p_value = round(annual_trends_wind$p_value, 4),
              r_squared = round(annual_trends_wind$r_squared, 4)
            )
          )
        ),
        "seasonal",
        "Monthly and seasonal statistics with annual trends"
      )
    }
  ),

  # Inter-station correlations
  targets::tar_target(
    api_correlations,
    {
      .api_wrap(
        list(
          overall = list(
            wind_wave = round(dashboard_stats$overall$wind_wave_correlation, 4),
            wave_hmax = round(dashboard_stats$overall$wave_hmax_correlation, 4)
          ),
          station_pairs = list(
            wave_height = pair_correlations_wave,
            wind_speed = pair_correlations_wind,
            hmax = pair_correlations_hmax
          )
        ),
        "correlations",
        "Inter-station correlations for wave height, wind speed, and max wave height"
      )
    }
  ),

  # Data dictionary
  targets::tar_target(
    api_data_dictionary,
    {
      dict <- get_data_dictionary()
      .api_wrap(
        list(n_variables = nrow(dict), variables = dict),
        "data-dictionary",
        "Variable metadata: names, units, descriptions, typical ranges"
      )
    }
  ),

  # Latest observation per station
  targets::tar_target(
    api_latest,
    {
      latest <- generate_api_latest(n = 1L)
      .api_wrap(
        list(
          n_stations = dplyr::n_distinct(latest$station_id),
          observations = latest
        ),
        "latest", "Most recent observation per station"
      )
    }
  ),

  # ==========================================================================
  # NEW ENDPOINTS (PR 1 / Issue #53)
  # ==========================================================================

  # CI workflow file dependency (triggers rebuild when schedule changes)
  targets::tar_target(
    src_ci_workflow,
    ".github/workflows/data-update.yml",
    format = "file"
  ),

  # Dynamic update schedule parsed from CI workflow YAML
  targets::tar_target(
    api_update_schedule,
    {
      force(src_ci_workflow) # file dependency
      # yaml::read_yaml() converts YAML `on:` key to TRUE (boolean),
      # so use yml[["TRUE"]] instead of yml$on
      yml <- yaml::read_yaml(".github/workflows/data-update.yml")
      sched <- yml[["TRUE"]]$schedule[[1]]$cron # e.g. "0 0,6,12,18 * * *"
      if (is.null(sched)) {
        # Fallback: grep the cron expression directly from the file
        lines <- readLines(".github/workflows/data-update.yml")
        cron_line <- grep("^\\s*- cron:", lines, value = TRUE)[1]
        sched <- gsub(".*cron:\\s*['\"]?([^'\"]+)['\"]?\\s*$", "\\1", cron_line)
      }
      hours <- strsplit(strsplit(trimws(sched), " ")[[1]][2], ",")[[1]]
      paste0(
        "Every ", 24 / length(hours), " hours (",
        paste(paste0(hours, ":00"), collapse = ", "), " UTC)"
      )
    }
  ),

  # Data provenance (update_frequency from CI workflow)
  targets::tar_target(
    api_sources,
    generate_api_sources(update_frequency = api_update_schedule)
  ),

  # Per-station operational status (reuses dashboard_stats)
  targets::tar_target(
    api_status,
    generate_api_status(dashboard_stats)
  ),

  # Mann-Kendall per station/variable (intermediate target for api_trends)
  targets::tar_target(
    mk_per_station,
    {
      stations <- unique(analysis_data$station_id)
      variables <- c("wave_height", "wind_speed")

      results <- lapply(stats::setNames(stations, stations), function(st) {
        st_data <- analysis_data[analysis_data$station_id == st, ]
        lapply(stats::setNames(variables, variables), function(var) {
          if (sum(!is.na(st_data[[var]])) < 10) {
            return(list(
              tau = NA_real_, p_value = NA_real_,
              trend_direction = "insufficient data"
            ))
          }
          tryCatch(
            mann_kendall_test(st_data, variable = var, time_col = "time"),
            error = function(e) list(
              tau = NA_real_, p_value = NA_real_,
              trend_direction = paste("error:", e$message)
            )
          )
        })
      })
      results
    }
  ),

  # Trends endpoint (Mann-Kendall + annual trends)
  targets::tar_target(
    api_trends,
    generate_api_trends(mk_per_station, annual_trends_wave, annual_trends_wind)
  ),

  # Extremes endpoint (GPD return levels + CI comparison)
  targets::tar_target(
    api_extremes,
    generate_api_extremes(return_levels_per_station, ci_comparison_per_station)
  ),

  # ==========================================================================
  # NEW ENDPOINTS (PR 2 / Issue #53 Tier 2)
  # ==========================================================================

  # STL decomposition per station (intermediate target)
  targets::tar_target(
    decomp_per_station,
    {
      stations <- unique(analysis_data$station_id)
      results <- lapply(stats::setNames(stations, stations), function(st) {
        st_data <- analysis_data[analysis_data$station_id == st, ]
        if (nrow(st_data) < 168) return(NULL)  # Need at least 1 week
        tryCatch(
          decompose_stl(st_data, variable = "wave_height", frequency = "daily"),
          error = function(e) NULL
        )
      })
      results
    }
  ),

  # Decomposition endpoint
  targets::tar_target(
    api_decomposition,
    generate_api_decomposition(decomp_per_station)
  ),

  # Spatial correlations endpoint (reuses existing pair_correlations targets)
  targets::tar_target(
    api_spatial,
    generate_api_spatial(
      pair_correlations_wave,
      pair_correlations_wind,
      pair_correlations_hmax
    )
  ),

  # Gust factors endpoint (reuses existing gust_factor_analysis target)
  targets::tar_target(
    api_gust_factors,
    generate_api_gust_factors(gust_factor_analysis)
  ),

  # ==========================================================================
  # NEW ENDPOINTS (PR 3 / Issue #53 Tier 3)
  # ==========================================================================

  # Methods documentation (pure constants, no upstream dependency)
  targets::tar_target(
    api_methods,
    generate_api_methods()
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
        "latest.json" = api_latest,
        "seasonal.json" = api_seasonal,
        "correlations.json" = api_correlations,
        "sources.json" = api_sources,
        "status.json" = api_status,
        "trends.json" = api_trends,
        "extremes.json" = api_extremes,
        "decomposition.json" = api_decomposition,
        "spatial.json" = api_spatial,
        "gust-factors.json" = api_gust_factors,
        "methods.json" = api_methods
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
  # BULK PARQUET EXPORT + VALIDATION
  # ==========================================================================

  # Export full dataset as Parquet for bulk access
  targets::tar_target(
    api_bulk_parquet,
    {
      parquet_dir <- "docs/vignettes/data"
      dir.create(parquet_dir, recursive = TRUE, showWarnings = FALSE)
      parquet_path <- file.path(parquet_dir, "buoy_data.parquet")

      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con), add = TRUE)

      df <- buoy_tbl(con) |>
        dplyr::filter(.data$qc_flag %in% c(0L, 1L)) |>
        dplyr::collect()

      arrow::write_parquet(df, parquet_path)
      cli::cli_alert_success(
        "Wrote {nrow(df)} rows to {parquet_path} ({round(file.info(parquet_path)$size / 1024, 1)} KB)"
      )
      parquet_path
    },
    format = "file"
  ),

  # Validate exported Parquet
  targets::tar_target(
    api_bulk_validate,
    {
      df <- arrow::read_parquet(api_bulk_parquet)
      required_cols <- c("station_id", "time", "wave_height", "wind_speed")
      missing_cols <- setdiff(required_cols, names(df))
      if (length(missing_cols) > 0) {
        cli::cli_abort("Parquet missing required columns: {missing_cols}")
      }
      if (nrow(df) == 0) {
        cli::cli_abort("Parquet file has zero rows")
      }
      list(
        n_rows = nrow(df),
        n_stations = dplyr::n_distinct(df$station_id),
        n_cols = ncol(df),
        size_kb = round(file.info(api_bulk_parquet)$size / 1024, 1),
        validated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
      )
    }
  ),

  # ==========================================================================
  # VIGNETTE DISPLAY TARGETS
  # ==========================================================================

  # Endpoints table for the API usage vignette (clickable URLs)
  targets::tar_target(
    api_vignette_endpoints_dt,
    {
      idx <- api_index
      endpoints_df <- dplyr::bind_rows(idx$endpoints)
      # Make URLs clickable (open in new window)
      endpoints_df$url <- paste0(
        '<a href="', endpoints_df$url, '" target="_blank">',
        endpoints_df$url, '</a>'
      )
      DT::datatable(
        endpoints_df,
        caption = htmltools::tags$caption(
          style = "caption-side: top;",
          "Available API Endpoints"
        ),
        escape = FALSE, # allow HTML in url column
        options = list(
          pageLength = 17,
          dom = "Bfrtip",
          buttons = c("csv", "print"),
          columnDefs = list(
            list(width = "100px", targets = 0), # endpoint
            list(width = "35%", targets = 1),   # url (half-width)
            list(width = "55%", targets = 2)    # description (wider)
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
      example$data$observations <- head(example$data$observations, 1)
      jsonlite::toJSON(
        example,
        pretty = TRUE,
        auto_unbox = TRUE,
        POSIXt = "ISO8601",
        na = "null"
      )
    }
  ),

  # Stations table for vignette
  targets::tar_target(
    api_vignette_stations_dt,
    {
      st <- api_stations$data
      # Remove rows with all-NA numeric columns
      st <- st[!is.na(st$latitude) & !is.na(st$longitude), ]
      DT::datatable(
        st,
        caption = "Station Metadata",
        options = list(
          pageLength = 10,
          dom = "Bfrtip",
          buttons = c("csv", "print")
        ),
        rownames = FALSE,
        class = "display compact"
      )
    }
  ),

  # Stats table for vignette
  targets::tar_target(
    api_vignette_stats_dt,
    {
      st_stats <- api_stats$data$station_stats
      # station_stats is already a data frame from dashboard_stats
      df <- st_stats |>
        dplyr::transmute(
          station = .data$station_id,
          n_records = .data$n_records,
          mean_wave_height = round(.data$mean_wave_height, 2),
          max_wave_height = round(.data$max_wave_height, 2),
          mean_wind_speed = round(.data$mean_wind_speed, 2),
          max_wind_speed = round(.data$max_wind_speed, 2)
        )
      DT::datatable(
        df,
        caption = "Per-Station Summary Statistics",
        options = list(
          pageLength = 10,
          dom = "Bfrtip",
          buttons = c("csv", "print")
        ),
        rownames = FALSE,
        class = "display compact"
      )
    }
  ),

  # Return levels table for vignette (wide format with units)
  targets::tar_target(
    api_vignette_return_levels_dt,
    {
      rl <- api_return_levels$data$by_station
      unit_map <- c(
        wave_height = "m", hmax = "m",
        wind_speed = "kn", gust = "kn"
      )
      rows <- lapply(names(rl), function(station) {
        vars <- rl[[station]]
        lapply(names(vars), function(variable) {
          periods <- vars[[variable]]
          tibble::tibble(
            station = station,
            variable = variable,
            unit = unit_map[variable] %||% "\u2014",
            `1yr` = periods[["1yr"]] %||% NA_real_,
            `5yr` = periods[["5yr"]] %||% NA_real_,
            `10yr` = periods[["10yr"]] %||% NA_real_
          )
        })
      })
      df <- dplyr::bind_rows(unlist(rows, recursive = FALSE))
      DT::datatable(
        df,
        caption = htmltools::tags$caption(
          style = "caption-side: top;",
          "GPD Return Levels by Station and Variable (with units)"
        ),
        options = list(
          pageLength = 15,
          dom = "Bfrtip",
          buttons = c("csv", "print")
        ),
        rownames = FALSE,
        class = "display compact"
      ) |> DT::formatRound(columns = c("1yr", "5yr", "10yr"), digits = 2)
    }
  ),

  # Rogue waves preview table for vignette (top 20 by ratio)
  targets::tar_target(
    api_vignette_rogue_waves_dt,
    {
      events <- api_rogue_waves$data$events
      if (is.data.frame(events) && nrow(events) > 0) {
        events <- events[order(-events$rogue_ratio), ]
        events <- utils::head(events, 20)
      }
      DT::datatable(
        events,
        caption = paste0(
          "Top Rogue Wave Events (showing 20 of ",
          api_rogue_waves$data$n_events, " total)"
        ),
        options = list(
          pageLength = 10,
          dom = "Bfrtip",
          buttons = c("csv", "print"),
          scrollX = TRUE
        ),
        rownames = FALSE,
        class = "display compact"
      )
    }
  ),

  # Data dictionary table for vignette
  targets::tar_target(
    api_vignette_data_dict_dt,
    {
      vars <- api_data_dictionary$data$variables
      DT::datatable(
        vars,
        caption = "Data Dictionary: Variable Definitions",
        options = list(
          pageLength = 20,
          dom = "Bfrtip",
          buttons = c("csv", "print")
        ),
        rownames = FALSE,
        class = "display compact"
      )
    }
  ),

  # Derived statistics metadata (units for computed/estimated quantities)
  targets::tar_target(
    api_derived_metadata,
    {
      tibble::tribble(
        ~statistic,                ~unit,           ~description,                                        ~source_endpoint,
        "Return level (wave)",     "m",             "GPD return level for wave height",                  "return-levels.json",
        "Return level (Hmax)",     "m",             "GPD return level for max wave height",              "return-levels.json",
        "Return level (wind)",     "kn",            "GPD return level for wind speed",                   "return-levels.json",
        "Return level (gust)",     "kn",            "GPD return level for gust speed",                   "return-levels.json",
        "Seasonal mean (wave)",    "m",             "Monthly/seasonal mean wave height",                 "seasonal.json",
        "Seasonal mean (wind)",    "kn",            "Monthly/seasonal mean wind speed",                  "seasonal.json",
        "Trend per decade (wave)", "m/decade",      "Linear trend in annual mean wave height",           "trends.json",
        "Trend per decade (wind)", "kn/decade",     "Linear trend in annual mean wind speed",            "trends.json",
        "Mann-Kendall tau",        "dimensionless", "Kendall rank correlation coefficient (-1 to 1)",    "trends.json",
        "Mann-Kendall p-value",    "dimensionless", "Significance of monotonic trend",                   "trends.json",
        "Rogue ratio",             "dimensionless", "Hmax / significant wave height (>2.0 = rogue)",     "rogue-waves.json",
        "Gust factor",             "dimensionless", "Gust / mean wind speed",                            "gust-factors.json",
        "Pair correlation",        "dimensionless", "Cross-station correlation (Pearson r, -1 to 1)",    "spatial.json",
        "STL seasonal component",  "same as input", "Seasonal component from STL decomposition",        "decomposition.json",
        "STL trend component",     "same as input", "Trend component from STL decomposition",           "decomposition.json",
        "STL remainder",           "same as input", "Remainder (residual) from STL decomposition",      "decomposition.json"
      )
    }
  ),

  # DT display of derived metadata for vignette
  targets::tar_target(
    api_vignette_derived_dict_dt,
    {
      DT::datatable(
        api_derived_metadata,
        caption = htmltools::tags$caption(
          style = "caption-side: top;",
          "Derived Statistics: Units and Definitions"
        ),
        options = list(
          pageLength = 20,
          dom = "Bfrtip",
          buttons = c("csv", "print"),
          columnDefs = list(
            list(width = "180px", targets = 0),
            list(width = "100px", targets = 1),
            list(width = "140px", targets = 3)
          )
        ),
        rownames = FALSE,
        class = "display compact"
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
