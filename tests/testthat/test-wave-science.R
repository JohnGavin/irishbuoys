# Tests for R/wave_science.R
# All functions are pure (no DB/network) so fully testable

test_that("wave_glossary returns valid data frame", {
  g <- wave_glossary()
  expect_s3_class(g, "data.frame")
  expect_true(nrow(g) > 0)
  expect_named(g, c("acronym", "term", "definition", "unit"))
  # Check key acronyms are present

  expect_true("Hs" %in% g$acronym)
  expect_true("Hmax" %in% g$acronym)
  expect_true("Tp" %in% g$acronym)
  # No NAs in acronym/term
  expect_false(any(is.na(g$acronym)))
  expect_false(any(is.na(g$term)))
})

test_that("explain_hs_formula returns non-empty string", {
  result <- explain_hs_formula()
  expect_type(result, "character")
  expect_true(nchar(result) > 100)
  expect_true(grepl("4.*sigma", result, ignore.case = TRUE))
  expect_true(grepl("Rayleigh", result))
})

test_that("explain_measurement_period returns non-empty string", {
  result <- explain_measurement_period()
  expect_type(result, "character")
  expect_true(nchar(result) > 100)
  expect_true(grepl("17.5", result))
})

test_that("explain_hourly_averaging returns non-empty string", {
  result <- explain_hourly_averaging()
  expect_type(result, "character")
  expect_true(nchar(result) > 100)
  expect_true(grepl("burst", result, ignore.case = TRUE))
})

test_that("explain_wave_height_measurement returns non-empty string", {
  result <- explain_wave_height_measurement()
  expect_type(result, "character")
  expect_true(nchar(result) > 100)
  expect_true(grepl("zero.*crossing", result, ignore.case = TRUE))
})

test_that("wave_science_documentation combines all explanations", {
  result <- wave_science_documentation()
  expect_type(result, "character")
  # Should contain content from all sub-functions
  expect_true(grepl("Rayleigh", result))
  expect_true(grepl("17.5", result))
  expect_true(grepl("burst", result, ignore.case = TRUE))
  expect_true(grepl("zero.*crossing", result, ignore.case = TRUE))
})

test_that("calculate_hs_from_elevation computes correctly", {
  # Known case: pure sine wave with amplitude A has sigma = A/sqrt(2)
  # so Hs = 4 * A/sqrt(2) = 2*sqrt(2)*A
  set.seed(42)
  t <- seq(0, 1000, by = 0.5)
  A <- 1.0
  elevation <- A * sin(2 * pi * t / 8)
  hs <- calculate_hs_from_elevation(elevation)
  expected_hs <- 4 * A / sqrt(2)  # 2*sqrt(2) ~ 2.828
  expect_equal(hs, expected_hs, tolerance = 0.01)
})

test_that("calculate_hs_from_elevation handles NAs", {
  elevation <- c(1, 2, NA, 3, NA, 4)
  hs <- calculate_hs_from_elevation(elevation)
  expect_true(is.numeric(hs))
  expect_true(is.finite(hs))
})

test_that("calculate_rms_wave_height computes correctly", {
  heights <- c(1, 2, 3, 4, 5)
  h_rms <- calculate_rms_wave_height(heights)
  expected <- sqrt(mean(heights^2))
  expect_equal(h_rms, expected)
})

test_that("calculate_rms_wave_height handles NAs", {
  heights <- c(1, 2, NA, 4)
  h_rms <- calculate_rms_wave_height(heights)
  expect_true(is.finite(h_rms))
})

test_that("hs_from_rms converts correctly", {
  h_rms <- 1.5
  hs <- hs_from_rms(h_rms)
  expect_equal(hs, h_rms * sqrt(8))
  # Inverse relationship
  expect_equal(hs / sqrt(8), h_rms)
})

test_that("hs_from_rms and calculate_rms_wave_height are consistent", {
  # For Rayleigh waves: Hs = sqrt(8) * H_rms
  heights <- c(1.2, 2.1, 0.8, 3.5, 1.9, 2.8)
  h_rms <- calculate_rms_wave_height(heights)
  hs <- hs_from_rms(h_rms)
  expect_true(hs > h_rms)  # Hs is always > H_rms
  expect_equal(hs / h_rms, sqrt(8), tolerance = 0.001)
})
