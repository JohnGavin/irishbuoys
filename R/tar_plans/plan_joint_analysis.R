#' Targets Plan: Joint Distribution Analysis
#'
#' This plan analyzes joint distributions and dependencies between buoys,
#' including cross-correlations, time-lagged predictions, and copula models.
#'
#' @name plan_joint_analysis
NULL

plan_joint_analysis <- list(

  # Station information and distance matrix
  targets::tar_target(
    station_info,
    get_station_info()
  ),

  targets::tar_target(
    station_distances,
    station_distance_matrix(station_info)
  ),

  # Cross-correlation analysis for wave height
  targets::tar_target(
    pair_correlations_wave,
    {
      # Use analysis_data from plan_wave_analysis
      analyze_station_pairs(analysis_data, variable = "wave_height", max_lag = 48)
    }
  ),

  # Cross-correlation analysis for wind speed
  targets::tar_target(
    pair_correlations_wind,
    {
      analyze_station_pairs(analysis_data, variable = "wind_speed", max_lag = 48)
    }
  ),

  # Cross-correlation analysis for hmax
  targets::tar_target(
    pair_correlations_hmax,
    {
      analyze_station_pairs(analysis_data, variable = "hmax", max_lag = 48)
    }
  ),

  # M6 prediction models - M6 is furthest offshore
  targets::tar_target(
    m6_predicts_m2_wave,
    predict_station_lagged(analysis_data, "M6", "M2", "wave_height")
  ),

  targets::tar_target(
    m6_predicts_m3_wave,
    predict_station_lagged(analysis_data, "M6", "M3", "wave_height")
  ),

  targets::tar_target(
    m6_predicts_m4_wave,
    predict_station_lagged(analysis_data, "M6", "M4", "wave_height")
  ),

  targets::tar_target(
    m6_predicts_m5_wave,
    predict_station_lagged(analysis_data, "M6", "M5", "wave_height")
  ),

  # Combine M6 predictions
  targets::tar_target(
    m6_prediction_summary,
    {
      predictions <- list(
        M2 = m6_predicts_m2_wave,
        M3 = m6_predicts_m3_wave,
        M4 = m6_predicts_m4_wave,
        M5 = m6_predicts_m5_wave
      )

      # Extract summary metrics
      data.frame(
        target_station = names(predictions),
        lag_hours = sapply(predictions, function(x) x$lag_hours),
        r_squared = sapply(predictions, function(x) x$r_squared),
        rmse = sapply(predictions, function(x) x$rmse),
        n_obs = sapply(predictions, function(x) x$n_obs),
        distance_km = c(
          station_distances["M6", "M2"],
          station_distances["M6", "M3"],
          station_distances["M6", "M4"],
          station_distances["M6", "M5"]
        ),
        row.names = NULL,
        stringsAsFactors = FALSE
      )
    }
  ),

  # Joint extreme analysis for wave height
  targets::tar_target(
    joint_extremes_wave,
    analyze_joint_extremes(analysis_data, "wave_height", threshold_quantile = 0.95)
  ),

  # Joint extreme analysis for hmax
  targets::tar_target(
    joint_extremes_hmax,
    analyze_joint_extremes(analysis_data, "hmax", threshold_quantile = 0.95)
  ),

  # Copula analysis for adjacent station pairs (in-memory, safe for crew workers)
  # M6-M2: offshore to southwest coast
  targets::tar_target(
    copula_m6_m2_wave,
    fit_bivariate_copula(analysis_data, "M6", "M2", "wave_height", "gumbel"),
    deployment = "worker"
  ),

  # M6-M5: offshore to west coast (closest to M6)
  targets::tar_target(
    copula_m6_m5_wave,
    fit_bivariate_copula(analysis_data, "M6", "M5", "wave_height", "gumbel"),
    deployment = "worker"
  ),

  # M2-M3: two southwest stations (should be highly correlated)
  targets::tar_target(
    copula_m2_m3_wave,
    fit_bivariate_copula(analysis_data, "M2", "M3", "wave_height", "gumbel"),
    deployment = "worker"
  ),

  # Adjacent ring: 5 geographically adjacent pairs (was C(5,2)=10).
  # Ring order: M6(offshore) → M5(west) → M4(southeast) → M3(southwest) → M2(southwest) → M6.
  # Non-adjacent pairs (M6-M3, M6-M4, M2-M4, M2-M5, M3-M5) removed to halve
  # copula runtime (~2.5 min saved per tar_make). Restored if needed for
  # cross-network dependence analysis.
  targets::tar_target(
    copula_m3_m4_wave,
    fit_bivariate_copula(analysis_data, "M3", "M4", "wave_height", "gumbel"),
    deployment = "worker"
  ),

  targets::tar_target(
    copula_m4_m5_wave,
    fit_bivariate_copula(analysis_data, "M4", "M5", "wave_height", "gumbel"),
    deployment = "worker"
  ),

  # Copula summary — 5 adjacent pairs
  targets::tar_target(
    copula_summary,
    {
      copulas <- list(
        `M6-M2` = copula_m6_m2_wave,
        `M6-M5` = copula_m6_m5_wave,
        `M2-M3` = copula_m2_m3_wave,
        `M3-M4` = copula_m3_m4_wave,
        `M4-M5` = copula_m4_m5_wave
      )

      data.frame(
        pair = names(copulas),
        kendall_tau = sapply(copulas, function(x) {
          if (is.null(x$error)) x$tau else NA
        }),
        upper_tail_dep = sapply(copulas, function(x) {
          if (is.null(x$error)) x$tail_dependence$upper else NA
        }),
        lower_tail_dep = sapply(copulas, function(x) {
          if (is.null(x$error)) x$tail_dependence$lower else NA
        }),
        n_obs = sapply(copulas, function(x) {
          if (is.null(x$error)) x$n_obs else NA
        }),
        row.names = NULL,
        stringsAsFactors = FALSE
      )
    }
  ),

  # Combined summary for vignette
  targets::tar_target(
    joint_analysis_results,
    list(
      station_info = station_info,
      station_distances = station_distances,
      pair_correlations = list(
        wave_height = pair_correlations_wave,
        wind_speed = pair_correlations_wind,
        hmax = pair_correlations_hmax
      ),
      m6_predictions = m6_prediction_summary,
      joint_extremes = list(
        wave_height = joint_extremes_wave,
        hmax = joint_extremes_hmax
      ),
      copula_summary = copula_summary
    )
  )
)
