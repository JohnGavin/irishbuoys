# Tests for the weekly email event tables (irishbuoys#110, #109):
# one table per event type, unit in every header, "N of M" text,
# rogue-wave rows show the Hs they were judged against, full timestamps,
# and every link built from one URL home.

make_events <- function(n_high = 0, n_storm = 0, n_rogue = 0) {
  t0 <- as.POSIXct("2026-10-20 00:00:00", tz = "UTC")
  mk <- function(n, type, value, hs, offset) {
    if (n == 0) {
      return(NULL)
    }
    data.frame(
      station_id = "M6",
      time = t0 + 3600 * (offset + seq_len(n)),
      event_type = type,
      value = value + seq_len(n) / 100,
      hs = hs,
      stringsAsFactors = FALSE
    )
  }
  dplyr::bind_rows(
    mk(n_high, "High Waves", 9, 9, 0),
    mk(n_storm, "Storm Winds", 50, 4, 1000),
    mk(n_rogue, "Rogue Wave", 5.5, 2.5, 2000)
  )
}

make_summary <- function(events) {
  list(
    extreme_events = events,
    current_week = data.frame(
      station_id = "M6", n_observations = 100L,
      max_wave_height = 5.2, avg_wave_height = 2.1,
      avg_wind_speed = 12.3, avg_air_temp = 10.1, avg_sea_temp = 11.5,
      stringsAsFactors = FALSE
    ),
    data_coverage = NULL, ingestion_stats = NULL, db_stats = NULL,
    update_result = NULL, report_date = Sys.Date(),
    period = list(start = Sys.Date() - 7, end = Sys.Date() - 1),
    week_over_week = NULL
  )
}

email_html <- function(events) {
  # html_str is the HTML part only (as.character() also adds a text part)
  create_email_summary(make_summary(events))$html_str
}

th_texts <- function(html) {
  m <- regmatches(html, gregexpr("<th>.*?</th>", html, perl = TRUE))[[1]]
  gsub("<[^>]+>", "", m)
}

test_that("every measure column header carries its unit", {
  html <- email_html(make_events(2, 2, 2))
  headers <- th_texts(html)
  expect_false("Value" %in% headers)
  expect_true("Significant wave height Hs (m)" %in% headers)
  expect_true("Wind speed (kn)" %in% headers)
  expect_true("Maximum wave height Hmax (m)" %in% headers)
  expect_true("Ratio Hmax/Hs" %in% headers)
  measure <- headers[!headers %in% c("Station", "Time (UTC)", "Ratio Hmax/Hs")]
  expect_true(all(grepl("\\((m|kn)\\)$", measure)))
})

test_that("measure column headers link to the definitions page", {
  html <- email_html(make_events(1, 1, 1))
  defs <- irishbuoys:::email_dashboard_url("definitions")
  th_cells <- regmatches(html, gregexpr("<th>.*?</th>", html, perl = TRUE))[[1]]
  linked <- th_cells[grepl("<a href=", th_cells, fixed = TRUE)]
  expect_gte(length(linked), 4)
  expect_true(all(grepl(defs, linked, fixed = TRUE)))
})

test_that("rogue-wave rows show Hmax, the Hs they were judged against and the ratio", {
  ev <- data.frame(
    station_id = "M6",
    time = as.POSIXct("2026-10-22 13:00:00", tz = "UTC"),
    event_type = "Rogue Wave", value = 5.5, hs = 2.2,
    stringsAsFactors = FALSE
  )
  html <- email_html(ev)
  expect_match(html, "<td>5.5</td><td>2.2</td><td>2.5</td>", fixed = TRUE)
})

test_that("each table states its threshold from the shared constants", {
  html <- email_html(make_events(1, 1, 1))
  rules <- irishbuoys:::.email_rules
  expect_match(html, paste0("above ", rules$high_waves$threshold, " m"),
               fixed = TRUE)
  expect_match(html, paste0("above ", rules$storm_winds$threshold, " kn"),
               fixed = TRUE)
  expect_match(html, paste0("more than ", rules$rogue_wave$ratio, " times"),
               fixed = TRUE)
})

test_that("changing a threshold constant changes the email text", {
  rules <- irishbuoys:::.email_rules
  rules$high_waves$threshold <- 9
  testthat::local_mocked_bindings(.email_rules = rules, .package = "irishbuoys")
  html <- email_html(make_events(1, 0, 0))
  expect_match(html, "above 9 m", fixed = TRUE)
  expect_no_match(html, "above 8 m", fixed = TRUE)
})

test_that("event queries do not hand-type the thresholds", {
  src <- paste(deparse(body(generate_weekly_summary)), collapse = "\n")
  expect_no_match(src, "wave_height > 8", fixed = TRUE)
  expect_no_match(src, "wind_speed > 48", fixed = TRUE)
  expect_no_match(src, "2 * .data$wave_height", fixed = TRUE)
})

test_that("unit symbols agree with the data dictionary", {
  dict <- get_data_dictionary()
  to_symbol <- c(meters = "m", knots = "kn")
  unit_of <- function(var) unname(to_symbol[dict$units[dict$variable == var]])
  rules <- irishbuoys:::.email_rules
  expect_equal(rules$high_waves$unit, unit_of("WaveHeight"))
  expect_equal(rules$rogue_wave$unit, unit_of("Hmax"))
  expect_equal(rules$storm_winds$unit, unit_of("WindSpeed"))
})

test_that("a table over the cap says 'showing N of M' and links to the dashboard", {
  cap <- irishbuoys:::.email_max_events_per_table
  html <- email_html(make_events(n_high = cap + 5))
  expect_match(
    html,
    paste0("Showing the newest ", cap, " of ", cap + 5, " events"),
    fixed = TRUE
  )
  expect_match(html, irishbuoys:::email_dashboard_url("high_waves"), fixed = TRUE)
  rows <- gregexpr("<tr><td>M6</td>", html, fixed = TRUE)[[1]]
  expect_equal(length(rows), cap)
})

test_that("a table at or under the cap shows every row and says so", {
  html <- email_html(make_events(n_high = 5))
  expect_match(html, "Showing all 5 events", fixed = TRUE)
  expect_equal(length(gregexpr("<tr><td>M6</td>", html, fixed = TRUE)[[1]]), 5)
})

test_that("old behaviour (silent halving) is gone: 4 events show 4 rows", {
  html <- email_html(make_events(n_high = 4))
  expect_equal(length(gregexpr("<tr><td>M6</td>", html, fixed = TRUE)[[1]]), 4)
})

test_that("rows are newest first", {
  html <- email_html(make_events(n_high = 3))
  pos_new <- regexpr("2026-10-20 03:00:00 UTC", html, fixed = TRUE)
  pos_old <- regexpr("2026-10-20 01:00:00 UTC", html, fixed = TRUE)
  expect_true(pos_new > 0 && pos_old > 0)
  expect_true(pos_new < pos_old)
})

test_that("time shows full timestamp with timezone, even at midnight", {
  ev <- data.frame(
    station_id = "M3",
    time = as.POSIXct("2026-10-22 00:00:00", tz = "UTC"),
    event_type = "High Waves", value = 8.4, hs = 8.4,
    stringsAsFactors = FALSE
  )
  html <- email_html(ev)
  expect_match(html, "2026-10-22 00:00:00 UTC", fixed = TRUE)
})

test_that("event types with no rows are named, not dropped", {
  html <- email_html(make_events(n_high = 1))
  expect_match(html, "None this week.", fixed = TRUE)
  expect_match(html, "Storm Winds", fixed = TRUE)
  expect_match(html, "Rogue Waves", fixed = TRUE)
})

test_that("unrecognised event types are counted, not silently dropped", {
  ev <- rbind(
    make_events(n_high = 1),
    data.frame(station_id = "M2", time = Sys.time(), event_type = "Other",
               value = 1, hs = 1, stringsAsFactors = FALSE)
  )
  expect_match(email_html(ev), "1 event(s) of an unrecognised type",
               fixed = TRUE)
})

test_that("every section heading link matches the documented URL pattern", {
  html <- email_html(make_events(1, 1, 1))
  hrefs <- unique(unlist(regmatches(
    html, gregexpr("https://johngavin\\.github\\.io/irishbuoys/articles/[^'\" <]+",
                   html)
  )))
  expect_gte(length(hrefs), 6)
  pattern <- paste0(
    "^", gsub(".", "\\.", irishbuoys:::.dashboard_base_url, fixed = TRUE),
    "articles/(dashboard_static|telemetry)\\.html#[a-z0-9-]+$"
  )
  expect_true(all(grepl(pattern, hrefs)))
  targets <- names(irishbuoys:::.dashboard_targets)
  expected <- vapply(targets, irishbuoys:::email_dashboard_url, character(1))
  expect_true(all(hrefs %in% expected))
  for (key in c("ingestion", "coverage", "station_stats", "rogue_wave")) {
    expect_match(html, irishbuoys:::email_dashboard_url(key), fixed = TRUE)
  }
})

test_that("an unknown dashboard target aborts instead of emitting a dead link", {
  expect_error(irishbuoys:::email_dashboard_url("nope"), "Unknown dashboard target")
})

test_that("live dashboard links return HTTP 200 (set IRISHBUOYS_LIVE_LINKS=true)", {
  skip_if_not(identical(Sys.getenv("IRISHBUOYS_LIVE_LINKS"), "true"))
  skip_if_not_installed("curl")
  urls <- unique(vapply(
    names(irishbuoys:::.dashboard_targets),
    function(k) sub("#.*$", "", irishbuoys:::email_dashboard_url(k)),
    character(1)
  ))
  for (u in urls) {
    expect_equal(curl::curl_fetch_memory(u)$status_code, 200L, info = u)
  }
})
