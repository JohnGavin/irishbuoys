# Tests for R/palettes.R and the palette menu (issue #116, PR A)

hex_re <- "^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$"

test_that("ib_palette_names lists the presets, okabe_ito first", {
  nm <- ib_palette_names()
  expect_equal(nm[1], "okabe_ito")
  expect_setequal(nm, c("okabe_ito", "viridis", "classic"))
})

test_that("default palette is okabe_ito and follows the option", {
  withr::local_options(irishbuoys.palette = NULL)
  expect_equal(ib_default_palette(), "okabe_ito")
  expect_equal(ib_palette()$name, "okabe_ito")
  withr::local_options(irishbuoys.palette = "viridis")
  expect_equal(ib_default_palette(), "viridis")
  expect_equal(ib_palette()$name, "viridis")
})

test_that("each preset gives enough valid colours for every category", {
  for (nm in ib_palette_names()) {
    pal <- ib_palette(nm)
    expect_s3_class(pal, "ib_palette")
    expect_gte(length(pal$categorical), 12L)
    expect_true(all(grepl(hex_re, pal$categorical)), info = nm)
    expect_equal(anyDuplicated(pal$categorical), 0L, info = nm)

    expect_equal(names(pal$station), paste0("M", 2:6), info = nm)
    expect_equal(names(pal$month), month.abb, info = nm)
    expect_length(pal$beaufort, 6L)
    expect_equal(names(pal$time_of_day), c("Morning", "Afternoon", "Evening", "Night"))
    expect_equal(names(pal$return_period), c("1-yr", "5-yr", "10-yr"))
    expect_equal(names(pal$rf_category), c("Low", "Moderate", "High", "Extreme"))
    for (g in c("station", "month", "beaufort", "time_of_day", "return_period", "rf_category")) {
      expect_true(all(grepl(hex_re, pal[[g]])), info = paste(nm, g))
      expect_equal(anyDuplicated(unname(pal[[g]])), 0L, info = paste(nm, g))
    }
  }
})

test_that("each preset defines the semantic colours", {
  needed <- c("threshold", "extreme", "reference", "neutral", "primary", "secondary",
              "tertiary", "fit", "marker_outline", "dark_bg", "dark_strip", "dark_text",
              "text_strong", "grid_base", "ink", "panel", "strip", "grid_major", "grid_minor",
              "point")
  for (nm in ib_palette_names()) {
    sem <- ib_palette(nm)$semantic
    expect_true(all(needed %in% names(sem)), info = nm)
    expect_true(all(grepl(hex_re, unlist(sem))), info = nm)
  }
})

test_that("unknown or malformed palette names abort", {
  expect_error(ib_palette("no_such_palette"), "Unknown palette")
  expect_error(ib_palette(1), "single string")
  expect_error(ib_palette(c("viridis", "classic")), "single string")
  expect_error(ib_palette(NA_character_), "single string")
  expect_error(ib_palette(NULL), "single string")
})

test_that("okabe_ito uses the published Okabe-Ito colours (black dropped for dark plots)", {
  ref <- unname(grDevices::palette.colors(palette = "Okabe-Ito"))
  pal <- ib_palette("okabe_ito")
  expect_true(all(toupper(pal$categorical[1:7]) %in% toupper(ref)))
  expect_false("#000000" %in% toupper(pal$categorical))
})

test_that("classic reproduces the colours that were hand-typed before", {
  pal <- ib_palette("classic")
  expect_equal(tolower(unname(pal$station[c("M2", "M3", "M4", "M5", "M6")])),
               c("#e41a1c", "#377eb8", "#4daf4a", "#984ea3", "#ff7f00"))
  expect_equal(tolower(unname(pal$month[c("Jan", "Dec")])), c("#1f77b4", "#8c6d31"))
  expect_equal(tolower(unname(pal$beaufort[1])), "#2166ac")
  expect_equal(tolower(unname(pal$time_of_day["Night"])), "#2166ac")
  expect_equal(tolower(pal$semantic$primary), "#4682b4")   # steelblue
  expect_equal(tolower(pal$semantic$secondary), "#ff8c00") # darkorange
})

test_that("ib_group_colors returns a colour per requested level, with a fallback", {
  pal <- ib_palette("okabe_ito")
  cols <- ib_group_colors(pal, "station", c("M3", "M6"))
  expect_equal(names(cols), c("M3", "M6"))
  expect_equal(unname(cols), unname(pal$station[c("M3", "M6")]))
  more <- ib_group_colors(pal, "station", c("M2", "M9", "M10"))
  expect_equal(names(more), c("M2", "M9", "M10"))
  expect_true(all(grepl(hex_re, more)))
  expect_equal(anyDuplicated(unname(more)), 0L)
  expect_error(ib_group_colors(pal, "nope", "a"), "Unknown colour group")
})

test_that("ib_alpha adds an alpha channel to a hex colour", {
  expect_equal(ib_alpha("#112233", 0.5), "#11223380")
  expect_equal(ib_alpha("#112233", 1), "#112233FF")
  expect_error(ib_alpha("#112233", 2), "between 0 and 1")
})

# --- add_palette_menu -------------------------------------------------------

mk_fig <- function(col) {
  plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "markers",
                  marker = list(color = col))
}

test_that("add_palette_menu adds one dropdown with one button per preset", {
  presets <- list(okabe_ito = mk_fig("#111111"), viridis = mk_fig("#222222"),
                  classic = mk_fig("#333333"))
  p <- add_palette_menu(presets$okabe_ito, presets)
  b <- plotly::plotly_build(p)
  um <- b$x$layout$updatemenus
  expect_length(um, 1L)
  expect_equal(um[[1]]$type, "dropdown")
  expect_length(um[[1]]$buttons, 3L)
  labels <- vapply(um[[1]]$buttons, function(x) x$label, character(1))
  expect_equal(labels, names(presets))
  expect_equal(um[[1]]$buttons[[2]]$method, "update")
  # button 2 restyles the trace colour to the second preset's colour
  expect_equal(um[[1]]$buttons[[2]]$args[[1]][["marker.color"]][[1]], "#222222")
  expect_equal(um[[1]]$buttons[[3]]$args[[1]][["marker.color"]][[1]], "#333333")
  expect_equal(um[[1]]$active, 0L)
})

test_that("add_palette_menu restyles layout colours (shapes, annotations)", {
  mk <- function(col) {
    plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "markers") |>
      plotly::layout(shapes = list(list(type = "line", x0 = 1, x1 = 3, y0 = 2, y1 = 2,
                                        line = list(color = col))))
  }
  presets <- list(a = mk("#aa0000"), b = mk("#00aa00"))
  p <- add_palette_menu(presets$a, presets)
  um <- plotly::plotly_build(p)$x$layout$updatemenus[[1]]
  expect_equal(um$buttons[[2]]$args[[2]][["shapes[0].line.color"]], "#00aa00")
})

test_that("add_palette_menu rejects bad input", {
  good <- list(a = mk_fig("#111111"), b = mk_fig("#222222"))
  expect_error(add_palette_menu(good$a, list(mk_fig("#111111"), mk_fig("#222222"))), "named list")
  expect_error(add_palette_menu(good$a, list(a = 1, b = 2)), "plotly")
  two_traces <- good$b |> plotly::add_trace(x = 1:3, y = 3:1, type = "scatter", mode = "lines")
  expect_error(add_palette_menu(good$a, list(a = good$a, b = two_traces)), "same number of traces")
  expect_error(add_palette_menu(good$a, good, selected = "zzz"), "selected")
})

# --- every create_plot_*() takes palette= and carries the menu ----------------

n_buttons <- function(p) {
  um <- plotly::plotly_build(p)$x$layout$updatemenus
  if (length(um) != 1L) return(NA_integer_)
  length(um[[1]]$buttons)
}

make_rf_eval <- function(n = 60) {
  actual <- runif(n, 0.5, 9)
  predicted <- actual + rnorm(n, 0, 0.4)
  cat <- cut(actual, c(-Inf, 2, 4, 6, Inf), labels = c("Low", "Moderate", "High", "Extreme"))
  list(
    predictions = data.frame(actual = actual, predicted = predicted,
                             residual = actual - predicted, category = cat),
    overall = data.frame(metric = c("R_squared", "RMSE", "MAE", "N_test"),
                         value = c(0.93, 0.4, 0.3, n))
  )
}

make_rf_model <- function() {
  list(importance = data.frame(variable = paste0("v", 1:12), importance = 12:1))
}

make_return_levels_station <- function() {
  data.frame(
    station = rep(c("M2", "M3", "M4"), each = 3),
    variable = "avg_wave", variable_label = "Avg Wave Height (m)",
    return_period = rep(c(1, 5, 10), 3),
    return_level = c(4.5, 6.2, 7.1, 5.0, 6.8, 7.8, 3.9, 5.5, 6.4),
    lower = c(3.8, 5.0, 5.8, 4.2, 5.5, 6.3, 3.2, 4.3, 5.1),
    upper = c(5.2, 7.4, 8.4, 5.8, 8.1, 9.3, 4.6, 6.7, 7.7)
  )
}

plotly_builders <- function() {
  list(
    rogue_all = function(...) create_plot_rogue_all(make_rogue_events(), ...),
    rogue_by_station = function(...) create_plot_rogue_by_station(make_rogue_events(), ...),
    rogue_station = function(...) create_plot_rogue_station(make_rogue_events(), "M2", ...),
    wind_beaufort = function(...) create_plot_wind_beaufort(make_rogue_conditions(), ...),
    week_of_year = function(...) create_plot_week_of_year(make_rogue_conditions(), ...),
    time_of_day = function(...) create_plot_time_of_day(make_rogue_conditions(), ...),
    monthly_wave = function(...) create_plot_monthly_wave(make_seasonal_means(), ...),
    monthly_wind = function(...) create_plot_monthly_wind(make_seasonal_means(), ...),
    annual_trends = function(...) create_plot_annual_trends(make_annual_trends(), ...),
    return_levels = function(...) create_plot_return_levels(make_return_levels(), ...),
    return_levels_station = function(...)
      create_plot_return_levels_per_station(make_return_levels_station(), "avg_wave", ...),
    gust_by_category = function(...) create_plot_gust_by_category(make_gust_analysis(), ...),
    gust_by_category_plain = function(...)
      create_plot_gust_by_category(make_gust_analysis(with_station = FALSE), ...),
    rogue_gusts = function(...) create_plot_rogue_gusts(make_gust_analysis(), ...),
    rogue_gusts_all = function(...) create_plot_rogue_gusts_all(make_rogue_gust_events(), ...),
    rogue_gusts_by_station = function(...)
      create_plot_rogue_gusts_by_station(make_rogue_gust_events(), ...),
    gusts_vs_waves = function(...) create_plot_gusts_vs_waves(make_analysis_data(), ...),
    rf_actual = function(...) create_plot_rf_actual_vs_predicted(make_rf_eval(), ...),
    rf_residuals = function(...) create_plot_rf_residuals(make_rf_eval(), ...),
    rf_importance = function(...) create_plot_rf_importance(make_rf_model(), ...)
  )
}

test_that("every plotly create_plot_*() carries a palette menu with one button per preset", {
  skip_if_not_installed("plotly")
  withr::local_seed(1)
  for (nm in names(plotly_builders())) {
    p <- plotly_builders()[[nm]]()
    expect_s3_class(p, "plotly")
    expect_equal(n_buttons(p), length(ib_palette_names()), info = nm)
  }
})

test_that("every plotly create_plot_*() takes palette= and aborts on an unknown preset", {
  skip_if_not_installed("plotly")
  withr::local_seed(2)
  for (nm in names(plotly_builders())) {
    expect_error(plotly_builders()[[nm]](palette = "bogus"), "Unknown palette", info = nm)
    p <- plotly_builders()[[nm]](palette = "viridis")
    um <- plotly::plotly_build(p)$x$layout$updatemenus[[1]]
    expect_equal(um$active, which(ib_palette_names() == "viridis") - 1L, info = nm)
  }
})

test_that("the palette argument changes the colours actually drawn", {
  skip_if_not_installed("plotly")
  withr::local_seed(3)
  for (nm in c("okabe_ito", "viridis", "classic")) {
    p <- create_plot_monthly_wave(make_seasonal_means(), palette = nm)
    b <- plotly::plotly_build(p)
    expect_equal(toupper(b$x$data[[1]]$marker$color), toupper(ib_palette(nm)$semantic$primary))
  }
})

test_that("default palette is used when palette is not given", {
  skip_if_not_installed("plotly")
  withr::local_options(irishbuoys.palette = NULL)
  b <- plotly::plotly_build(create_plot_monthly_wave(make_seasonal_means()))
  expect_equal(toupper(b$x$data[[1]]$marker$color),
               toupper(ib_palette("okabe_ito")$semantic$primary))
})

test_that("create_plot_stl takes palette= and uses its colours", {
  skip_if_not_installed("ggplot2")
  skip_if_not_installed("tidyr")
  p <- create_plot_stl(make_wave_stl(), palette = "viridis")
  expect_s3_class(p, "gg")
  expect_equal(toupper(p$layers[[1]]$aes_params$colour), toupper(ib_palette("viridis")$semantic$primary))
  expect_error(create_plot_stl(make_wave_stl(), palette = "bogus"), "Unknown palette")
})

test_that("new inline-replacement plots return NULL or an empty figure on no data", {
  skip_if_not_installed("plotly")
  expect_s3_class(create_plot_rogue_station(make_rogue_events(), "M9"), "plotly")
  expect_null(create_plot_rf_actual_vs_predicted(NULL))
  expect_null(create_plot_rf_residuals(NULL))
  expect_null(create_plot_rf_importance(NULL))
})

test_that("wind and gust labels say kn, not m/s", {
  skip_if_not_installed("plotly")
  withr::local_seed(4)
  json <- function(p) as.character(plotly::plotly_json(p, jsonedit = FALSE))
  for (nm in c("rogue_all", "wind_beaufort", "monthly_wind", "gust_by_category",
               "rogue_gusts_all", "rogue_gusts_by_station", "rogue_by_station")) {
    j <- json(plotly_builders()[[nm]]())
    expect_false(grepl("m/s", j, fixed = TRUE), info = nm)
  }
  expect_true(grepl("(kn)", json(create_plot_monthly_wind(make_seasonal_means())), fixed = TRUE))
  expect_true(grepl(" kn", json(create_plot_rogue_all(make_rogue_events())), fixed = TRUE))
})
