#' Spatial Max-Stable Process Models
#'
#' @description
#' Functions for fitting max-stable process models to spatial extreme data.
#' Requires the SpatialExtremes package for Brown-Resnick and Schlather models.
#'
#' @name spatial_maxstable
#' @keywords internal
NULL

#' Try Fitting Max-Stable Models with Fallback
#'
#' Attempts Brown-Resnick first, then Schlather (Whittle-Matern) if that fails.
#' Returns both the fit object and model type to avoid `<<-` superassignment.
#'
#' @param frechet_data Matrix of Frechet-transformed annual maxima
#' @param coords Coordinate matrix (lon, lat)
#' @return List with `fit` (model object or NULL) and `model_type` (character)
#' @keywords internal
#' @noRd
try_maxstable_fit <- function(frechet_data, coords) {
  # Brown-Resnick (primary)
  br_fit <- tryCatch({
    cli::cli_alert_info("Fitting Brown-Resnick max-stable model...")
    result <- SpatialExtremes::fitmaxstab(
      frechet_data, coords,
      cov.mod = "brown",
      start = list(range = 200, smooth = 1),
      control = list(maxit = 500)
    )
    cli::cli_alert_success(
      "Brown-Resnick fit: range={round(result$fitted.values['range'], 1)}, smooth={round(result$fitted.values['smooth'], 3)}"
    )
    list(fit = result, model_type = "brown_resnick")
  }, error = function(e) {
    cli::cli_alert_warning("Brown-Resnick failed: {e$message}")
    NULL
  })

  if (!is.null(br_fit)) return(br_fit)

  # Schlather fallback (Whittle-Matern covariance)
  sch_fit <- tryCatch({
    cli::cli_alert_info("Trying Schlather model as fallback...")
    result <- SpatialExtremes::fitmaxstab(
      frechet_data, coords,
      cov.mod = "whitmat",
      start = list(nugget = 0, range = 200, smooth = 1),
      control = list(maxit = 500)
    )
    cli::cli_alert_success("Schlather fit succeeded")
    list(fit = result, model_type = "schlather")
  }, error = function(e2) {
    cli::cli_alert_warning("Schlather also failed: {e2$message}")
    NULL
  })

  if (!is.null(sch_fit)) return(sch_fit)

  list(fit = NULL, model_type = NA_character_)
}

#' Fit a Max-Stable Process to Station Annual Maxima
#'
#' @description
#' Fits a Brown-Resnick max-stable process model to annual block maxima of wave
#' heights across multiple stations. Margins are first transformed to unit
#' Frechet using the empirical CDF. If the Brown-Resnick model fails to
#' converge, a Schlather model (Whittle-Matern covariance) is tried as fallback.
#'
#' **Limitation:** Max-stable models require many spatial locations (typically
#' >= 20) for reliable estimation. With only 5 buoy stations, results are
#' illustrative and the information matrix is often singular.
#'
#' @param data Data frame with columns: `time` (POSIXct), `station_id`
#'   (character), and the variable specified by `variable`.
#' @param variable Variable to analyze (default: `"wave_height"`).
#' @param station_info Optional data frame with station metadata (from
#'   [get_station_info()]). Must contain `station_id`, `lat`, `lon`. If `NULL`,
#'   uses the default 5-station network.
#' @param min_years Minimum number of complete years required across all
#'   stations (default: 5).
#'
#' @return List with:
#'   \describe{
#'     \item{fitted}{Logical: whether a max-stable model was successfully fitted.}
#'     \item{fit}{The fitted model object (from `SpatialExtremes::fitmaxstab`),
#'       or `NULL` if fitting failed.}
#'     \item{model_type}{Character: `"brown_resnick"`, `"schlather"`, or `NA`.}
#'     \item{parameters}{Named numeric vector of fitted parameters, or `NULL`.}
#'     \item{annual_maxima}{Data frame of annual maxima per station (long format).}
#'     \item{coords}{Coordinate matrix (lon, lat) used for fitting.}
#'     \item{limitation}{Character string describing the illustrative nature
#'       of results with few stations.}
#'   }
#'   If fitting fails entirely, `fitted = FALSE` and a `reason` field explains why.
#'
#' @family spatial-extremes
#' @export
#' @examples
#' \dontrun{
#' con <- connect_duckdb()
#' data <- query_buoy_data(con, variables = c("time", "station_id", "wave_height"))
#' result <- fit_spatial_maxstable(data)
#' if (result$fitted) print(result$parameters)
#' DBI::dbDisconnect(con)
#' }
fit_spatial_maxstable <- function(
    data,
    variable = "wave_height",
    station_info = NULL,
    min_years = 5
) {
  if (!requireNamespace("SpatialExtremes", quietly = TRUE)) {
    cli::cli_abort(c(
      "x" = "Package {.pkg SpatialExtremes} is required for max-stable models.",
      "i" = "Add {.pkg SpatialExtremes} to your Nix environment."
    ))
  }

  limitation_msg <- paste(
    "Max-stable process results are illustrative only.",
    "N=5 stations is below the recommended minimum of ~20",
    "for reliable spatial model fitting.",
    "Pairwise copula analysis (compute_extremal_dependence) is more robust",
    "for this station network."
  )

  # Validate inputs
  required_cols <- c("time", "station_id", variable)
  missing_cols <- setdiff(required_cols, names(data))
  if (length(missing_cols) > 0) {
    cli::cli_abort(c(
      "x" = "Missing required columns: {.val {missing_cols}}",
      "i" = "Data must contain: {.val {required_cols}}"
    ))
  }

  if (is.null(station_info)) {
    station_info <- get_station_info()
  }

  # Ensure time is POSIXct
  if (!inherits(data$time, "POSIXct")) {
    data$time <- as.POSIXct(data$time)
  }

  # Compute annual maxima per station
  data$year <- as.integer(format(data$time, "%Y"))
  stations <- sort(unique(data$station_id))

  annual_max_list <- lapply(stations, function(stn) {
    stn_data <- data[data$station_id == stn, ]
    agg <- stats::aggregate(
      stn_data[[variable]],
      by = list(year = stn_data$year),
      FUN = max, na.rm = TRUE
    )
    names(agg) <- c("year", "max_value")
    agg$station_id <- stn
    agg[is.finite(agg$max_value), ]
  })
  annual_max <- do.call(rbind, annual_max_list)
  row.names(annual_max) <- NULL

  # Pivot to wide format (rows = years, columns = stations)
  max_wide <- stats::reshape(
    annual_max,
    direction = "wide",
    idvar = "year",
    timevar = "station_id",
    v.names = "max_value"
  )
  names(max_wide) <- gsub("max_value\\.", "", names(max_wide))
  max_wide <- max_wide[stats::complete.cases(max_wide), ]
  max_wide <- max_wide[order(max_wide$year), ]

  cli::cli_alert_info("Annual maxima: {nrow(max_wide)} complete years across {length(stations)} stations")

  if (nrow(max_wide) < min_years) {
    cli::cli_alert_warning("Too few complete years ({nrow(max_wide)}) for max-stable fitting")
    return(list(
      fitted = FALSE,
      fit = NULL,
      model_type = NA_character_,
      parameters = NULL,
      annual_maxima = annual_max,
      coords = NULL,
      reason = paste0(
        "Only ", nrow(max_wide), " complete years; need at least ", min_years
      ),
      limitation = limitation_msg
    ))
  }

  # Prepare data matrix and coordinates
  stn_order <- c("M2", "M3", "M4", "M5", "M6")
  available_stns <- intersect(stn_order, colnames(max_wide))
  if (length(available_stns) == 0) {
    available_stns <- intersect(stations, colnames(max_wide))
  }

  data_mat <- as.matrix(max_wide[, available_stns, drop = FALSE])
  stn_meta <- station_info[match(available_stns, station_info$station_id), ]
  coords <- as.matrix(stn_meta[, c("lon", "lat")])

  # Transform margins to unit Frechet
  n_years <- nrow(data_mat)
  frechet_data <- data_mat
  for (j in seq_len(ncol(data_mat))) {
    ranks <- rank(data_mat[, j]) / (n_years + 1)
    frechet_data[, j] <- -1 / log(ranks)
  }

  # Fit max-stable model: Brown-Resnick primary, Schlather fallback
  # Returns list(fit, model_type) to avoid <<- superassignment
  fit_result <- try_maxstable_fit(frechet_data, coords)

  list(
    fitted = !is.null(fit_result$fit),
    fit = fit_result$fit,
    model_type = fit_result$model_type,
    parameters = if (!is.null(fit_result$fit)) fit_result$fit$fitted.values else NULL,
    annual_maxima = annual_max,
    coords = coords,
    limitation = limitation_msg
  )
}
