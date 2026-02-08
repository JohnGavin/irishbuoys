# earliest dates snapshot - historical data preserved

    Code
      earliest_df
    Output
        station_id       earliest_date
      1         M2 2025-11-27 12:00:00
      2         M3          2025-11-01
      3         M4          2025-11-01
      4         M5          2025-11-01
      5         M6          2025-11-01

# data structure snapshot - columns remain consistent

    Code
      column_info
    Output
                       column
      1       air_temperature
      2  atmospheric_pressure
      3                  gust
      4                  hmax
      5              latitude
      6             longitude
      7   mean_wave_direction
      8               qc_flag
      9       sea_temperature
      10           station_id
      11                 time
      12          wave_height
      13          wave_period
      14       wind_direction
      15           wind_speed

# station list snapshot - stations not lost

    Code
      station_counts
    Output
        station_id n_records
      1         M2      1594
      2         M3      2155
      3         M4      2155
      4         M5      2155
      5         M6      2156

# data date range - should span multiple years

    Code
      date_summary
    Output
           metric               value
      1  earliest          2025-11-01
      2    latest 2026-02-01 21:00:00
      3 days_span                92.9

