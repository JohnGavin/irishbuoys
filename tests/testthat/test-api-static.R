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

test_that("generate_api_index has 8 endpoints", {
  idx <- generate_api_index()
  expect_length(idx$endpoints, 8)
})

test_that("generate_api_index includes all endpoint names", {
  idx <- generate_api_index()
  endpoint_names <- vapply(idx$endpoints, function(x) x$endpoint, character(1))
  expected <- c(
    "stations.json", "stats.json", "rogue-waves.json",
    "return-levels.json", "data-dictionary.json", "latest.json",
    "seasonal.json", "correlations.json"
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
