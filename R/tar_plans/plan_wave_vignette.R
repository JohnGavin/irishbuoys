#' Wave Analysis Vignette Display Targets
#'
#' Pre-computed display data for wave_analysis.qmd.
#' MANDATORY: The vignette must use tar_load() for ALL data.
#' No inline computation beyond trivial display formatting.
#'
#' @details
#' Targets:
#' - wave_vignette_missing_summary   : Missing data availability by station
#' - wave_vignette_rogue_table       : Rogue events table with gust_ratio
#' - wave_vignette_rl_wide           : Return levels in wide format for display
#' - wave_vignette_gpd_params        : GPD parameters data frame (all variables/stations)
#' - wave_vignette_threshold_sens    : Threshold sensitivity for M3 wave height
#' - wave_vignette_gev_pooled_params : GEV pooled parameter estimates (illustrative)
#' - wave_vignette_ci_comparison     : CI comparison table (delta vs bootstrap, wide)

plan_wave_vignette <- list(

  # Missing data availability summary by station
  targets::tar_target(
    wave_vignette_missing_summary,
    {
      if (is.null(missing_data_grid)) return(NULL)

      missing_data_grid |>
        dplyr::group_by(.data$station_id) |>
        dplyr::summarise(
          total_days = as.numeric(max(.data$date) - min(.data$date)) + 1L,
          days_wave_obs = sum(.data$n_wave_height > 0),
          days_wind_obs = sum(.data$n_wind_speed > 0),
          days_hmax_obs = sum(.data$n_hmax > 0),
          pct_wave = round(100 * .data$days_wave_obs / .data$total_days, 1),
          pct_wind = round(100 * .data$days_wind_obs / .data$total_days, 1),
          pct_hmax = round(100 * .data$days_hmax_obs / .data$total_days, 1),
          .groups = "drop"
        )
    }
  ),

  # Rogue wave events table with gust_ratio column
  targets::tar_target(
    wave_vignette_rogue_table,
    {
      if (is.null(rogue_wave_events) || nrow(rogue_wave_events) == 0) return(NULL)

      rogue_wave_events |>
        dplyr::mutate(gust_ratio = round(.data$gust / .data$wind_speed, 2)) |>
        dplyr::arrange(dplyr::desc(.data$rogue_ratio)) |>
        dplyr::select(
          "time", "station_id", "wave_height", "hmax", "rogue_ratio",
          "wind_speed", "gust", "gust_ratio", "atmospheric_pressure"
        ) |>
        dplyr::mutate(
          time = format(.data$time, "%Y-%m-%d %H:%M"),
          dplyr::across(dplyr::where(is.numeric), ~ round(., 2))
        )
    }
  ),

  # Return levels in wide format (all stations, all variables)
  targets::tar_target(
    wave_vignette_rl_wide,
    {
      if (is.null(return_levels_per_station)) return(NULL)

      return_levels_per_station |>
        dplyr::filter(!is.na(.data$return_level)) |>
        dplyr::mutate(
          col_name = paste0(.data$variable_label, " ", .data$return_period, "yr"),
          return_level = round(.data$return_level, 2)
        ) |>
        dplyr::select("station", "col_name", "return_level") |>
        tidyr::pivot_wider(names_from = "col_name", values_from = "return_level")
    }
  ),

  # GPD parameters for all 4 variables across all stations
  targets::tar_target(
    wave_vignette_gpd_params,
    {
      gpd_all <- list(
        list(name = "Avg Wave", fits = gpd_wave_per_station),
        list(name = "Rogue Wave", fits = gpd_hmax_per_station),
        list(name = "Avg Wind", fits = gpd_wind_per_station),
        list(name = "Wind Gust", fits = gpd_gust_per_station)
      )

      gpd_params_list <- lapply(gpd_all, function(var_info) {
        if (is.null(var_info$fits)) return(NULL)
        lapply(names(var_info$fits), function(st) {
          res <- var_info$fits[[st]][["medium"]]
          if (!is.null(res) && is.null(res$error) && !is.null(res$scale)) {
            data.frame(
              variable = var_info$name,
              station = st,
              threshold_value = round(res$u, 2),
              n_exceedances = res$n_exceed,
              scale = round(as.numeric(res$scale), 3),
              shape = round(as.numeric(res$shape), 3),
              se_scale = round(as.numeric(res$se_scale), 4),
              se_shape = round(as.numeric(res$se_shape), 4),
              stringsAsFactors = FALSE
            )
          }
        }) |> (\(x) do.call(rbind, Filter(Negate(is.null), x)))()
      })

      do.call(rbind, Filter(Negate(is.null), gpd_params_list))
    }
  ),

  # Threshold sensitivity for M3 wave height
  targets::tar_target(
    wave_vignette_threshold_sens,
    {
      if (is.null(gpd_wave_per_station) || !("M3" %in% names(gpd_wave_per_station))) {
        return(NULL)
      }

      m3_gpd <- gpd_wave_per_station[["M3"]]
      threshold_comparison <- lapply(names(m3_gpd), function(thr) {
        res <- m3_gpd[[thr]]
        if (!is.null(res) && is.null(res$error) && !is.null(res$scale)) {
          data.frame(
            threshold = thr,
            quantile = paste0(c(low = "90%", medium = "95%", high = "99%")[thr]),
            u = round(res$u, 2),
            n_exceed = res$n_exceed,
            scale = round(as.numeric(res$scale), 3),
            shape = round(as.numeric(res$shape), 3),
            stringsAsFactors = FALSE
          )
        }
      })
      do.call(rbind, Filter(Negate(is.null), threshold_comparison))
    }
  ),

  # GEV pooled parameter estimates (illustrative)
  targets::tar_target(
    wave_vignette_gev_pooled_params,
    {
      if (is.null(analysis_summary) || !("gev_pooled_fits" %in% names(analysis_summary))) {
        return(NULL)
      }

      gev_fits <- analysis_summary$gev_pooled_fits

      params_df <- data.frame(
        Variable = c("Signif Wave", "Max Wave", "Wind Speed"),
        Location = c(
          gev_fits$wave_height$parameters["location"],
          gev_fits$hmax$parameters["location"],
          gev_fits$wind_speed$parameters["location"]
        ),
        Scale = c(
          gev_fits$wave_height$parameters["scale"],
          gev_fits$hmax$parameters["scale"],
          gev_fits$wind_speed$parameters["scale"]
        ),
        Shape = c(
          gev_fits$wave_height$parameters["shape"],
          gev_fits$hmax$parameters["shape"],
          gev_fits$wind_speed$parameters["shape"]
        ),
        N_years = c(
          gev_fits$wave_height$n_years,
          gev_fits$hmax$n_years,
          gev_fits$wind_speed$n_years
        )
      )
      params_df$Location <- round(params_df$Location, 2)
      params_df$Scale <- round(params_df$Scale, 3)
      params_df$Shape <- round(params_df$Shape, 3)
      params_df
    }
  ),

  # CI comparison table: delta-method vs bootstrap (wide format for display)
  targets::tar_target(
    wave_vignette_ci_comparison,
    {
      if (is.null(ci_comparison_per_station)) return(NULL)

      ci_comparison_per_station |>
        dplyr::filter(!is.na(.data$return_level)) |>
        dplyr::mutate(
          ci_label = paste0(
            round(.data$return_level, 2), " [",
            round(.data$lower, 2), ", ",
            round(.data$upper, 2), "]"
          ),
          col_name = paste0(.data$method, "_", .data$return_period, "yr")
        ) |>
        dplyr::select("station", "variable", "col_name", "ci_label") |>
        tidyr::pivot_wider(names_from = "col_name", values_from = "ci_label")
    }
  )
)
