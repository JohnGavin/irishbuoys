# Tests for R/api_static.R
# Pure functions, no DB/network required

test_that("generate_api_index returns valid structure", {
  idx <- generate_api_index()
  expect_type(idx, "list")
  expect_equal(idx$api, "irishbuoys")
  expect_equal(idx$version, "v1")
  expect_true(grepl("^https://", idx$base_url))
  expect_true(!is.null(idx$updated_at))
  expect_type(idx$endpoints, "list")
})

test_that("generate_api_index has 12 endpoints", {
  idx <- generate_api_index()
  expect_length(idx$endpoints, 12)
})

test_that("generate_api_index includes all endpoint names", {
  idx <- generate_api_index()
  endpoint_names <- vapply(idx$endpoints, function(x) x$endpoint, character(1))
  expected <- c(
    "stations.json", "stats.json", "rogue-waves.json",
    "return-levels.json", "data-dictionary.json", "latest.json",
    "seasonal.json", "correlations.json",
    "sources.json", "status.json", "trends.json", "extremes.json"
  )
  for (ep in expected) {
    expect_true(ep %in% endpoint_names, info = paste("Missing endpoint:", ep))
  }
})

test_that("generate_api_index endpoints have url and description", {
  idx <- generate_api_index()
  for (ep in idx$endpoints) {
    expect_true("endpoint" %in% names(ep), info = "Missing 'endpoint' field")
    expect_true("url" %in% names(ep), info = "Missing 'url' field")
    expect_true("description" %in% names(ep), info = "Missing 'description' field")
    expect_true(grepl("^https://", ep$url), info = paste("Bad URL:", ep$url))
  }
})

test_that("generate_api_index accepts custom base_url", {
  idx <- generate_api_index(base_url = "https://example.com/api/v1/")
  expect_equal(idx$base_url, "https://example.com/api/v1/")
  urls <- vapply(idx$endpoints, function(x) x$url, character(1))
  expect_true(all(grepl("^https://example.com/", urls)))
})

test_that("generate_api_index accepts custom endpoints", {
  custom <- list(
    list(endpoint = "test.json", url = "https://x.com/test.json", description = "Test")
  )
  idx <- generate_api_index(endpoints = custom)
  expect_length(idx$endpoints, 1)
  expect_equal(idx$endpoints[[1]]$endpoint, "test.json")
})

test_that("generate_api_index seasonal endpoint has correct description", {
  idx <- generate_api_index()
  seasonal <- Filter(function(x) x$endpoint == "seasonal.json", idx$endpoints)
  expect_length(seasonal, 1)
  expect_true(grepl("seasonal", seasonal[[1]]$description, ignore.case = TRUE))
})

test_that("generate_api_index correlations endpoint has correct description", {
  idx <- generate_api_index()
  corr <- Filter(function(x) x$endpoint == "correlations.json", idx$endpoints)
  expect_length(corr, 1)
  expect_true(grepl("correlation", corr[[1]]$description, ignore.case = TRUE))
})

# ===========================================================================
# .api_meta() helper
# ===========================================================================

test_that(".api_meta returns valid structure", {
  meta <- .api_meta("trends", "Mann-Kendall trend tests")
  expect_type(meta, "list")
  expect_named(meta, c("generated", "package_version", "endpoint", "description"))
  expect_equal(meta$endpoint, "trends")
  expect_equal(meta$description, "Mann-Kendall trend tests")
  expect_true(grepl("^\\d{4}-\\d{2}-\\d{2}T", meta$generated))
  expect_true(nzchar(meta$package_version))
})

test_that(".api_wrap adds _meta and data fields", {
  payload <- list(a = 1, b = 2)
  result <- .api_wrap(payload, "test", "Test endpoint")
  expect_true("_meta" %in% names(result))
  expect_true("data" %in% names(result))
  expect_equal(result$data, payload)
  expect_equal(result[["_meta"]]$endpoint, "test")
})

# ===========================================================================
# generate_api_sources()
# ===========================================================================

test_that("generate_api_sources returns valid structure", {
  src <- generate_api_sources()
  expect_type(src, "list")
  expect_true("_meta" %in% names(src))
  expect_true("data" %in% names(src))
  expect_equal(src[["_meta"]]$endpoint, "sources")

  data <- src$data
  expect_true("erddap_base_url" %in% names(data))
  expect_true("dataset_id" %in% names(data))
  expect_true("update_frequency" %in% names(data))
  expect_true("license" %in% names(data))
  expect_true("citation" %in% names(data))
  expect_true(grepl("erddap", data$erddap_base_url, ignore.case = TRUE))
  expect_equal(data$dataset_id, "IWBNetwork")
})

# ===========================================================================
# generate_api_status()
# ===========================================================================

test_that("generate_api_status returns valid structure", {
  # Create mock dashboard_stats
  mock_stats <- list(
    station = tibble::tibble(
      station_id = c("M2", "M3"),
      n_records = c(1000L, 2000L),
      first_date = as.POSIXct(c("2017-01-01", "2016-01-01"), tz = "UTC"),
      last_date = as.POSIXct(c("2024-12-31", "2024-12-31"), tz = "UTC"),
      mean_wave_height = c(1.5, 2.0),
      max_wave_height = c(8.0, 12.0),
      mean_wind_speed = c(15.0, 18.0),
      max_wind_speed = c(50.0, 60.0)
    ),
    overall = list(
      total_records = 3000L,
      date_range = as.POSIXct(c("2016-01-01", "2024-12-31"), tz = "UTC"),
      stations = c("M2", "M3")
    )
  )
  result <- generate_api_status(mock_stats)
  expect_type(result, "list")
  expect_true("_meta" %in% names(result))
  expect_true("data" %in% names(result))
  expect_equal(result[["_meta"]]$endpoint, "status")

  data <- result$data
  expect_true("stations" %in% names(data))
  expect_true("total_records" %in% names(data))
  expect_length(data$stations, 2)
  # Each station should have status info
  expect_true("station_id" %in% names(data$stations[[1]]))
  expect_true("n_records" %in% names(data$stations[[1]]))
})

# ===========================================================================
# generate_api_trends()
# ===========================================================================

test_that("generate_api_trends returns valid structure", {
  # Mock per-station Mann-Kendall + annual trend results
  mock_mk <- list(
    M2 = list(
      wave_height = list(tau = 0.05, p_value = 0.12, trend_direction = "no trend"),
      wind_speed = list(tau = -0.08, p_value = 0.03, trend_direction = "decreasing")
    ),
    M3 = list(
      wave_height = list(tau = 0.10, p_value = 0.001, trend_direction = "increasing"),
      wind_speed = list(tau = -0.02, p_value = 0.45, trend_direction = "no trend")
    )
  )
  mock_annual_wave <- list(
    annual_stats = tibble::tibble(year = 2017:2024, mean = runif(8)),
    trend_per_decade = 0.05,
    p_value = 0.12,
    r_squared = 0.08
  )
  mock_annual_wind <- list(
    annual_stats = tibble::tibble(year = 2017:2024, mean = runif(8)),
    trend_per_decade = -0.3,
    p_value = 0.03,
    r_squared = 0.15
  )

  result <- generate_api_trends(mock_mk, mock_annual_wave, mock_annual_wind)
  expect_type(result, "list")
  expect_true("_meta" %in% names(result))
  expect_true("data" %in% names(result))
  expect_equal(result[["_meta"]]$endpoint, "trends")

  data <- result$data
  expect_true("mann_kendall" %in% names(data))
  expect_true("annual_trends" %in% names(data))
  expect_true("M2" %in% names(data$mann_kendall))
  expect_true("wave" %in% names(data$annual_trends))
  expect_true("wind" %in% names(data$annual_trends))
})

# ===========================================================================
# generate_api_extremes()
# ===========================================================================

test_that("generate_api_extremes returns valid structure", {
  # Mock return_levels_per_station
  mock_rl <- tibble::tibble(
    return_period = rep(c(1, 5, 10), 2),
    return_level = c(3.5, 5.2, 6.8, 4.0, 6.1, 7.5),
    lower = c(3.0, 4.5, 5.8, 3.4, 5.3, 6.4),
    upper = c(4.0, 5.9, 7.8, 4.6, 6.9, 8.6),
    station = rep(c("M2", "M3"), each = 3),
    variable = rep("avg_wave", 6),
    variable_label = rep("Avg Wave (m)", 6)
  )

  # Mock ci_comparison_per_station
  mock_ci <- tibble::tibble(
    return_period = rep(c(1, 5, 10), 4),
    return_level = runif(12, 3, 8),
    lower = runif(12, 2, 4),
    upper = runif(12, 6, 10),
    station = rep(c("M2", "M3"), each = 6),
    variable = rep("avg_wave", 12),
    method = rep(c("delta", "bootstrap"), each = 3, times = 2)
  )

  result <- generate_api_extremes(mock_rl, mock_ci)
  expect_type(result, "list")
  expect_true("_meta" %in% names(result))
  expect_true("data" %in% names(result))
  expect_equal(result[["_meta"]]$endpoint, "extremes")

  data <- result$data
  expect_true("method" %in% names(data))
  expect_true("return_levels" %in% names(data))
  expect_true("ci_comparison" %in% names(data))
})
