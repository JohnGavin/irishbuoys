#' Static API Generation Functions
#'
#' @description
#' Functions for generating static JSON API files served via GitHub Pages.
#' These are written to `docs/api/v1/` and updated 6-hourly by CI.
#'
#' @family api
#' @name api_static
NULL

# ===========================================================================
# Internal helpers
# ===========================================================================

#' Build API Metadata Block
#'
#' @param endpoint Character, endpoint name (e.g. "trends")
#' @param description Character, human-readable description
#' @return A list with generated, package_version, endpoint, description
#' @noRd
.api_meta <- function(endpoint, description) {
  list(
    generated = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    package_version = as.character(utils::packageVersion("irishbuoys")),
    endpoint = endpoint,
    description = description
  )
}

#' Wrap API Payload with Metadata
#'
#' @param data The payload (list, data.frame, etc.)
#' @param endpoint Character, endpoint name
#' @param description Character, human-readable description
#' @return A list with `_meta` and `data` fields
#' @noRd
.api_wrap <- function(data, endpoint, description) {
  list(
    `_meta` = .api_meta(endpoint, description),
    data = data
  )
}

#' Generate API Index
#'
#' @description
#' Creates a JSON-serialisable list describing all available API endpoints.
#' Used to generate `index.json` at the API root.
#'
#' @param base_url Character, base URL for the API
#'   (default: `"https://johngavin.github.io/irishbuoys/api/v1/"`)
#' @param endpoints Named list of endpoint metadata. Each element should have
#'   `description` and optionally `fields`. If NULL, uses default endpoints.
#'
#' @return A list suitable for `jsonlite::toJSON()`.
#'
#' @family api
#' @export
#' @examples
#' \dontrun{
#' idx <- generate_api_index()
#' jsonlite::toJSON(idx, pretty = TRUE, auto_unbox = TRUE)
#' }
generate_api_index <- function(
    base_url = "https://johngavin.github.io/irishbuoys/api/v1/",
    endpoints = NULL
) {
  if (is.null(endpoints)) {
    endpoints <- list(
      list(
        endpoint = "stations.json",
        url = paste0(base_url, "stations.json"),
        description = "All buoy station metadata (ID, call sign, coordinates)"
      ),
      list(
        endpoint = "stats.json",
        url = paste0(base_url, "stats.json"),
        description = "Summary statistics per station and overall"
      ),
      list(
        endpoint = "rogue-waves.json",
        url = paste0(base_url, "rogue-waves.json"),
        description = "Detected rogue wave events (Hmax > 2x significant wave height)"
      ),
      list(
        endpoint = "return-levels.json",
        url = paste0(base_url, "return-levels.json"),
        description = "GPD return levels per station for 1, 5, 10-year periods (avg wave, rogue wave, avg wind, wind gust)"
      ),
      list(
        endpoint = "data-dictionary.json",
        url = paste0(base_url, "data-dictionary.json"),
        description = "Variable metadata: names, units, descriptions, typical ranges"
      ),
      list(
        endpoint = "latest.json",
        url = paste0(base_url, "latest.json"),
        description = "Most recent observation per station"
      ),
      list(
        endpoint = "seasonal.json",
        url = paste0(base_url, "seasonal.json"),
        description = "Monthly and seasonal statistics with annual trends (wave height, wind speed)"
      ),
      list(
        endpoint = "correlations.json",
        url = paste0(base_url, "correlations.json"),
        description = "Inter-station correlations for wave height, wind speed, and max wave height"
      ),
      list(
        endpoint = "sources.json",
        url = paste0(base_url, "sources.json"),
        description = "Data provenance: ERDDAP source, update frequency, license, citation"
      ),
      list(
        endpoint = "status.json",
        url = paste0(base_url, "status.json"),
        description = "Per-station operational status, record counts, and date ranges"
      ),
      list(
        endpoint = "trends.json",
        url = paste0(base_url, "trends.json"),
        description = "Mann-Kendall trend tests and Sen's slope estimates per station/variable"
      ),
      list(
        endpoint = "extremes.json",
        url = paste0(base_url, "extremes.json"),
        description = "GPD fits, return levels, and CI method comparison (delta, bootstrap)"
      ),
      list(
        endpoint = "decomposition.json",
        url = paste0(base_url, "decomposition.json"),
        description = "STL decomposition (seasonal, trend, remainder) per station"
      ),
      list(
        endpoint = "spatial.json",
        url = paste0(base_url, "spatial.json"),
        description = "Cross-station correlation matrices for wave height, wind speed, Hmax"
      ),
      list(
        endpoint = "gust-factors.json",
        url = paste0(base_url, "gust-factors.json"),
        description = "Gust factor analysis per station with extreme events"
      ),
      list(
        endpoint = "methods.json",
        url = paste0(base_url, "methods.json"),
        description = "Statistical methods documentation: thresholds, formulas, references"
      )
    )
  }

  list(
    api = "irishbuoys",
    version = "v1",
    base_url = base_url,
    updated_at = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
    endpoints = endpoints
  )
}

#' Generate Latest Observations
#'
#' @description
#' Queries DuckDB for the most recent `n` observations per station.
#' Returns a tibble suitable for JSON serialisation.
#'
#' @param db_path Character, path to the DuckDB database file
#'   (default: `"inst/extdata/irish_buoys.duckdb"`)
#' @param n Integer, number of most recent observations per station to return
#'   (default: 1L)
#'
#' @return A tibble with `n` rows per station, ordered by station and time
#'   (most recent first).
#'
#' @family api
#' @export
#' @examples
#' \dontrun{
#' latest <- generate_api_latest(n = 1)
#' latest_5 <- generate_api_latest(n = 5)
#' }
generate_api_latest <- function(
    db_path = "inst/extdata/irish_buoys.duckdb",
    n = 1L
) {
  n <- as.integer(n)
  if (n < 1L) {
    cli::cli_abort(c(
      "x" = "{.arg n} must be >= 1, not {n}."
    ))
  }

  con <- connect_duckdb(db_path = db_path)

  on.exit(DBI::dbDisconnect(con), add = TRUE)


  # Use window function (row_number) which DuckDB translates natively
  # Include qc_flag 0 (unchecked) and 1 (good) — ERDDAP data arrives as flag 0
  result <- buoy_tbl(con) |>
    dplyr::filter(.data$qc_flag %in% c(0L, 1L)) |>
    dplyr::group_by(.data$station_id) |>
    dplyr::arrange(dplyr::desc(.data$time), .by_group = TRUE) |>
    dplyr::mutate(rn = dplyr::row_number()) |>
    dplyr::filter(.data$rn <= n) |>
    dplyr::ungroup() |>
    dplyr::select(-"rn") |>
    dplyr::collect()

  cli::cli_alert_success(
    "Retrieved {nrow(result)} latest observations ({n} per station)"
  )

  result
}

# ===========================================================================
# PR 1: New endpoint generators
# ===========================================================================

#' Generate Data Sources Endpoint
#'
#' @description
#' Returns data provenance constants: ERDDAP URL, dataset ID,
#' update frequency, license, and citation.
#'
#' @param update_frequency Character, human-readable update schedule.
#'   If NULL (default), uses "Every 6 hours (0:00, 6:00, 12:00, 18:00 UTC)".
#'   Typically supplied dynamically from the `api_update_schedule` target.
#'
#' @return A list with `_meta` and `data` fields suitable for
#'   `jsonlite::toJSON()`.
#'
#' @family api
#' @export
#' @examples
#' \dontrun{
#' src <- generate_api_sources()
#' jsonlite::toJSON(src, pretty = TRUE, auto_unbox = TRUE)
#' }
generate_api_sources <- function(update_frequency = NULL) {
  if (is.null(update_frequency)) {
    update_frequency <- "Every 6 hours (0:00, 6:00, 12:00, 18:00 UTC)"
  }
  .api_wrap(
    data = list(
      erddap_base_url = "https://erddap.marine.ie/erddap/tabledap/IWBNetwork",
      dataset_id = "IWBNetwork",
      info_url = "https://erddap.marine.ie/erddap/info/IWBNetwork/index.html",
      provider = "Marine Institute, Ireland",
      update_frequency = update_frequency,
      license = "Creative Commons Attribution 4.0 (CC BY 4.0)",
      citation = paste(
        "Marine Institute (2024). Irish Weather Buoy Network.",
        "Data accessed via ERDDAP at erddap.marine.ie."
      ),
      variables_measured = c(
        "wave_height", "hmax", "wave_period", "wind_speed", "gust",
        "wind_direction", "atmospheric_pressure", "air_temperature",
        "sea_temperature"
      )
    ),
    endpoint = "sources",
    description = "Data provenance: ERDDAP source, update frequency, license, citation"
  )
}

#' Generate Station Status Endpoint
#'
#' @description
#' Returns per-station operational status including record counts
#' and date ranges. Reuses `dashboard_stats` target output.
#'
#' @param dashboard_stats List, output from the `dashboard_stats` target
#'   containing `station` (tibble) and `overall` (list) elements.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_status <- function(dashboard_stats) {
  station_df <- dashboard_stats$station
  overall <- dashboard_stats$overall

  stations_list <- lapply(seq_len(nrow(station_df)), function(i) {
    row <- station_df[i, ]
    list(
      station_id = row$station_id,
      n_records = row$n_records,
      first_date = format(row$first_date, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      last_date = format(row$last_date, "%Y-%m-%dT%H:%M:%SZ", tz = "UTC"),
      mean_wave_height = round(row$mean_wave_height, 2),
      max_wave_height = round(row$max_wave_height, 2),
      mean_wind_speed = round(row$mean_wind_speed, 2),
      max_wind_speed = round(row$max_wind_speed, 2)
    )
  })

  .api_wrap(
    data = list(
      n_stations = nrow(station_df),
      total_records = overall$total_records,
      date_range = as.character(overall$date_range),
      stations = stations_list
    ),
    endpoint = "status",
    description = "Per-station operational status, record counts, and date ranges"
  )
}

#' Generate Trends Endpoint
#'
#' @description
#' Returns Mann-Kendall trend tests per station/variable and overall
#' annual trend statistics for wave height and wind speed.
#'
#' @param mann_kendall_per_station Named list of per-station Mann-Kendall
#'   results. Each element is a station, containing named sub-elements
#'   for each variable (e.g. `wave_height`, `wind_speed`), each with
#'   `tau`, `p_value`, `trend_direction`.
#' @param annual_trends_wave List with `annual_stats`, `trend_per_decade`,
#'   `p_value`, `r_squared`.
#' @param annual_trends_wind Same structure as `annual_trends_wave`.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_trends <- function(
    mann_kendall_per_station,
    annual_trends_wave,
    annual_trends_wind
) {
  .api_wrap(
    data = list(
      mann_kendall = mann_kendall_per_station,
      annual_trends = list(
        wave = list(
          trend_per_decade = round(annual_trends_wave$trend_per_decade, 4),
          p_value = round(annual_trends_wave$p_value, 4),
          r_squared = round(annual_trends_wave$r_squared, 4)
        ),
        wind = list(
          trend_per_decade = round(annual_trends_wind$trend_per_decade, 4),
          p_value = round(annual_trends_wind$p_value, 4),
          r_squared = round(annual_trends_wind$r_squared, 4)
        )
      )
    ),
    endpoint = "trends",
    description = "Mann-Kendall trend tests and Sen's slope estimates per station/variable"
  )
}

#' Generate Extremes Endpoint
#'
#' @description
#' Combines GPD return levels and CI comparison (delta, bootstrap,
#' order-statistics) into a single endpoint.
#'
#' @param return_levels_per_station Tibble with columns `return_period`,
#'   `return_level`, `lower`, `upper`, `station`, `variable`, `variable_label`.
#' @param ci_comparison_per_station Tibble with columns `return_period`,
#'   `return_level`, `lower`, `upper`, `station`, `variable`, `method`.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_extremes <- function(
    return_levels_per_station,
    ci_comparison_per_station
) {
  # Build nested return levels by station
  rl <- return_levels_per_station
  rl <- rl[!is.na(rl$return_level), ]
  stations <- unique(rl$station)

  by_station <- lapply(stats::setNames(stations, stations), function(st) {
    st_data <- rl[rl$station == st, ]
    vars <- unique(st_data$variable)
    lapply(stats::setNames(vars, vars), function(v) {
      v_data <- st_data[st_data$variable == v, ]
      lapply(seq_len(nrow(v_data)), function(i) {
        list(
          return_period = v_data$return_period[i],
          return_level = round(v_data$return_level[i], 2),
          lower = round(v_data$lower[i], 2),
          upper = round(v_data$upper[i], 2)
        )
      })
    })
  })

  # Build CI comparison summary
  ci <- ci_comparison_per_station
  ci_methods <- if (!is.null(ci) && nrow(ci) > 0) {
    unique(ci$method)
  } else {
    character(0)
  }

  .api_wrap(
    data = list(
      method = "GPD",
      threshold = "95th percentile",
      return_periods = c(1, 5, 10),
      return_levels = by_station,
      ci_comparison = list(
        methods = ci_methods,
        n_rows = nrow(ci),
        records = ci
      )
    ),
    endpoint = "extremes",
    description = "GPD fits, return levels, and CI method comparison (delta, bootstrap)"
  )
}

# ===========================================================================
# PR 2: Analysis-derived endpoint generators
# ===========================================================================

#' Generate Decomposition Endpoint
#'
#' @description
#' Returns STL decomposition results per station, downsampled to daily
#' resolution to keep JSON under 1MB.
#'
#' @param decomp_per_station Named list of per-station decomposition results.
#'   Each element should have `components` (data.frame with time, seasonal,
#'   trend, remainder), `summary`, and `variable`.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_decomposition <- function(decomp_per_station) {
  stations <- lapply(
    stats::setNames(names(decomp_per_station), names(decomp_per_station)),
    function(st) {
      decomp <- decomp_per_station[[st]]
      if (is.null(decomp)) return(NULL)

      comp <- decomp$components
      # Downsample to daily: take first observation per date
      if (is.data.frame(comp) && nrow(comp) > 0) {
        comp$date <- as.Date(comp$time)
        comp <- comp[!duplicated(comp$date), ]
        comp$time <- NULL
        # Round numeric columns
        num_cols <- c("seasonal", "trend", "remainder")
        for (col in intersect(num_cols, names(comp))) {
          comp[[col]] <- round(comp[[col]], 4)
        }
      }

      list(
        variable = decomp$variable %||% "wave_height",
        n_daily_points = nrow(comp),
        summary = decomp$summary,
        components = comp
      )
    }
  )

  .api_wrap(
    data = list(
      resolution = "daily (downsampled from hourly)",
      stations = stations
    ),
    endpoint = "decomposition",
    description = "STL decomposition (seasonal, trend, remainder) per station"
  )
}

#' Generate Spatial Correlations Endpoint
#'
#' @description
#' Returns cross-station correlation matrices for wave height,
#' wind speed, and Hmax.
#'
#' @param pair_wave Data frame from `analyze_station_pairs()` for wave height.
#' @param pair_wind Data frame from `analyze_station_pairs()` for wind speed.
#' @param pair_hmax Data frame from `analyze_station_pairs()` for Hmax.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_spatial <- function(pair_wave, pair_wind, pair_hmax) {
  round_pairs <- function(df) {
    if (is.null(df) || !is.data.frame(df)) return(df)
    num_cols <- c("distance_km", "max_correlation", "expected_lag")
    for (col in intersect(num_cols, names(df))) {
      df[[col]] <- round(df[[col]], 4)
    }
    df
  }

  .api_wrap(
    data = list(
      wave_height = round_pairs(pair_wave),
      wind_speed = round_pairs(pair_wind),
      hmax = round_pairs(pair_hmax)
    ),
    endpoint = "spatial",
    description = "Cross-station correlation matrices for wave height, wind speed, Hmax"
  )
}

#' Generate Gust Factors Endpoint
#'
#' @description
#' Returns gust factor analysis results per station, capped at 500
#' extreme events to keep JSON under 1MB.
#'
#' @param gust_analysis List from `analyze_gust_factor()` containing
#'   `summary`, `extreme_gusts`, `by_station`, `rogue_gust_threshold`,
#'   `n_rogue_gusts`, `pct_rogue_gusts`.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_gust_factors <- function(gust_analysis) {
  # Cap extreme_gusts at 500 rows

  extreme <- gust_analysis$extreme_gusts
  if (is.data.frame(extreme) && nrow(extreme) > 500) {
    # Keep highest gust factor events
    if ("gust_factor" %in% names(extreme)) {
      extreme <- extreme[order(-extreme$gust_factor), ]
    }
    extreme <- utils::head(extreme, 500)
  }

  .api_wrap(
    data = list(
      summary = gust_analysis$summary,
      extreme_gusts = extreme,
      by_station = gust_analysis$by_station,
      rogue_gust_threshold = gust_analysis$rogue_gust_threshold,
      n_rogue_gusts = gust_analysis$n_rogue_gusts,
      pct_rogue_gusts = round(gust_analysis$pct_rogue_gusts, 4)
    ),
    endpoint = "gust-factors",
    description = "Gust factor analysis per station with extreme events"
  )
}

# ===========================================================================
# PR 3: Methods documentation endpoint
# ===========================================================================

#' Generate Methods Endpoint
#'
#' @description
#' Returns statistical methods documentation: thresholds, formulas,
#' references. Pure function with no upstream target dependency.
#'
#' @return A list with `_meta` and `data` fields.
#'
#' @family api
#' @export
generate_api_methods <- function() {
  .api_wrap(
    data = list(
      gpd = list(
        description = paste(
          "Generalised Pareto Distribution fitted to exceedances above",
          "a threshold using maximum likelihood estimation (mev::fit.gpd)."
        ),
        threshold = "95th percentile of the variable's distribution",
        return_periods = c(1, 5, 10),
        observations_per_year = 8760L,
        ci_methods = list(
          delta = "Delta method (asymptotic normal approximation of MLE)",
          bootstrap = paste(
            "Block bootstrap (block_size=48h) with 500 resamples;",
            "percentile CIs at 95% level"
          )
        ),
        references = c(
          "Coles, S. (2001). An Introduction to Statistical Modeling of Extreme Values. Springer.",
          "Beirlant, J. et al. (2004). Statistics of Extremes. Wiley."
        )
      ),
      mann_kendall = list(
        description = paste(
          "Non-parametric trend test using Kendall's tau correlation",
          "between time index and variable values."
        ),
        significance_level = 0.05,
        trend_classification = list(
          increasing = "tau > 0 and p < 0.05",
          decreasing = "tau < 0 and p < 0.05",
          no_trend = "p >= 0.05"
        ),
        references = c(
          "Mann, H.B. (1945). Nonparametric tests against trend. Econometrica, 13, 245-259.",
          "Kendall, M.G. (1975). Rank Correlation Methods. Griffin, London."
        )
      ),
      stl_decomposition = list(
        description = paste(
          "Seasonal and Trend decomposition using Loess (STL).",
          "Separates time series into seasonal, trend, and remainder components."
        ),
        frequency = "daily (24 observations per cycle for hourly data)",
        references = c(
          "Cleveland, R.B. et al. (1990). STL: A Seasonal-Trend Decomposition Procedure Based on Loess. J. Official Statistics, 6, 3-73."
        )
      ),
      rogue_wave_detection = list(
        description = "Rogue waves detected where Hmax exceeds 2x significant wave height (Hs).",
        criterion = "Hmax / Hs > 2.0",
        references = c(
          "Haver, S. (2004). A possible freak wave event measured at the Draupner jacket January 1 1995.",
          "Kharif, C. & Pelinovsky, E. (2003). Physical mechanisms of the rogue wave phenomenon. Eur. J. Mech. B/Fluids, 22, 603-634."
        )
      ),
      gust_factor = list(
        description = "Ratio of gust speed to mean wind speed. Rogue gusts exceed a threshold factor.",
        formula = "gust_factor = gust / wind_speed",
        min_wind_speed = 5,
        references = c(
          "WMO (2018). Guide to Meteorological Instruments and Methods of Observation. WMO-No. 8."
        )
      ),
      cross_correlation = list(
        description = paste(
          "Cross-correlation between station pairs at varying lags,",
          "used to identify wave propagation patterns."
        ),
        max_lag = 48,
        expected_propagation_speed = "~30 km/h (swell)",
        references = c(
          "Hasselmann, K. et al. (1973). Measurements of wind-wave growth and swell decay during JONSWAP. Dt. Hydrogr. Z., A8(12), 1-95."
        )
      )
    ),
    endpoint = "methods",
    description = "Statistical methods documentation: thresholds, formulas, references"
  )
}
