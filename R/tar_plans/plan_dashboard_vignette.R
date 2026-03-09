#' Dashboard Vignette Display Targets
#'
#' Pre-computed display data for dashboard_static.qmd.
#' MANDATORY: The vignette must use tar_load() for ALL data.
#' No inline computation beyond trivial display formatting.
#'
#' @details
#' Targets:
#' - dash_vignette_scalars     : Correlations, max values, date captions, counts
#' - dash_vignette_stats       : Per-station hmax/wave/wind statistics tables
#' - dash_vignette_data_tables : Top-5000 data tables (hmax, wave, wind, scatter)
#' - dash_vignette_reg_stats   : Wind-wave regression statistics
#' - dash_vignette_rogue       : Rogue merged events, rogue waves, extreme gusts
#' - dash_vignette_rl          : Return level tables (1yr, 5yr, 10yr, all wide)

plan_dashboard_vignette <- list(

  # Scalar summary values for dashboard vignette

  targets::tar_target(
    dash_vignette_scalars,
    {
      data <- dashboard_buoy_data

      valid_ww <- complete.cases(data$wind_speed, data$wave_height)
      valid_wh <- complete.cases(data$wave_height, data$hmax)

      max_hmax_row <- data[which.max(data$hmax), ]
      max_signif_row <- data[which.max(data$wave_height), ]

      list(
        cor_wind_wave = round(cor(data$wind_speed[valid_ww], data$wave_height[valid_ww]), 3),
        cor_wave_hmax = round(cor(data$wave_height[valid_wh], data$hmax[valid_wh]), 3),
        days_span = round(as.numeric(difftime(max(data$time), min(data$time), units = "days"))),
        date_caption = paste0(
          format(min(data$time), "%Y-%m-%d"), " to ",
          format(max(data$time), "%Y-%m-%d")
        ),
        n_records = format(nrow(data), big.mark = ","),
        n_records_raw = nrow(data),
        stations = sort(unique(data$station_id)),
        max_hmax = round(max_hmax_row$hmax, 1),
        max_hmax_date = format(max_hmax_row$time, "%Y-%m-%d %H:%M"),
        max_hmax_station = max_hmax_row$station_id,
        max_signif = round(max_signif_row$wave_height, 1),
        max_signif_date = format(max_signif_row$time, "%Y-%m-%d %H:%M"),
        max_signif_station = max_signif_row$station_id
      )
    }
  ),

  # Sampled hourly data for dygraphs (sample if >200k rows)
  targets::tar_target(
    dash_vignette_hourly,
    {
      data <- dashboard_buoy_data
      set.seed(42)
      if (nrow(data) > 200000) {
        data[sample(nrow(data), 200000), ]
      } else {
        data
      }
    }
  ),

  # Per-station statistics tables
  targets::tar_target(
    dash_vignette_stats,
    {
      data <- dashboard_buoy_data

      max_wave_dates <- data |>
        dplyr::group_by(.data$station_id) |>
        dplyr::filter(.data$hmax == max(.data$hmax, na.rm = TRUE)) |>
        dplyr::slice(1) |>
        dplyr::select("station_id", max_wave_time = "time") |>
        dplyr::ungroup()

      hmax_stats <- data |>
        dplyr::group_by(Station = .data$station_id) |>
        dplyr::summarise(
          `Records (hourly)` = format(dplyr::n(), big.mark = ","),
          `Max Wave (m)` = round(max(.data$hmax, na.rm = TRUE), 2),
          `Avg Max Wave (m)` = round(mean(.data$hmax, na.rm = TRUE), 2),
          `Max Signif (m)` = round(max(.data$wave_height, na.rm = TRUE), 2),
          `Avg Ratio` = round(mean(.data$hmax / .data$wave_height, na.rm = TRUE), 2),
          .groups = "drop"
        ) |>
        dplyr::left_join(max_wave_dates, by = c("Station" = "station_id")) |>
        dplyr::mutate(`Max Wave Date` = format(.data$max_wave_time, "%Y-%m-%d %H:%M")) |>
        dplyr::select("Station", "Records (hourly)", "Max Wave Date",
                       "Max Wave (m)", "Avg Max Wave (m)", "Max Signif (m)", "Avg Ratio") |>
        dplyr::arrange(dplyr::desc(`Max Wave (m)`))

      max_signif_dates <- data |>
        dplyr::group_by(.data$station_id) |>
        dplyr::filter(.data$wave_height == max(.data$wave_height, na.rm = TRUE)) |>
        dplyr::slice(1) |>
        dplyr::select("station_id", max_signif_time = "time") |>
        dplyr::ungroup()

      wave_stats <- data |>
        dplyr::group_by(Station = .data$station_id) |>
        dplyr::summarise(
          `Records (hourly)` = format(dplyr::n(), big.mark = ","),
          `Max Wave (m)` = round(max(.data$hmax, na.rm = TRUE), 2),
          `Max Signif (m)` = round(max(.data$wave_height, na.rm = TRUE), 2),
          `Avg Signif (m)` = round(mean(.data$wave_height, na.rm = TRUE), 2),
          .groups = "drop"
        ) |>
        dplyr::left_join(max_signif_dates, by = c("Station" = "station_id")) |>
        dplyr::mutate(`Max Signif Date` = format(.data$max_signif_time, "%Y-%m-%d %H:%M")) |>
        dplyr::select("Station", "Records (hourly)", "Max Signif Date",
                       "Max Wave (m)", "Max Signif (m)", "Avg Signif (m)") |>
        dplyr::arrange(dplyr::desc(`Max Signif (m)`))

      wind_stats <- data |>
        dplyr::group_by(Station = .data$station_id) |>
        dplyr::summarise(
          `Records (hourly)` = dplyr::n(),
          `Avg Wind (kn)` = round(mean(.data$wind_speed, na.rm = TRUE), 1),
          `Max Wind (kn)` = round(max(.data$wind_speed, na.rm = TRUE), 1),
          `Max Gust (kn)` = round(max(.data$gust, na.rm = TRUE), 1),
          `Gust Factor` = round(
            max(.data$gust, na.rm = TRUE) / max(.data$wind_speed, na.rm = TRUE), 2
          ),
          .groups = "drop"
        ) |>
        dplyr::arrange(dplyr::desc(`Max Gust (kn)`))

      list(
        hmax_stats = hmax_stats,
        wave_stats = wave_stats,
        wind_stats = wind_stats
      )
    }
  ),

  # Top-5000 data tables for display
  targets::tar_target(
    dash_vignette_data_tables,
    {
      data <- dashboard_buoy_data

      hmax_data <- data |>
        dplyr::select("time", "station_id", "hmax", "wave_height") |>
        dplyr::mutate(ratio = round(.data$hmax / .data$wave_height, 2)) |>
        dplyr::arrange(dplyr::desc(.data$hmax)) |>
        utils::head(5000) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          `Max Wave (m)` = round(.data$hmax, 2),
          `Signif Wave (m)` = round(.data$wave_height, 2),
          Ratio = .data$ratio
        ) |>
        dplyr::select("Time (UTC)", Station = "station_id",
                       "Max Wave (m)", "Signif Wave (m)", "Ratio")

      wave_data <- data |>
        dplyr::select("time", "station_id", "wave_height", "hmax", "wave_period") |>
        dplyr::arrange(dplyr::desc(.data$wave_height)) |>
        utils::head(5000) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          `Signif Wave (m)` = round(.data$wave_height, 2),
          `Max Wave (m)` = round(.data$hmax, 2),
          `Wave Period (s)` = round(.data$wave_period, 1)
        ) |>
        dplyr::select("Time (UTC)", Station = "station_id",
                       "Signif Wave (m)", "Max Wave (m)", "Wave Period (s)")

      wind_data <- data |>
        dplyr::select("time", "station_id", "wind_speed", "gust",
                       "atmospheric_pressure") |>
        dplyr::arrange(dplyr::desc(.data$gust)) |>
        utils::head(5000) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          `Wind Speed (kn)` = round(.data$wind_speed, 1),
          `Gust (kn)` = round(.data$gust, 1),
          `Pressure (hPa)` = round(.data$atmospheric_pressure, 1)
        ) |>
        dplyr::select("Time (UTC)", Station = "station_id",
                       "Wind Speed (kn)", "Gust (kn)", "Pressure (hPa)")

      scatter_data <- data |>
        dplyr::select("time", "station_id", "wind_speed", "wave_height", "hmax") |>
        dplyr::filter(!is.na(.data$wind_speed), !is.na(.data$wave_height)) |>
        dplyr::arrange(dplyr::desc(.data$wave_height)) |>
        utils::head(5000) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          `Wind Speed (kn)` = round(.data$wind_speed, 1),
          `Signif Wave (m)` = round(.data$wave_height, 2),
          `Max Wave (m)` = round(.data$hmax, 2)
        ) |>
        dplyr::select("Time (UTC)", Station = "station_id",
                       "Wind Speed (kn)", "Signif Wave (m)", "Max Wave (m)")

      list(
        hmax_data = hmax_data,
        wave_data = wave_data,
        wind_data = wind_data,
        scatter_data = scatter_data
      )
    }
  ),

  # Regression statistics for wind vs wave scatter
  targets::tar_target(
    dash_vignette_reg_stats,
    {
      data <- dashboard_buoy_data |>
        dplyr::filter(!is.na(.data$wind_speed), !is.na(.data$wave_height))

      data |>
        dplyr::group_by(Station = .data$station_id) |>
        dplyr::summarise(
          Records = dplyr::n(),
          Correlation = round(cor(.data$wind_speed, .data$wave_height), 2),
          Intercept = round(stats::coef(stats::lm(wave_height ~ wind_speed))[1], 2),
          Slope = round(stats::coef(stats::lm(wave_height ~ wind_speed))[2], 2),
          .groups = "drop"
        ) |>
        dplyr::arrange(dplyr::desc(.data$Slope))
    }
  ),

  # Scatter plot data (wind >20kn, sampled for plotly)
  targets::tar_target(
    dash_vignette_scatter_data,
    {
      data <- dashboard_buoy_data |>
        dplyr::filter(
          !is.na(.data$wind_speed), !is.na(.data$wave_height),
          .data$wind_speed > 20
        )
      n_strong_wind <- nrow(data)
      set.seed(42)
      if (nrow(data) > 15000) {
        data <- data[sample(nrow(data), 15000), ]
      }
      list(
        data = data,
        n_strong_wind = n_strong_wind
      )
    }
  ),

  # Rogue event tables
  targets::tar_target(
    dash_vignette_rogue,
    {
      data <- dashboard_buoy_data

      # Rogue merged: storm conditions with rogue waves or gusts
      rogue_merged <- data |>
        dplyr::filter(
          !is.na(.data$hmax), !is.na(.data$wave_height), .data$wave_height > 2,
          !is.na(.data$gust), !is.na(.data$wind_speed), .data$wind_speed > 20
        ) |>
        dplyr::mutate(
          wave_ratio = .data$hmax / .data$wave_height,
          gust_ratio = .data$gust / .data$wind_speed
        ) |>
        dplyr::filter(.data$wave_ratio > 2.0 | .data$gust_ratio > 1.8) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          Station = .data$station_id,
          `Max Wave (m)` = round(.data$hmax, 2),
          `Signif Wave (m)` = round(.data$wave_height, 2),
          `Wave Ratio` = round(.data$wave_ratio, 2),
          `Rogue Wave?` = ifelse(.data$wave_ratio > 2.0, "Yes", "No"),
          `Gust (kn)` = round(.data$gust, 1),
          `Wind (kn)` = round(.data$wind_speed, 1),
          `Gust Ratio` = round(.data$gust_ratio, 2),
          `Rogue Wind?` = ifelse(.data$gust_ratio > 1.8, "Yes", "No")
        ) |>
        dplyr::arrange(dplyr::desc(.data$`Wave Ratio`), dplyr::desc(.data$`Gust Ratio`)) |>
        dplyr::select(
          "Time (UTC)", "Station", "Max Wave (m)", "Signif Wave (m)",
          "Wave Ratio", "Rogue Wave?", "Gust (kn)", "Wind (kn)",
          "Gust Ratio", "Rogue Wind?"
        )

      # Rogue waves (ratio > 2.0)
      rogue_waves <- data |>
        dplyr::filter(
          !is.na(.data$hmax), !is.na(.data$wave_height), .data$wave_height > 0
        ) |>
        dplyr::mutate(ratio = .data$hmax / .data$wave_height) |>
        dplyr::filter(.data$ratio > 2.0) |>
        dplyr::arrange(dplyr::desc(.data$ratio)) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          Station = .data$station_id,
          `Max Wave (m)` = round(.data$hmax, 2),
          `Signif Wave (m)` = round(.data$wave_height, 2),
          Ratio = round(.data$ratio, 2),
          `Wind (kn)` = round(.data$wind_speed, 1),
          `Gust (kn)` = round(.data$gust, 1)
        ) |>
        dplyr::select(
          "Time (UTC)", "Station", "Max Wave (m)", "Signif Wave (m)",
          "Ratio", "Wind (kn)", "Gust (kn)"
        )

      # Extreme gusts (top 1%)
      gust_threshold <- stats::quantile(data$gust, 0.99, na.rm = TRUE)
      extreme_gusts <- data |>
        dplyr::filter(!is.na(.data$gust), .data$gust >= gust_threshold) |>
        dplyr::arrange(dplyr::desc(.data$gust)) |>
        dplyr::mutate(
          `Time (UTC)` = format(.data$time, "%Y-%m-%d %H:%M"),
          Station = .data$station_id,
          `Gust (kn)` = round(.data$gust, 1),
          `Wind (kn)` = round(.data$wind_speed, 1),
          `Gust Factor` = round(.data$gust / .data$wind_speed, 2),
          `Max Wave (m)` = round(.data$hmax, 2),
          `Pressure (hPa)` = round(.data$atmospheric_pressure, 1)
        ) |>
        dplyr::select(
          "Time (UTC)", "Station", "Gust (kn)", "Wind (kn)",
          "Gust Factor", "Max Wave (m)", "Pressure (hPa)"
        )

      list(
        rogue_merged = rogue_merged,
        rogue_waves = rogue_waves,
        extreme_gusts = extreme_gusts,
        gust_threshold = round(gust_threshold, 1)
      )
    }
  ),

  # Return level tables (wide format for display)
  targets::tar_target(
    dash_vignette_rl,
    {
      rl <- dashboard_return_levels
      if (is.null(rl)) return(NULL)

      make_rl_wide <- function(period) {
        rl |>
          dplyr::filter(
            .data$return_period == period, !is.na(.data$return_level)
          ) |>
          dplyr::mutate(return_level = round(.data$return_level, 2)) |>
          dplyr::select("station", "variable_label", "return_level") |>
          tidyr::pivot_wider(
            names_from = "variable_label", values_from = "return_level"
          )
      }

      rl_all_wide <- rl |>
        dplyr::filter(!is.na(.data$return_level)) |>
        dplyr::mutate(
          col_name = paste0(.data$variable_label, " ", .data$return_period, "yr"),
          return_level = round(.data$return_level, 2)
        ) |>
        dplyr::select("station", "col_name", "return_level") |>
        tidyr::pivot_wider(names_from = "col_name", values_from = "return_level")

      list(
        rl_1yr = make_rl_wide(1),
        rl_5yr = make_rl_wide(5),
        rl_10yr = make_rl_wide(10),
        rl_all = rl_all_wide
      )
    }
  )
)
