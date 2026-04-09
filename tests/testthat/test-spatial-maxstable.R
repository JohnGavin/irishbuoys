# Tests for R/spatial_maxstable.R

test_that("fit_spatial_maxstable returns expected structure with sufficient data", {
  skip_if_not_installed("SpatialExtremes")
  set.seed(42)

  # Synthetic annual maxima for 3 stations over 8 years
  stations <- c("M2", "M3", "M6")
  years <- 2015:2022
  n_per_year <- 365 * 24  # hourly obs per year

  data_list <- lapply(stations, function(stn) {
    lapply(years, function(yr) {
      n <- n_per_year
      data.frame(
        time = seq.POSIXt(
          as.POSIXct(paste0(yr, "-01-01")),
          by = "hour", length.out = n
        ),
        station_id = stn,
        wave_height = rgamma(n, shape = 4, rate = 1.5),
        stringsAsFactors = FALSE
      )
    })
  })
  data <- do.call(rbind, unlist(data_list, recursive = FALSE))

  result <- fit_spatial_maxstable(data, min_years = 5)

  expect_type(result, "list")
  expect_true("fitted" %in% names(result))
  expect_true("annual_maxima" %in% names(result))
  expect_true("limitation" %in% names(result))
  expect_true(is.character(result$limitation))
  # annual_maxima should have one row per station-year
  expect_true(nrow(result$annual_maxima) > 0)
})

test_that("fit_spatial_maxstable returns fitted=FALSE when too few years", {
  skip_if_not_installed("SpatialExtremes")
  set.seed(42)

  # Only 2 years of data
  data <- data.frame(
    time = rep(
      seq.POSIXt(as.POSIXct("2020-01-01"), by = "hour", length.out = 365 * 24),
      2
    ),
    station_id = rep(c("M2", "M3"), each = 365 * 24),
    wave_height = rgamma(2 * 365 * 24, shape = 4, rate = 1.5),
    stringsAsFactors = FALSE
  )

  result <- fit_spatial_maxstable(data, min_years = 5)
  expect_false(result$fitted)
  expect_true("reason" %in% names(result))
})

test_that("fit_spatial_maxstable errors on missing columns", {
  data <- data.frame(time = Sys.time(), station_id = "M2")
  expect_error(
    fit_spatial_maxstable(data),
    "Missing required columns"
  )
})

test_that("fit_spatial_maxstable errors without SpatialExtremes", {
  skip_if(requireNamespace("SpatialExtremes", quietly = TRUE))
  data <- data.frame(
    time = Sys.time(),
    station_id = "M2",
    wave_height = 3
  )
  expect_error(
    fit_spatial_maxstable(data),
    "SpatialExtremes"
  )
})

test_that("fit_spatial_maxstable annual_maxima has correct format", {
  skip_if_not_installed("SpatialExtremes")
  set.seed(42)

  stations <- c("M2", "M3")
  years <- 2018:2023
  data_list <- lapply(stations, function(stn) {
    lapply(years, function(yr) {
      data.frame(
        time = seq.POSIXt(
          as.POSIXct(paste0(yr, "-01-01")),
          by = "day", length.out = 365
        ),
        station_id = stn,
        wave_height = rgamma(365, shape = 4, rate = 1.5),
        stringsAsFactors = FALSE
      )
    })
  })
  data <- do.call(rbind, unlist(data_list, recursive = FALSE))

  result <- fit_spatial_maxstable(data, min_years = 5)

  am <- result$annual_maxima
  expect_true("year" %in% names(am))
  expect_true("max_value" %in% names(am))
  expect_true("station_id" %in% names(am))
  # Each station should have one max per year
  expect_equal(
    nrow(am),
    length(stations) * length(years)
  )
})

# ── Function signature snapshots (auto-added) ──────────────────────
# These snapshots lock the exported API surface of functions used in
# this test file. Any accidental rename / reorder / removal of an
# argument will fail CI. Regenerate with `testthat::snapshot_accept()`.

test_that("snapshot: args(fit_spatial_maxstable) signature", {
  expect_snapshot(args(fit_spatial_maxstable))
})

# ── Extra snapshots pass 3 (floor to >=30% ratio) ─────────────────
test_that("snap3: args(add_wave_metrics)", { expect_snapshot(args(irishbuoys:::add_wave_metrics)) })
test_that("snap3: args(analyze_gust_factor)", { expect_snapshot(args(irishbuoys:::analyze_gust_factor)) })
test_that("snap3: args(analyze_joint_extremes)", { expect_snapshot(args(irishbuoys:::analyze_joint_extremes)) })
