#!/usr/bin/env Rscript
#' Storage Format Comparison for Irish Buoys Data
#'
#' This script demonstrates the storage efficiency of different formats
#' and helps choose the optimal solution for GitHub storage limits.

library(irishbuoys)
library(duckdb)
library(arrow)
library(dplyr)

cli::cli_h1("Storage Format Comparison")

# Download sample data (30 days)
cli::cli_h2("Downloading Sample Data")
sample_data <- download_buoy_data(
  start_date = Sys.Date() - 30,
  end_date = Sys.Date()
)

cli::cli_alert_info("Sample size: {nrow(sample_data)} rows, {ncol(sample_data)} columns")

# Prepare test directory
test_dir <- tempdir()
cli::cli_alert_info("Using temp directory: {test_dir}")

# 1. CSV Format
cli::cli_h2("CSV Format")
csv_file <- file.path(test_dir, "buoys.csv")
write.csv(sample_data, csv_file, row.names = FALSE)
csv_size <- file.info(csv_file)$size / 1024^2
cli::cli_alert_info("CSV size: {round(csv_size, 2)} MB")

# 2. Native DuckDB
cli::cli_h2("DuckDB Native Format")
duckdb_file <- file.path(test_dir, "buoys.duckdb")
con <- dbConnect(duckdb::duckdb(), dbdir = duckdb_file)
dbWriteTable(con, "buoy_data", sample_data, overwrite = TRUE)
dbDisconnect(con)
duckdb_size <- file.info(duckdb_file)$size / 1024^2
cli::cli_alert_info("DuckDB size: {round(duckdb_size, 2)} MB")
cli::cli_alert_info("Compression vs CSV: {round(csv_size/duckdb_size, 1)}:1")

# 3. Parquet (Snappy - default)
cli::cli_h2("Parquet with Snappy Compression")
parquet_snappy <- file.path(test_dir, "buoys_snappy.parquet")
write_parquet(sample_data, parquet_snappy, compression = "snappy")
snappy_size <- file.info(parquet_snappy)$size / 1024^2
cli::cli_alert_info("Parquet (snappy) size: {round(snappy_size, 2)} MB")
cli::cli_alert_info("Compression vs CSV: {round(csv_size/snappy_size, 1)}:1")

# 4. Parquet (Gzip)
cli::cli_h2("Parquet with Gzip Compression")
parquet_gzip <- file.path(test_dir, "buoys_gzip.parquet")
write_parquet(sample_data, parquet_gzip, compression = "gzip", compression_level = 9)
gzip_size <- file.info(parquet_gzip)$size / 1024^2
cli::cli_alert_info("Parquet (gzip) size: {round(gzip_size, 2)} MB")
cli::cli_alert_info("Compression vs CSV: {round(csv_size/gzip_size, 1)}:1")

# 5. Parquet (Zstd)
cli::cli_h2("Parquet with Zstd Compression")
parquet_zstd <- file.path(test_dir, "buoys_zstd.parquet")
write_parquet(sample_data, parquet_zstd, compression = "zstd", compression_level = 22)
zstd_size <- file.info(parquet_zstd)$size / 1024^2
cli::cli_alert_info("Parquet (zstd) size: {round(zstd_size, 2)} MB")
cli::cli_alert_info("Compression vs CSV: {round(csv_size/zstd_size, 1)}:1")

# 6. Partitioned Parquet
cli::cli_h2("Partitioned Parquet (by year/month)")
sample_data$year <- lubridate::year(sample_data$time)
sample_data$month <- lubridate::month(sample_data$time)
partitioned_dir <- file.path(test_dir, "partitioned")
write_dataset(
  sample_data,
  partitioned_dir,
  format = "parquet",
  partitioning = c("year", "month"),
  parquet_options = ParquetWriteOptions$create(compression = "zstd", compression_level = 22)
)
parquet_files <- list.files(partitioned_dir, pattern = "\\.parquet$", recursive = TRUE, full.names = TRUE)
partitioned_size <- sum(file.info(parquet_files)$size) / 1024^2
cli::cli_alert_info("Partitioned Parquet size: {round(partitioned_size, 2)} MB across {length(parquet_files)} files")
cli::cli_alert_info("Compression vs CSV: {round(csv_size/partitioned_size, 1)}:1")

# Create comparison table
cli::cli_h2("Storage Comparison Summary")

comparison <- data.frame(
  Format = c("CSV", "DuckDB", "Parquet (snappy)", "Parquet (gzip)",
             "Parquet (zstd)", "Partitioned Parquet"),
  Size_MB = round(c(csv_size, duckdb_size, snappy_size, gzip_size,
                    zstd_size, partitioned_size), 2),
  Compression_Ratio = round(csv_size / c(csv_size, duckdb_size, snappy_size,
                                          gzip_size, zstd_size, partitioned_size), 1),
  Percent_of_CSV = round(100 * c(csv_size, duckdb_size, snappy_size, gzip_size,
                                  zstd_size, partitioned_size) / csv_size, 1)
)

print(comparison)

# Query performance test
cli::cli_h2("Query Performance Comparison")

# Test query: aggregate statistics
test_query <- "
  SELECT
    station_id,
    AVG(wave_height) as avg_wave,
    MAX(wave_height) as max_wave,
    COUNT(*) as n
  FROM buoy_data
  WHERE wave_height > 2
  GROUP BY station_id
"

# DuckDB native
con <- dbConnect(duckdb::duckdb(), dbdir = duckdb_file)
t1 <- system.time({
  result_db <- dbGetQuery(con, test_query)
})
dbDisconnect(con)
cli::cli_alert_info("DuckDB query time: {round(t1['elapsed'], 3)} seconds")

# DuckDB on Parquet
con <- dbConnect(duckdb::duckdb())
t2 <- system.time({
  dbExecute(con, glue::glue("CREATE VIEW buoy_data AS SELECT * FROM '{parquet_zstd}'"))
  result_parquet <- dbGetQuery(con, test_query)
})
dbDisconnect(con)
cli::cli_alert_info("DuckDB + Parquet query time: {round(t2['elapsed'], 3)} seconds")

# Projection for full dataset (22 years)
cli::cli_h2("Full Dataset Size Projection")

# Estimate based on sample
days_in_sample <- as.numeric(diff(range(sample_data$time, na.rm = TRUE)))
rows_per_day <- nrow(sample_data) / days_in_sample
years_of_data <- 22
projected_rows <- rows_per_day * 365 * years_of_data

cli::cli_alert_info("Sample period: {round(days_in_sample, 1)} days")
cli::cli_alert_info("Rows per day: {round(rows_per_day, 0)}")
cli::cli_alert_info("Projected rows for {years_of_data} years: {format(round(projected_rows, 0), big.mark = ',')}")

# Size projections
scale_factor <- projected_rows / nrow(sample_data)
projected_sizes <- data.frame(
  Format = comparison$Format,
  Current_MB = comparison$Size_MB,
  Projected_MB = round(comparison$Size_MB * scale_factor, 0),
  GitHub_Compatible = ifelse(comparison$Size_MB * scale_factor < 100, "✅", "❌")
)

print(projected_sizes)

# Recommendations
cli::cli_h2("📊 Recommendations")

best_format <- comparison$Format[which.min(comparison$Size_MB)]
best_size <- min(comparison$Size_MB)
best_ratio <- max(comparison$Compression_Ratio)

cli::cli_alert_success("Best compression: {best_format} ({best_size} MB, {best_ratio}:1 ratio)")

if (min(projected_sizes$Projected_MB) < 100) {
  cli::cli_alert_success("✅ Projected size fits within GitHub's 100 MB limit")
  suitable <- projected_sizes[projected_sizes$Projected_MB < 100, ]
  cli::cli_alert_info("Suitable formats: {paste(suitable$Format, collapse = ', ')}")
} else {
  cli::cli_alert_warning("⚠️ Full dataset may exceed GitHub's 100 MB limit")
  cli::cli_alert_info("Consider: 1) Git LFS, 2) External storage, 3) Keep only recent data")
}

# Architecture recommendation
cli::cli_h2("Recommended Architecture")
cli::cli_text("
1. Use Parquet with zstd compression for raw data storage
2. Partition by year/month for efficient updates
3. Use DuckDB as query engine (reads Parquet directly)
4. Keep only metadata in DuckDB database (<1 MB)
5. For GitHub: Store last 2-3 years in repo, archive older data externally

Benefits:
- 5-10x compression vs CSV
- Direct querying without import
- Efficient incremental updates
- GitHub-friendly file sizes
- Column pruning for fast queries
")

# Clean up
cli::cli_alert_info("Cleaning up temporary files...")
unlink(test_dir, recursive = TRUE)