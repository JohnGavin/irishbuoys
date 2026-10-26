# Tests for R/email_preview.R (dev preview of the weekly email).
# All fixtures are built in a temp DuckDB; nothing touches the real database
# and nothing is ever sent.

make_preview_db <- function(end_age_hours, days = 15, env = parent.frame()) {
  dir <- withr::local_tempdir(.local_envir = env)
  db <- file.path(dir, "fixture.duckdb")
  con <- connect_duckdb(db_path = db, create_new = TRUE)
  end <- floor_to_hour(Sys.time() - end_age_hours * 3600)
  times <- seq(end - days * 24 * 3600, end, by = "hour")
  rows <- do.call(rbind, lapply(get_station_info()$station_id, function(s) {
    n <- length(times)
    data.frame(
      time = times, station_id = s, call_sign = NA_character_,
      longitude = NA_real_, latitude = NA_real_,
      atmospheric_pressure = 1010, air_temperature = 10, dew_point = NA_real_,
      wind_direction = 180, wind_speed = 15, gust = 20,
      relative_humidity = NA_real_, sea_temperature = 12, salinity = NA_real_,
      wave_height = 2 + sin(seq_len(n) / 10), wave_period = 8,
      mean_wave_direction = NA_real_, hmax = 3, tp = NA_real_, thtp = NA_real_,
      sprtp = NA_real_, qc_flag = 1L
    )
  }))
  DBI::dbWriteTable(con, "buoy_data", rows, append = TRUE)
  DBI::dbDisconnect(con)
  db
}

floor_to_hour <- function(x) {
  as.POSIXct(format(x, "%Y-%m-%d %H:00:00", tz = "UTC"), tz = "UTC")
}

test_that("preview refuses stale data and writes no file", {
  db <- make_preview_db(end_age_hours = 30 * 24)
  out <- withr::local_tempfile(fileext = ".html")
  expect_error(
    suppressMessages(capture.output(
      render_weekly_email_preview(db_path = db, out_file = out)
    )),
    "stale"
  )
  expect_false(file.exists(out))
})

test_that("preview refuses data just past the guard threshold (96 h)", {
  db <- make_preview_db(end_age_hours = 100)
  out <- withr::local_tempfile(fileext = ".html")
  expect_error(
    suppressMessages(capture.output(
      render_weekly_email_preview(db_path = db, out_file = out)
    )),
    "stale"
  )
  expect_false(file.exists(out))
})

test_that("preview renders fresh data and prints latest timestamps and path", {
  db <- make_preview_db(end_age_hours = 2)
  out <- withr::local_tempfile(fileext = ".html")
  printed <- capture.output(
    suppressMessages(render_weekly_email_preview(db_path = db, out_file = out))
  )
  expect_true(file.exists(out))
  expect_match(paste(readLines(out, warn = FALSE), collapse = "\n"),
               "Irish Weather Buoy Network")
  # latest-timestamp line per station, with age
  expect_true(any(grepl("^  M2  latest: \\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}  age: [0-9.]+ h$",
                        printed)))
  expect_equal(sum(grepl("latest: ", printed)), nrow(get_station_info()))
  expect_true(any(grepl(paste0("Preview written to: ", out), printed, fixed = TRUE)))
})

test_that("preview refuses an empty database", {
  dir <- withr::local_tempdir()
  db <- file.path(dir, "empty.duckdb")
  con <- connect_duckdb(db_path = db, create_new = TRUE)
  DBI::dbDisconnect(con)
  out <- withr::local_tempfile(fileext = ".html")
  expect_error(
    suppressMessages(capture.output(
      render_weekly_email_preview(db_path = db, out_file = out)
    )),
    "no station has any observation"
  )
  expect_false(file.exists(out))
})

test_that("preview errors on a missing database without creating it", {
  db <- file.path(withr::local_tempdir(), "nope.duckdb")
  expect_error(email_preview_latest(db), "not found")
  expect_false(file.exists(db))
})

test_that("fetch refuses to target the real project database", {
  expect_error(
    email_preview_fetch_recent(db_path = email_preview_real_db()),
    "Refusing to write the real project database"
  )
})

test_that("the freshness threshold has one home: the guard's default", {
  expect_equal(formals(validate_email_freshness)$max_stale_hours, 96)
})
