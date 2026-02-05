#!/usr/bin/env Rscript
# Check data gaps and max Hmax in DuckDB
pkgload::load_all(".")
con <- connect_duckdb()

cat("=== Coverage by year-month ===\n")
coverage <- DBI::dbGetQuery(con, "
  SELECT
    strftime(time, '%Y-%m') as year_month,
    COUNT(*) as n_records,
    COUNT(DISTINCT station_id) as n_stations
  FROM buoy_data
  GROUP BY strftime(time, '%Y-%m')
  ORDER BY year_month
")
print(as.data.frame(coverage))

cat("\n=== Expected vs Actual months (2019-2026) ===\n")
all_months <- format(seq(as.Date("2019-01-01"), as.Date("2026-02-01"), by = "month"), "%Y-%m")
missing <- setdiff(all_months, coverage$year_month)
cat("Missing months:", length(missing), "\n")
if (length(missing) > 0) cat(paste(missing, collapse = ", "), "\n")

cat("\n=== Max Hmax overall ===\n")
print(DBI::dbGetQuery(con, "
  SELECT station_id, hmax, time
  FROM buoy_data
  ORDER BY hmax DESC
  LIMIT 10
"))

cat("\n=== Max Hmax by station ===\n")
print(DBI::dbGetQuery(con, "
  SELECT station_id, MAX(hmax) as max_hmax, COUNT(*) as n_records,
    MIN(time) as first_time, MAX(time) as last_time
  FROM buoy_data
  GROUP BY station_id
  ORDER BY max_hmax DESC
"))

cat("\n=== Total records ===\n")
cat("Total:", DBI::dbGetQuery(con, "SELECT COUNT(*) as n FROM buoy_data")[[1]], "\n")

DBI::dbDisconnect(con)
