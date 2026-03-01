#' Static API Generation Functions
#'
#' @description
#' Functions for generating static JSON API files served via GitHub Pages.
#' These are written to `docs/api/v1/` and updated weekly by CI.
#'
#' @family api
#' @name api_static
NULL

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
