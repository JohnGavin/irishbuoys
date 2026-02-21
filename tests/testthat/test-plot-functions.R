# Tests for R/plot_functions.R
# All plot functions are pure: data frame in, plotly/ggplot out

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

# --- NULL guard tests ---

test_that("create_plot_rogue_all returns NULL for NULL input", {
  expect_null(create_plot_rogue_all(NULL))
})

test_that("create_plot_rogue_all returns NULL for empty data", {
  d <- make_rogue_events(0)
  expect_null(create_plot_rogue_all(d[0, ]))
})

test_that("create_plot_rogue_by_station returns NULL for NULL", {
  expect_null(create_plot_rogue_by_station(NULL))
})

test_that("create_plot_wind_beaufort returns NULL for NULL", {
  expect_null(create_plot_wind_beaufort(NULL))
})

test_that("create_plot_wind_beaufort returns NULL for missing wind_speed", {
  d <- data.frame(time = Sys.time(), rogue_ratio = 2.1)
  expect_null(create_plot_wind_beaufort(d))
})

test_that("create_plot_week_of_year returns NULL for NULL", {
  expect_null(create_plot_week_of_year(NULL))
})

test_that("create_plot_time_of_day returns NULL for NULL", {
  expect_null(create_plot_time_of_day(NULL))
})

test_that("create_plot_time_of_day returns NULL for missing time_of_day", {
  d <- data.frame(time = Sys.time(), rogue_ratio = 2.1)
  expect_null(create_plot_time_of_day(d))
})

test_that("create_plot_monthly_wave returns NULL for NULL", {
  expect_null(create_plot_monthly_wave(NULL))
})

test_that("create_plot_monthly_wave returns NULL for missing monthly key", {
  expect_null(create_plot_monthly_wave(list(other = 1)))
})

test_that("create_plot_monthly_wind returns NULL for NULL", {
  expect_null(create_plot_monthly_wind(NULL))
})

test_that("create_plot_annual_trends returns NULL for NULL", {
  expect_null(create_plot_annual_trends(NULL))
})

test_that("create_plot_annual_trends returns NULL for missing key", {
  expect_null(create_plot_annual_trends(list(other = 1)))
})

test_that("create_plot_return_levels returns NULL for NULL", {
  expect_null(create_plot_return_levels(NULL))
})

test_that("create_plot_gust_by_category returns NULL for NULL", {
  expect_null(create_plot_gust_by_category(NULL))
})

test_that("create_plot_gust_by_category returns NULL for empty list", {
  expect_null(create_plot_gust_by_category(list()))
})

test_that("create_plot_rogue_gusts returns NULL for NULL", {
  expect_null(create_plot_rogue_gusts(NULL))
})

test_that("create_plot_rogue_gusts returns NULL for missing by_station", {
  expect_null(create_plot_rogue_gusts(list(other = 1)))
})

test_that("create_plot_stl returns NULL for NULL", {
  expect_null(create_plot_stl(NULL))
})

test_that("create_plot_stl returns NULL for missing components", {
  expect_null(create_plot_stl(list(other = 1)))
})

test_that("create_plot_rogue_gusts_all returns NULL for NULL", {
  expect_null(create_plot_rogue_gusts_all(NULL))
})

test_that("create_plot_rogue_gusts_by_station returns NULL for NULL", {
  expect_null(create_plot_rogue_gusts_by_station(NULL))
})

test_that("create_plot_gusts_vs_waves returns NULL for NULL", {
  expect_null(create_plot_gusts_vs_waves(NULL))
})

# --- Positive tests: functions return correct plot objects ---

test_that("create_plot_rogue_all returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_rogue_all(make_rogue_events())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_rogue_by_station returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_rogue_by_station(make_rogue_events())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_rogue_by_station accepts date_caption", {
  skip_if_not_installed("plotly")
  result <- create_plot_rogue_by_station(make_rogue_events(), date_caption = "2024")
  expect_s3_class(result, "plotly")
})

test_that("create_plot_wind_beaufort returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_wind_beaufort(make_rogue_conditions())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_week_of_year returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_week_of_year(make_rogue_conditions())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_time_of_day returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_time_of_day(make_rogue_conditions())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_monthly_wave returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_monthly_wave(make_seasonal_means())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_monthly_wind returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_monthly_wind(make_seasonal_means())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_annual_trends returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_annual_trends(make_annual_trends())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_return_levels returns plotly for wave", {
  skip_if_not_installed("plotly")
  result <- create_plot_return_levels(make_return_levels(), variable = "wave")
  expect_s3_class(result, "plotly")
})

test_that("create_plot_return_levels returns plotly for wind", {
  skip_if_not_installed("plotly")
  result <- create_plot_return_levels(make_return_levels(), variable = "wind")
  expect_s3_class(result, "plotly")
})

test_that("create_plot_return_levels returns plotly for hmax", {
  skip_if_not_installed("plotly")
  result <- create_plot_return_levels(make_return_levels(), variable = "hmax")
  expect_s3_class(result, "plotly")
})

test_that("create_plot_gust_by_category with station data returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_gust_by_category(make_gust_analysis(with_station = TRUE))
  expect_s3_class(result, "plotly")
})

test_that("create_plot_gust_by_category without station data returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_gust_by_category(make_gust_analysis(with_station = FALSE))
  expect_s3_class(result, "plotly")
})

test_that("create_plot_rogue_gusts returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_rogue_gusts(make_gust_analysis())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_stl returns ggplot", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("tidyr")
  result <- create_plot_stl(make_wave_stl())
  expect_s3_class(result, "gg")
})

test_that("create_plot_stl accepts date_caption", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("tidyr")
  result <- create_plot_stl(make_wave_stl(), date_caption = "2024")
  expect_s3_class(result, "gg")
})

test_that("create_plot_rogue_gusts_all returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_rogue_gusts_all(make_rogue_gust_events())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_rogue_gusts_by_station returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_rogue_gusts_by_station(make_rogue_gust_events())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_gusts_vs_waves returns plotly", {
  skip_if_not_installed("plotly")
  result <- create_plot_gusts_vs_waves(make_analysis_data())
  expect_s3_class(result, "plotly")
})

test_that("create_plot_gusts_vs_waves returns NULL when no extreme events", {
  skip_if_not_installed("plotly")
  # Data with all normal ratios
  d <- data.frame(
    time = as.POSIXct("2024-01-01") + 1:10 * 3600,
    station_id = rep("M2", 10),
    gust = rep(10, 10),
    wind_speed = rep(10, 10),
    hmax = rep(2, 10),
    wave_height = rep(2, 10)
  )
  result <- create_plot_gusts_vs_waves(d)
  expect_null(result)
})
