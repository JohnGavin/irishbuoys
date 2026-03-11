# Tests for R/api_plumber.R
# Tests router creation and endpoint registration (no live HTTP)

test_that("plumber API definition file exists", {
  skip_if_not_installed("plumber")

  # Use pkgload-aware path: works both installed and with load_all()
  api_file <- system.file("plumber", "api.R", package = "irishbuoys")
  if (!nzchar(api_file)) {
    # Fallback for load_all() context
    api_file <- file.path("inst", "plumber", "api.R")
    if (!file.exists(api_file)) {
      api_file <- file.path("..", "..", "inst", "plumber", "api.R")
    }
  }
  expect_true(file.exists(api_file))
})

test_that("plumber router can be created from API file", {
  skip_if_not_installed("plumber")

  api_file <- system.file("plumber", "api.R", package = "irishbuoys")
  if (!nzchar(api_file)) {
    api_file <- file.path("inst", "plumber", "api.R")
    if (!file.exists(api_file)) {
      api_file <- file.path("..", "..", "inst", "plumber", "api.R")
    }
  }
  skip_if(!file.exists(api_file), "API file not found")

  pr <- plumber::plumb(api_file)
  expect_s3_class(pr, "Plumber")
})

test_that("plumber router has all 17 endpoints (16 data + index)", {
  skip_if_not_installed("plumber")

  api_file <- system.file("plumber", "api.R", package = "irishbuoys")
  if (!nzchar(api_file)) {
    api_file <- file.path("inst", "plumber", "api.R")
    if (!file.exists(api_file)) {
      api_file <- file.path("..", "..", "inst", "plumber", "api.R")
    }
  }
  skip_if(!file.exists(api_file), "API file not found")

  pr <- plumber::plumb(api_file)
  endpoints <- pr$endpoints[[1]]
  paths <- vapply(endpoints, function(e) e$path, character(1))

  expected_paths <- c(
    # Existing endpoints
    "/index", "/stations", "/stats", "/rogue-waves",
    "/return-levels", "/data-dictionary", "/latest",
    "/seasonal", "/correlations",
    # Tier 1
    "/sources", "/status", "/trends", "/extremes",
    # Tier 2
    "/decomposition", "/spatial", "/gust-factors",
    # Tier 3
    "/methods"
  )
  for (ep in expected_paths) {
    expect_true(ep %in% paths, info = paste("Missing Plumber route:", ep))
  }
  expect_length(paths, 17)
})
