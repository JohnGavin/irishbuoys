#!/usr/bin/env Rscript
#' Example Usage of irishbuoys Package
#'
#' This script demonstrates the main functionality of the irishbuoys package

# Load package
library(irishbuoys)
library(dplyr)
library(ggplot2)

cli::cli_h1("Irish Buoys Package - Example Usage")

# 1. Get available stations
cli::cli_h2("Available Stations")
stations <- get_stations()
print(stations)

# 2. Download recent data
cli::cli_h2("Downloading Recent Data")
recent_data <- download_buoy_data(
  start_date = Sys.Date() - 7,
  end_date = Sys.Date()
)
cli::cli_alert_info("Downloaded {nrow(recent_data)} records")

# 3. Initialize database (only run once)
cli::cli_h2("Database Operations")
if (!file.exists("inst/extdata/irish_buoys.duckdb")) {
  cli::cli_alert_info("Initializing database with 30 days of data...")
  initialize_database(
    start_date = Sys.Date() - 30,
    end_date = Sys.Date()
  )
} else {
  cli::cli_alert_info("Database already exists")
}

# 4. Connect and query database
con <- connect_duckdb()

# Get wave statistics by station
cli::cli_h2("Wave Statistics by Station")
wave_stats <- query_buoy_data(
  con,
  sql_query = "
    SELECT
      station_id,
      AVG(wave_height) as avg_wave_height,
      MAX(wave_height) as max_wave_height,
      AVG(wave_period) as avg_wave_period
    FROM buoy_data
    WHERE qc_flag = 1
      AND time >= CURRENT_DATE - INTERVAL '7 days'
    GROUP BY station_id
    ORDER BY station_id
  "
)
print(wave_stats)

# 5. Check for rogue waves
cli::cli_h2("Rogue Wave Detection")
rogue_waves <- query_buoy_data(
  con,
  sql_query = "
    SELECT
      station_id,
      time,
      wave_height,
      hmax,
      ROUND(hmax / NULLIF(wave_height, 0), 2) as height_ratio
    FROM buoy_data
    WHERE hmax > 2 * wave_height
      AND wave_height > 2
      AND qc_flag = 1
      AND time >= CURRENT_DATE - INTERVAL '30 days'
    ORDER BY height_ratio DESC
    LIMIT 10
  "
)

if (nrow(rogue_waves) > 0) {
  cli::cli_alert_warning("Found {nrow(rogue_waves)} potential rogue waves")
  print(rogue_waves)
} else {
  cli::cli_alert_success("No rogue waves detected")
}

# 6. Plot recent wave heights
cli::cli_h2("Visualization Example")
plot_data <- query_buoy_data(
  con,
  stations = "M3",
  variables = c("time", "wave_height", "wind_speed"),
  start_date = Sys.Date() - 7,
  qc_filter = TRUE
)

if (nrow(plot_data) > 0) {
  p <- ggplot(plot_data, aes(x = time)) +
    geom_line(aes(y = wave_height), color = "blue", size = 1) +
    geom_line(aes(y = wind_speed/10), color = "red", size = 1, alpha = 0.7) +
    scale_y_continuous(
      name = "Wave Height (m)",
      sec.axis = sec_axis(~.*10, name = "Wind Speed (knots)")
    ) +
    labs(
      title = "M3 Buoy - Wave Height and Wind Speed",
      subtitle = paste("Last 7 days from", min(plot_data$time), "to", max(plot_data$time)),
      x = "Time"
    ) +
    theme_minimal() +
    theme(
      axis.text.y.left = element_text(color = "blue"),
      axis.text.y.right = element_text(color = "red"),
      axis.title.y.left = element_text(color = "blue"),
      axis.title.y.right = element_text(color = "red")
    )

  # Save plot
  ggsave("wave_wind_plot.png", p, width = 10, height = 6, dpi = 150)
  cli::cli_alert_success("Plot saved as wave_wind_plot.png")
}

# 7. Generate weekly summary
cli::cli_h2("Weekly Summary")
summary <- generate_weekly_summary()

cli::cli_alert_info("Summary generated for {length(unique(summary$current_week$station_id))} stations")
cli::cli_alert_info("Period: {summary$period$start} to {summary$period$end}")

if (nrow(summary$extreme_events) > 0) {
  cli::cli_alert_warning("Detected {nrow(summary$extreme_events)} extreme events")
}

# 8. Get data dictionary
cli::cli_h2("Data Dictionary")
dict <- get_data_dictionary()
cli::cli_alert_info("Data dictionary contains {nrow(dict)} variables")

# Show oceanographic variables
ocean_vars <- dict[dict$category == "oceanographic", c("variable", "units", "description")]
cli::cli_alert_info("Oceanographic variables:")
print(ocean_vars)

# 9. Database statistics
cli::cli_h2("Database Statistics")
stats <- get_database_stats()

# Disconnect from database
DBI::dbDisconnect(con)

cli::cli_alert_success("Example script completed successfully!")