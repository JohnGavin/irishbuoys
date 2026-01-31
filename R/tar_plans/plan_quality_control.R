#' Targets Plan: Quality Control and Data Validation
#'
#' This plan performs quality checks and validation on the buoy data

plan_quality_control <- list(
  # Check data completeness
  targets::tar_target(
    data_completeness,
    {
      con <- irishbuoys::connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      DBI::dbGetQuery(con, "
        SELECT
          station_id,
          DATE(time) as date,
          COUNT(*) as n_records,
          COUNT(DISTINCT EXTRACT(HOUR FROM time)) as n_hours,
          AVG(CASE WHEN qc_flag = 1 THEN 1 ELSE 0 END) as pct_good
        FROM buoy_data
        WHERE time >= CURRENT_DATE - INTERVAL '30 days'
        GROUP BY station_id, DATE(time)
        ORDER BY station_id, date DESC
      ")
    }
  ),

  # Identify potential outliers
  targets::tar_target(
    outlier_check,
    {
      con <- irishbuoys::connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      # Check for extreme values
      DBI::dbGetQuery(con, "
        SELECT
          station_id,
          time,
          'wave_height' as variable,
          wave_height as value
        FROM buoy_data
        WHERE wave_height > 15
          AND qc_flag = 1

        UNION ALL

        SELECT
          station_id,
          time,
          'wind_speed' as variable,
          wind_speed as value
        FROM buoy_data
        WHERE wind_speed > 60
          AND qc_flag = 1

        UNION ALL

        SELECT
          station_id,
          time,
          'hmax' as variable,
          hmax as value
        FROM buoy_data
        WHERE hmax > 25
          AND qc_flag = 1

        ORDER BY time DESC
        LIMIT 100
      ")
    }
  ),

  # Check for rogue waves
  targets::tar_target(
    rogue_waves,
    {
      con <- irishbuoys::connect_duckdb()
      on.exit(DBI::dbDisconnect(con))

      DBI::dbGetQuery(con, "
        SELECT
          station_id,
          time,
          wave_height,
          hmax,
          hmax / NULLIF(wave_height, 0) as height_ratio
        FROM buoy_data
        WHERE hmax > 2 * wave_height
          AND wave_height > 0
          AND qc_flag = 1
        ORDER BY time DESC
        LIMIT 100
      ")
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