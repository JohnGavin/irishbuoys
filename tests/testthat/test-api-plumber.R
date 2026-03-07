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

test_that("plumber router has expected endpoints", {
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

  expect_true("/stations" %in% paths)
  expect_true("/rogue-waves" %in% paths)
  expect_true("/return-levels" %in% paths)
  expect_true("/seasonal" %in% paths)
})
