# Tests for the exceedance model, the wave Manhattan and Q-Q plots and the
# restyled gust-ratio plot (issue #116, PR B).

# --- Fixtures ---------------------------------------------------------------

make_exceedance_data <- function(n = 40) {
  data.frame(
    time = as.POSIXct("2024-01-01", tz = "UTC") + seq_len(n) * 3600,
    station_id = rep(c("M2", "M3"), length.out = n),
    wave_height = rep(3, n),
    hmax = rep(3, n) * seq(1.5, 2.3, length.out = n),
    wave_period = rep(8, n),
    qc_flag = rep(1L, n),
    stringsAsFactors = FALSE
  )
}

# Adds one record far beyond the cap and returns the data
with_extreme <- function(d, qc = 1L, ratio = 8.1) {
  extra <- d[1, ]
  extra$time <- max(d$time) + 3600
  extra$station_id <- "M2"
  extra$wave_height <- 3
  extra$hmax <- 3 * ratio
  extra$qc_flag <- qc
  rbind(d, extra)
}

built <- function(p) plotly::plotly_build(p)$x

trace_symbols <- function(b) {
  unlist(lapply(b$data, function(tr) unique(as.character(tr$marker$symbol))))
}

# --- Model: p_hmax_exceedance ------------------------------------------------

test_that("Rayleigh special case at ratio 2, N = 1 gives exp(-8)", {
  p <- p_hmax_exceedance(
    2, hs = 1, tz = 10, duration_s = 10,
    alpha = 1 / sqrt(2), beta = 2
  )
  expect_equal(p, exp(-8), tolerance = 1e-10)
  expect_equal(p, 3.35e-4, tolerance = 1e-3)
})

test_that("ratios 5 and 8.1 with N about 130 give finite positive p", {
  n_waves <- 130
  dur <- ib_record_duration_s()
  tz <- dur / n_waves
  p <- p_hmax_exceedance(c(5, 8.1), hs = 1, tz = tz, duration_s = dur)
  expect_true(all(is.finite(p)))
  expect_true(all(p > 0))
  expect_lt(p[2], p[1])
  # Falsification: the old naive form underflows to exactly 0 on the same input
  old <- function(h, hs, n, alpha = 0.681, beta = 2.126) {
    1 - (1 - exp(-(h / (alpha * hs))^beta))^n
  }
  expect_equal(old(c(5, 8.1), 1, n_waves), c(0, 0))
})

test_that("log-space value stays finite where p itself underflows", {
  lp <- irishbuoys:::.ib_hmax_exceed(h = 40, hs = 1, tz = 8, duration_s = 1050,
                                     alpha = 0.681, beta = 2.126)
  expect_equal(lp$p, 0)
  expect_true(is.finite(lp$log_p))
  expect_lt(lp$log_p, -700)
})

test_that("p_hmax_exceedance edge cases: Hs = 0, NA, Hmax < Hs", {
  expect_true(is.na(p_hmax_exceedance(2, hs = 0, tz = 8, duration_s = 1050)))
  expect_true(is.na(p_hmax_exceedance(2, hs = NA_real_, tz = 8, duration_s = 1050)))
  expect_true(is.na(p_hmax_exceedance(NA_real_, hs = 1, tz = 8, duration_s = 1050)))
  expect_true(is.na(p_hmax_exceedance(2, hs = 1, tz = 0, duration_s = 1050)))
  expect_equal(p_hmax_exceedance(numeric(0), numeric(0), numeric(0)), numeric(0))
  p_low <- p_hmax_exceedance(0.5, hs = 1, tz = 8, duration_s = 1050)
  expect_true(is.finite(p_low))
  expect_gt(p_low, 0.99)
  expect_lte(p_low, 1)
})

test_that("small N agrees with the exact form where the old form was accurate", {
  h <- c(0.8, 1.2, 1.6)
  old <- 1 - (1 - exp(-(h / (0.681 * 1))^2.126))^25
  expect_equal(p_hmax_exceedance(h, 1, 42, 1050), old, tolerance = 1e-12)
})

# --- Record duration: one named home ----------------------------------------

test_that("the record duration is 17.5 minutes in one named home", {
  expect_equal(ib_record_duration_s(), 17.5 * 60)
})

test_that("observed-record code takes N from ib_record_duration_s()", {
  prep <- irishbuoys:::.ib_exceedance_prep(make_exceedance_data())
  expect_equal(prep$data$n_waves, ib_record_duration_s() / prep$data$wave_period)

  src <- source_tree_file("R", "plot_exceedance.R")
  skip_if(is.null(src), "R/plot_exceedance.R not available")
  txt <- paste(readLines(src, warn = FALSE), collapse = "\n")
  expect_true(grepl("ib_record_duration_s()", txt, fixed = TRUE))
  expect_false(grepl("1050|17\\.5|3600", txt))
})

test_that("3600 s stays only as the forecast default and is documented as such", {
  expect_equal(formals(p_hmax_exceedance)$duration_s, 3600)
  src <- source_tree_file("R", "storm_alert.R")
  skip_if(is.null(src), "R/storm_alert.R not available")
  txt <- paste(readLines(src, warn = FALSE), collapse = "\n")
  expect_true(grepl("forecast", txt, ignore.case = TRUE))
  expect_true(grepl("ib_record_duration_s", txt, fixed = TRUE))
})

# --- Pre-plot data checks ---------------------------------------------------

test_that("data checks count NA rows, Hmax < Hs and Hmax/Hs > 3", {
  d <- make_exceedance_data(10)
  d$hmax[1] <- NA_real_            # NA row
  d$wave_period[2] <- NA_real_     # NA row
  d$hmax[3] <- d$wave_height[3] * 0.9   # Hmax < Hs
  d$hmax[4] <- d$wave_height[4] * 3.5   # ratio > 3
  d$hmax[5] <- d$wave_height[5] * 4.0   # ratio > 3
  prep <- irishbuoys:::.ib_exceedance_prep(d)
  expect_equal(prep$checks$n_input, 10L)
  expect_equal(prep$checks$n_na_dropped, 2L)
  expect_equal(prep$checks$n_hmax_lt_hs, 1L)
  expect_equal(prep$checks$n_ratio_gt_3, 2L)
  expect_equal(nrow(prep$data), 8L)
  expect_match(prep$caption, "NA")
})

test_that("Hs = 0 rows are dropped from the model and counted", {
  d <- make_exceedance_data(6)
  d$wave_height[1] <- 0
  prep <- irishbuoys:::.ib_exceedance_prep(d)
  expect_equal(prep$checks$n_not_computable, 1L)
  expect_equal(nrow(prep$data), 5L)
})

test_that("QC-flagged records stay in the data, marked suspect", {
  d <- with_extreme(make_exceedance_data(10), qc = 9L)
  prep <- irishbuoys:::.ib_exceedance_prep(d)
  expect_equal(nrow(prep$data), nrow(d))
  expect_equal(sum(prep$data$suspect), 1L)
})

# --- Manhattan --------------------------------------------------------------

test_that("create_plot_wave_manhattan returns NULL on no data", {
  expect_null(create_plot_wave_manhattan(NULL))
  expect_null(create_plot_wave_manhattan(make_exceedance_data()[0, ]))
})

test_that("Manhattan threshold lines equal the function's own output", {
  d <- make_exceedance_data()
  p <- create_plot_wave_manhattan(d)
  expect_s3_class(p, "plotly")
  b <- built(p)
  ys <- vapply(b$layout$shapes, function(s) {
    if (identical(s$type, "line")) s$y0 else NA_real_
  }, numeric(1))
  ys <- sort(ys[!is.na(ys)])

  tz <- stats::median(d$wave_period)
  ratios <- irishbuoys:::ib_rogue_ratio_thresholds()
  expected <- sort(-log10(p_hmax_exceedance(
    unname(ratios), hs = 1, tz = tz, duration_s = ib_record_duration_s()
  )))
  expect_equal(ys, expected, tolerance = 1e-8)
  expect_equal(unname(ratios), c(2.0, 2.2))
})

test_that("points above the cap are drawn at the cap with the true value in hover", {
  d <- with_extreme(make_exceedance_data())
  cap <- 20
  b <- built(create_plot_wave_manhattan(d, y_cap = cap))
  tri <- Filter(function(tr) any(grepl("triangle", tr$marker$symbol)), b$data)
  expect_length(tri, 1L)
  expect_equal(as.numeric(tri[[1]]$y), cap)

  true_val <- -log10(p_hmax_exceedance(
    3 * 8.1, hs = 3, tz = 8, duration_s = ib_record_duration_s()
  ))
  expect_gt(true_val, cap)
  expect_match(tri[[1]]$text, sprintf("%.2f", true_val), fixed = TRUE)
  # nothing is plotted above the cap
  all_y <- unlist(lapply(b$data, function(tr) tr$y))
  expect_lte(max(all_y), cap)
})

test_that("QC-suspect records are drawn hollow and grey, never dropped", {
  d <- with_extreme(make_exceedance_data(), qc = 9L)
  b <- built(create_plot_wave_manhattan(d, y_cap = 20))
  syms <- trace_symbols(b)
  expect_true(any(grepl("open", syms)))
  hollow <- Filter(function(tr) any(grepl("open", tr$marker$symbol)), b$data)
  expect_equal(toupper(hollow[[1]]$marker$color),
               toupper(ib_palette()$semantic$neutral_light))
  n_pts <- sum(vapply(b$data, function(tr) length(tr$x), integer(1)))
  prep <- irishbuoys:::.ib_exceedance_prep(d)
  expect_equal(n_pts, sum(prep$data$nlog10_p >= 1))
})

test_that("Manhattan labels the top event per station and shades alternate stations", {
  d <- with_extreme(make_exceedance_data())
  b <- built(create_plot_wave_manhattan(d))
  texts <- vapply(b$layout$annotations, function(a) as.character(a$text), character(1))
  expect_true(any(grepl("^M2: ", texts)))
  expect_true(any(grepl("^M3: ", texts)))
  rects <- Filter(function(s) identical(s$type, "rect"), b$layout$shapes)
  expect_length(rects, 1L)  # shading on every other station block
})

test_that("data checks appear in the Manhattan figure caption", {
  d <- make_exceedance_data()
  d$hmax[1] <- NA_real_
  b <- built(create_plot_wave_manhattan(d))
  texts <- vapply(b$layout$annotations, function(a) as.character(a$text), character(1))
  expect_true(any(grepl("Data checks", texts)))
})

test_that("Manhattan takes palette= and carries the palette menu", {
  d <- make_exceedance_data()
  p <- create_plot_wave_manhattan(d, palette = "viridis")
  um <- built(p)$layout$updatemenus[[1]]
  expect_equal(length(um$buttons), length(ib_palette_names()))
  expect_equal(um$active, which(ib_palette_names() == "viridis") - 1L)
  expect_error(create_plot_wave_manhattan(d, palette = "bogus"), "Unknown palette")
})

# --- Q-Q --------------------------------------------------------------------

test_that("create_plot_exceedance_qq returns NULL on no data", {
  expect_null(create_plot_exceedance_qq(NULL))
})

test_that("Q-Q plot has per-station points, a 95% band and both reference lines", {
  d <- with_extreme(make_exceedance_data(60))
  p <- create_plot_exceedance_qq(d)
  expect_s3_class(p, "plotly")
  b <- built(p)
  nm <- vapply(b$data, function(tr) as.character(tr$name %||% ""), character(1))
  expect_true(any(grepl("M2", nm)))
  expect_true(any(grepl("95%", nm)))
  expect_true(any(grepl("Forristall", nm)))
  expect_true(any(grepl("Rayleigh", nm)))
  um <- b$layout$updatemenus[[1]]
  expect_equal(length(um$buttons), length(ib_palette_names()))
})

test_that("Q-Q observed values are the sorted -log10(p) and expected are uniform quantiles", {
  d <- make_exceedance_data(60)
  prep <- irishbuoys:::.ib_exceedance_prep(d)
  qq <- irishbuoys:::.ib_qq_table(prep$data[prep$data$station_id == "M2", ],
                                  max_points = 1000)
  n <- sum(prep$data$station_id == "M2")
  expect_equal(nrow(qq), n)
  expect_equal(qq$expected, sort(-log10(stats::ppoints(n)), decreasing = TRUE))
  expect_equal(qq$observed,
               sort(prep$data$nlog10_p[prep$data$station_id == "M2"], decreasing = TRUE))
  expect_true(all(qq$band_lo <= qq$band_hi))
})

test_that("Q-Q thinning keeps the whole upper tail", {
  d <- make_exceedance_data(2000)
  prep <- irishbuoys:::.ib_exceedance_prep(d)
  qq <- irishbuoys:::.ib_qq_table(prep$data, max_points = 300)
  expect_lte(nrow(qq), 300 + 1)
  top <- sort(prep$data$nlog10_p, decreasing = TRUE)[1:10]
  expect_equal(qq$observed[1:10], top)
})

# --- Gust-ratio plot: time series with range slider ---------------------------

make_long_gusts <- function(n = 40, by_days = 10) {
  g <- make_rogue_gust_events(n)
  g$time <- as.POSIXct("2024-01-01", tz = "UTC") + (seq_len(n) - 1) * by_days * 86400
  g
}

test_that("gust plot is a time series with threshold line and top-event labels", {
  g <- make_long_gusts()
  b <- built(create_plot_rogue_gusts_all(g))
  expect_equal(b$layout$xaxis$type, "date")
  types <- vapply(b$layout$shapes, function(s) as.character(s$type), character(1))
  expect_true("line" %in% types)
  texts <- vapply(b$layout$annotations, function(a) as.character(a$text), character(1))
  expect_true(any(grepl("^M2: ", texts)))
  expect_true(any(grepl("^M3: ", texts)))
  expect_length(b$layout$updatemenus[[1]]$buttons, length(ib_palette_names()))
  expect_null(create_plot_rogue_gusts_all(NULL))
})

test_that("gust plot has a range slider opening on the last 3 months of the data", {
  g <- make_long_gusts()
  b <- built(create_plot_rogue_gusts_all(g))
  ax <- b$layout$xaxis
  expect_false(is.null(ax$rangeslider))
  expect_false(isFALSE(ax$rangeslider$visible))
  win <- as.POSIXct(unlist(ax$range), tz = "UTC")
  expect_equal(win[2], max(g$time))
  span_days <- as.numeric(difftime(win[2], win[1], units = "days"))
  expect_gte(span_days, 89)
  expect_lte(span_days, 92)
  # the slider itself spans the whole record
  full <- as.POSIXct(unlist(ax$rangeslider$range), tz = "UTC")
  expect_equal(full[1], min(g$time))
  expect_equal(full[2], max(g$time))
})

test_that("a record shorter than 3 months opens on the whole record", {
  g <- make_long_gusts(n = 10, by_days = 1)
  ax <- built(create_plot_rogue_gusts_all(g))$layout$xaxis
  win <- as.POSIXct(unlist(ax$range), tz = "UTC")
  expect_equal(win[1], min(g$time))
  expect_equal(win[2], max(g$time))
})

