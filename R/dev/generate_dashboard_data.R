# Script to regenerate dashboard data with historical range
# Run this locally to update vignettes/data/buoy_data.json

library(httr2)
library(jsonlite)
library(dplyr)

# Fetch 1 year of data (balance between history and file size)
end_date <- Sys.Date()
start_date <- end_date - 365

cat("Fetching data from", as.character(start_date), "to", as.character(end_date), "\n")

# Build ERDDAP query - include QC_Flag
base_url <- "https://erddap.marine.ie/erddap/tabledap/IWBNetwork"
variables <- c(
  "time", "station_id", "longitude", "latitude",
  "WaveHeight", "WavePeriod", "Hmax", "MeanWaveDirection",
  "WindSpeed", "WindDirection", "Gust",
  "AtmosphericPressure", "AirTemperature", "SeaTemperature",
  "QC_Flag"
)

query_url <- paste0(
  base_url, ".csv?",
  paste(variables, collapse = ","),
  "&time>=", format(start_date, "%Y-%m-%dT00:00:00Z"),
  "&time<=", format(end_date, "%Y-%m-%dT23:59:59Z")
)

cat("Downloading from ERDDAP...\n")
response <- request(query_url) |>
  req_timeout(300) |>
  req_perform()

# Parse CSV (skip units row)
csv_text <- resp_body_string(response)
csv_lines <- strsplit(csv_text, "\n")[[1]]
csv_lines <- csv_lines[-2]  # Remove units row
data <- read.csv(text = paste(csv_lines, collapse = "\n"), stringsAsFactors = FALSE)

cat("Downloaded", nrow(data), "records\n")

# Standardize column names
names(data) <- c(
  "time", "station_id", "longitude", "latitude",
  "wave_height", "wave_period", "hmax", "mean_wave_direction",
  "wind_speed", "wind_direction", "gust",
  "atmospheric_pressure", "air_temperature", "sea_temperature",
  "qc_flag"
)

# Convert types
data$time <- as.POSIXct(data$time, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")

numeric_cols <- c(
  "longitude", "latitude", "wave_height", "wave_period", "hmax",
  "mean_wave_direction", "wind_speed", "wind_direction", "gust",
  "atmospheric_pressure", "air_temperature", "sea_temperature", "qc_flag"
)
for (col in numeric_cols) {
  data[[col]] <- as.numeric(data[[col]])
}

# Format time for JSON
data$time <- format(data$time, "%Y-%m-%dT%H:%M:%SZ")

# QC summary
cat("\nQC Flag Distribution:\n")
print(table(data$qc_flag, useNA = "ifany"))

cat("\nQC by Station:\n
")
print(table(data$station_id, data$qc_flag, useNA = "ifany"))

# Write JSON
output_path <- "vignettes/data/buoy_data.json"
cat("\nWriting to", output_path, "\n")
write_json(data, output_path, pretty = FALSE)

cat("Done! File size:", round(file.size(output_path) / 1024 / 1024, 2), "MB\n")
cat("Date range:", min(data$time), "to", max(data$time), "\n")
cat("Stations:", paste(sort(unique(data$station_id)), collapse = ", "), "\n")
