#' Targets Plan: Quality Control and Data Validation
#'
#' This plan performs quality checks and validation on the buoy data
#' Uses dplyr/dbplyr patterns for tidyverse consistency

plan_quality_control <- list(
  # Check data completeness
  targets::tar_target(
    data_completeness,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      # Use dplyr/dbplyr - collect then filter and aggregate in R for portability
      cutoff_date <- as.POSIXct(Sys.Date() - 30)
      dplyr::tbl(con, "buoy_data") |>
        dplyr::collect() |>
        dplyr::filter(time >= cutoff_date) |>
        dplyr::mutate(
          date = as.Date(time),
          hour = lubridate::hour(time)
        ) |>
        dplyr::group_by(station_id, date) |>
        dplyr::summarise(
          n_records = dplyr::n(),
          n_hours = dplyr::n_distinct(hour),
          pct_good = mean(qc_flag == 1, na.rm = TRUE),
          .groups = "drop"
        ) |>
        dplyr::arrange(station_id, dplyr::desc(date))
    }
  ),

  # Identify potential outliers
  targets::tar_target(
    outlier_check,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      # Use dplyr/dbplyr - check extreme values with bind_rows instead of UNION ALL
      buoy_tbl <- dplyr::tbl(con, "buoy_data") |>
        dplyr::filter(qc_flag == 1L) |>
        dplyr::collect()

      # Wave height outliers
      wave_outliers <- buoy_tbl |>
        dplyr::filter(wave_height > 15) |>
        dplyr::transmute(station_id, time, variable = "wave_height", value = wave_height)

      # Wind speed outliers
      wind_outliers <- buoy_tbl |>
        dplyr::filter(wind_speed > 60) |>
        dplyr::transmute(station_id, time, variable = "wind_speed", value = wind_speed)

      # Hmax outliers
      hmax_outliers <- buoy_tbl |>
        dplyr::filter(hmax > 25) |>
        dplyr::transmute(station_id, time, variable = "hmax", value = hmax)

      # Combine and return top 100 most recent
      dplyr::bind_rows(wave_outliers, wind_outliers, hmax_outliers) |>
        dplyr::arrange(dplyr::desc(time)) |>
        head(100)
    }
  ),

  # Check for rogue waves
  targets::tar_target(
    rogue_waves,
    {
      con <- connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      # Use dplyr/dbplyr for rogue wave detection
      dplyr::tbl(con, "buoy_data") |>
        dplyr::filter(
          hmax > 2 * wave_height,
          wave_height > 0,
          qc_flag == 1L
        ) |>
        dplyr::collect() |>
        dplyr::mutate(
          height_ratio = hmax / wave_height
        ) |>
        dplyr::select(station_id, time, wave_height, hmax, height_ratio) |>
        dplyr::arrange(dplyr::desc(time)) |>
        head(100)
    }
  ),

  # Generate data quality report
  targets::tar_target(
    quality_report,
    {
      list(
        completeness = data_completeness,
        outliers = outlier_check,
        rogue_waves = rogue_waves,
        report_date = Sys.Date()
      )
    }
  )
)
