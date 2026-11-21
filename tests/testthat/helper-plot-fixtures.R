# --- Synthetic data helpers ---

make_rogue_events <- function(n = 10) {
  data.frame(
    time = as.POSIXct("2024-01-01") + seq_len(n) * 3600,
    station_id = rep(c("M2", "M3"), length.out = n),
    rogue_ratio = runif(n, 2.0, 3.0),
    hmax = runif(n, 5, 15),
    wave_height = runif(n, 2, 5),
    wind_speed = runif(n, 5, 25),
    gust = runif(n, 8, 40),
    stringsAsFactors = FALSE
  )
}

make_rogue_conditions <- function(n = 20) {
  d <- make_rogue_events(n)
  d$time_of_day <- rep(c("Morning", "Afternoon", "Evening", "Night"), length.out = n)
  d
}

make_seasonal_means <- function() {
  list(
    monthly = data.frame(
      month_name = month.abb,
      mean = runif(12, 1, 4),
      sd = runif(12, 0.3, 1),
      stringsAsFactors = FALSE
    )
  )
}

make_annual_trends <- function() {
  list(
    annual_stats = data.frame(
      year = 2019:2024,
      mean = runif(6, 1.5, 3.5),
      sd = runif(6, 0.3, 0.8),
      stringsAsFactors = FALSE
    )
  )
}

make_return_levels <- function() {
  data.frame(
    return_period = c(2, 5, 10, 25, 50, 100),
    return_level = c(5, 7, 8.5, 10, 11.5, 13),
    lower = c(4, 5.5, 7, 8, 9.5, 10.5),
    upper = c(6, 8.5, 10, 12, 13.5, 15.5),
    stringsAsFactors = FALSE
  )
}

make_gust_analysis <- function(with_station = TRUE) {
  result <- list(
    rogue_gust_threshold = 1.5,
    by_category = data.frame(
      wind_category = c("0-5", "5-10", "10-15", "15+"),
      mean_gf = c(1.2, 1.3, 1.4, 1.6),
      p95_gf = c(1.5, 1.7, 1.9, 2.2),
      stringsAsFactors = FALSE
    ),
    by_station = data.frame(
      station_id = c("M2", "M3", "M4"),
      n = c(1000, 800, 600),
      n_rogue = c(15, 10, 8),
      pct_rogue = c(1.5, 1.25, 1.33),
      mean_gf = c(1.3, 1.35, 1.28),
      max_gf = c(3.1, 2.8, 2.5),
      stringsAsFactors = FALSE
    )
  )
  if (with_station) {
    result$by_station_category <- data.frame(
      station_id = rep(c("M2", "M3"), each = 3),
      wind_category = rep(c("0-5", "5-10", "10-15"), 2),
      mean_gf = runif(6, 1.1, 1.6),
      p95_gf = runif(6, 1.5, 2.2),
      n = sample(50:200, 6),
      stringsAsFactors = FALSE
    )
  }
  result
}

make_wave_stl <- function() {
  n <- 100
  list(
    components = data.frame(
      time = as.POSIXct("2024-01-01") + seq_len(n) * 86400,
      original = rnorm(n, 2, 0.5),
      seasonal = sin(seq_len(n) / 10),
      trend = seq_len(n) / 100,
      remainder = rnorm(n, 0, 0.1)
    )
  )
}

make_rogue_gust_events <- function(n = 10) {
  data.frame(
    time = as.POSIXct("2024-01-01") + seq_len(n) * 3600,
    station_id = rep(c("M2", "M3"), length.out = n),
    gust_ratio = runif(n, 1.5, 3.0),
    gust = runif(n, 15, 40),
    wind_speed = runif(n, 5, 25),
    wave_height = runif(n, 2, 5),
    stringsAsFactors = FALSE
  )
}

make_analysis_data <- function(n = 50) {
  data.frame(
    time = as.POSIXct("2024-01-01") + seq_len(n) * 3600,
    station_id = rep(c("M2", "M3"), length.out = n),
    gust = c(runif(n / 2, 15, 40), runif(n / 2, 5, 10)),
    wind_speed = runif(n, 5, 20),
    hmax = c(runif(n / 2, 6, 15), runif(n / 2, 2, 4)),
    wave_height = runif(n, 1, 5),
    stringsAsFactors = FALSE
  )
}

