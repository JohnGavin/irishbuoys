# Tests for R/data_dictionary.R
# Pure functions, no DB/network

test_that("get_data_dictionary returns valid tibble", {
  dict <- get_data_dictionary()
  expect_s3_class(dict, "tbl_df")
  expect_true(nrow(dict) > 0)
  expect_named(dict, c("variable", "category", "units", "data_type",
                        "description", "typical_range"))
})

test_that("get_data_dictionary has all expected categories", {
  dict <- get_data_dictionary()
  cats <- unique(dict$category)
  expect_true("dimension" %in% cats)
  expect_true("meteorological" %in% cats)
  expect_true("oceanographic" %in% cats)
  expect_true("quality" %in% cats)
})

test_that("get_data_dictionary has key variables", {
  dict <- get_data_dictionary()
  key_vars <- c("station_id", "time", "WaveHeight", "Hmax",
                "WindSpeed", "Gust", "SeaTemperature")
  for (v in key_vars) {
    expect_true(v %in% dict$variable, info = paste("Missing:", v))
  }
})

test_that("get_data_dictionary has no duplicate variables", {
  dict <- get_data_dictionary()
  expect_equal(length(dict$variable), length(unique(dict$variable)))
})

test_that("get_variable_docs returns all docs when NULL", {
  docs <- get_variable_docs(NULL)
  expect_type(docs, "list")
  expect_true(length(docs) > 0)
  expect_true("WaveHeight" %in% names(docs))
  expect_true("Hmax" %in% names(docs))
})

test_that("get_variable_docs returns specific variable", {
  doc <- get_variable_docs("WaveHeight")
  expect_type(doc, "list")
  expect_true("scientific_name" %in% names(doc))
  expect_true("definition" %in% names(doc))
})

test_that("get_variable_docs warns for unknown variable", {
  expect_warning(result <- get_variable_docs("nonexistent_var"))
  expect_null(result)
})

test_that("get_variable_docs Hmax has rogue_wave_threshold", {
  doc <- get_variable_docs("Hmax")
  expect_true("rogue_wave_threshold" %in% names(doc))
  expect_true(grepl("2", doc$rogue_wave_threshold))
})

test_that("get_variable_docs QC_Flag has values list", {
  doc <- get_variable_docs("QC_Flag")
  expect_true("values" %in% names(doc))
  expect_type(doc$values, "character")
})
