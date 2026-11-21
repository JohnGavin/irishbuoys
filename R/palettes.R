#' Colour Palettes for Irish Buoys Plots
#'
#' @description
#' One home for every colour used by the plots and dashboards. A palette
#' *preset* bundles categorical colours (stations, months, Beaufort classes,
#' ...) and semantic colours (threshold lines, reference lines, backgrounds).
#' Plot code never types a colour: it asks a preset for it.
#'
#' Presets:
#' \describe{
#'   \item{`okabe_ito`}{Default. The colour-blind-safe Okabe-Ito set (Okabe and
#'     Ito, 2008). Its black is left out because the plots use a dark
#'     background; four tints extend it to 12 categories.}
#'   \item{`viridis`}{Evenly spaced colours from the viridis map.}
#'   \item{`classic`}{The colours that were hand-typed in each plot before
#'     the palette home existed.}
#' }
#'
#' The default preset is read from `getOption("irishbuoys.palette")` and falls
#' back to `"okabe_ito"`.
#'
#' @name palettes
#' @keywords internal
NULL

# Colours that do not change between presets: the dark theme, text and the
# light panel of the STL plot. Kept here so no other file types them.
.ib_structural <- list(
  dark_bg = "#1A1A1A",
  dark_strip = "#333333",
  dark_text = "#CCCCCC",
  hover_bg = "#000000",
  text_strong = "#FFFFFF",
  grid_base = "#FFFFFF",
  grid_line = "#666666",
  reference = "#888888",
  neutral = "#666666",
  neutral_light = "#999999",
  marker_outline = "#333333",
  annotation = "#333333",
  ink = "#1A1A1A",
  panel = "#B3B3B3",
  strip = "#999999",
  grid_major = "#666666",
  grid_minor = "#808080"
)

.ib_beaufort_levels <- c(
  "0-5 (Calm-Fresh)", "6-7 (Strong-Near Gale)", "8-9 (Gale-Severe)",
  "10 (Storm)", "11 (Violent Storm)", "12 (Hurricane)"
)
.ib_tod_levels <- c("Morning", "Afternoon", "Evening", "Night")
.ib_period_levels <- c("1-yr", "5-yr", "10-yr")
.ib_rf_levels <- c("Low", "Moderate", "High", "Extreme")
.ib_station_levels <- paste0("M", 2:6)

.ib_colour_groups <- c(
  "station", "month", "beaufort", "time_of_day", "return_period", "rf_category"
)

# Mix colours towards white (amount in 0..1); returns upper-case hex.
.ib_tint <- function(cols, amount = 0.5) {
  m <- grDevices::col2rgb(cols)
  out <- round(m * (1 - amount) + 255 * amount)
  grDevices::rgb(out[1, ], out[2, ], out[3, ], maxColorValue = 255)
}

# n evenly spaced viridis colours, without the near-invisible darkest end.
.ib_viridis <- function(n) {
  grDevices::hcl.colors(n + 1L, "viridis")[-1L]
}

.ib_named <- function(cols, nms) {
  stats::setNames(as.character(cols), nms)
}

.ib_make_preset <- function(name, categorical, groups, semantic) {
  structure(
    c(
      list(name = name, categorical = categorical),
      groups,
      list(semantic = c(semantic, .ib_structural))
    ),
    class = "ib_palette"
  )
}

.ib_preset_okabe_ito <- function() {
  orange <- "#E69F00"
  skyblue <- "#56B4E9"
  green <- "#009E73"
  yellow <- "#F0E442"
  blue <- "#0072B2"
  vermillion <- "#D55E00"
  purple <- "#CC79A7"
  grey <- "#999999"
  series <- c(
    orange, skyblue, green, yellow, blue, vermillion, purple, grey,
    .ib_tint(c(orange, green, blue, vermillion), 0.5)
  )
  .ib_make_preset(
    "okabe_ito", series,
    groups = list(
      station = .ib_named(series[1:5], .ib_station_levels),
      month = .ib_named(series[1:12], month.abb),
      beaufort = .ib_named(
        c(skyblue, blue, yellow, orange, vermillion, purple), .ib_beaufort_levels
      ),
      time_of_day = .ib_named(c(orange, vermillion, skyblue, blue), .ib_tod_levels),
      return_period = .ib_named(c(skyblue, orange, vermillion), .ib_period_levels),
      rf_category = .ib_named(c(blue, green, orange, vermillion), .ib_rf_levels)
    ),
    semantic = list(
      threshold = vermillion, extreme = orange,
      primary = skyblue, secondary = orange, tertiary = vermillion,
      fit = vermillion, loess = green, point = skyblue, importance = skyblue,
      ref_wave = blue, ref_gust = orange,
      scale_low = yellow, scale_high = vermillion
    )
  )
}

.ib_preset_viridis <- function() {
  series <- .ib_viridis(12)
  .ib_make_preset(
    "viridis", series,
    groups = list(
      station = .ib_named(.ib_viridis(5), .ib_station_levels),
      month = .ib_named(series, month.abb),
      beaufort = .ib_named(.ib_viridis(6), .ib_beaufort_levels),
      time_of_day = .ib_named(.ib_viridis(4), .ib_tod_levels),
      return_period = .ib_named(.ib_viridis(3), .ib_period_levels),
      rf_category = .ib_named(.ib_viridis(4), .ib_rf_levels)
    ),
    semantic = list(
      threshold = "#FDE725", extreme = "#B4DE2C",
      primary = "#1F9E89", secondary = "#B4DE2C", tertiary = "#FDE725",
      fit = "#6DCD59", loess = "#FDE725", point = "#26828E", importance = "#26828E",
      ref_wave = "#26828E", ref_gust = "#FDE725",
      scale_low = "#FDE725", scale_high = "#26828E"
    )
  )
}

.ib_preset_classic <- function() {
  # Collected from the hand-typed vectors in R/plot_functions.R and the
  # deployed vignettes before this file existed.
  series <- c(
    "#E41A1C", "#377EB8", "#4DAF4A", "#984EA3", "#FF7F00", "#FFFF33",
    "#A65628", "#F781BF", "#999999", "#66C2A5", "#FC8D62", "#8DA0CB"
  )
  .ib_make_preset(
    "classic", series,
    groups = list(
      station = .ib_named(series[1:5], .ib_station_levels),
      month = .ib_named(
        c(
          "#1F77B4", "#2CA02C", "#8C564B", "#FF7F0E", "#D62728", "#9467BD",
          "#E377C2", "#17BECF", "#7F7F7F", "#393B79", "#637939", "#8C6D31"
        ),
        month.abb
      ),
      beaufort = .ib_named(
        c("#2166AC", "#4393C3", "#D6604D", "#F4A582", "#B2182B", "#67001F"),
        .ib_beaufort_levels
      ),
      time_of_day = .ib_named(
        c("#F4A582", "#D6604D", "#4393C3", "#2166AC"), .ib_tod_levels
      ),
      return_period = .ib_named(c("#4393C3", "#F4A582", "#D6604D"), .ib_period_levels),
      rf_category = .ib_named(
        c("#2196F3", "#4CAF50", "#FF9800", "#F44336"), .ib_rf_levels
      )
    ),
    semantic = list(
      threshold = "#FF4444", extreme = "#FF8800",
      primary = "#4682B4", secondary = "#FF8C00", tertiary = "#8B0000",
      fit = "#FF4444", loess = "#00FF88", point = "#00BFFF", importance = "#1F77B4",
      ref_wave = "#0000FF", ref_gust = "#FFA500",
      scale_low = "#FEE0D2", scale_high = "#DE2D26"
    )
  )
}

#' Names of the available palette presets
#'
#' @return Character vector of preset names; the first is the built-in default.
#' @examples
#' ib_palette_names()
#' @export
ib_palette_names <- function() {
  c("okabe_ito", "viridis", "classic")
}

#' Name of the default palette preset
#'
#' @description
#' Reads `getOption("irishbuoys.palette")`, falling back to `"okabe_ito"`.
#'
#' @return A single string.
#' @examples
#' ib_default_palette()
#' @export
ib_default_palette <- function() {
  getOption("irishbuoys.palette", "okabe_ito")
}

#' Get a colour palette preset
#'
#' @param name Preset name, one of [ib_palette_names()]. Defaults to the
#'   `irishbuoys.palette` option, then `"okabe_ito"`.
#'
#' @return An `ib_palette` list with `name`, `categorical` (12 colours),
#'   the colour groups `station`, `month`, `beaufort`, `time_of_day`,
#'   `return_period` and `rf_category` (named colour vectors), and `semantic`
#'   (named list: `threshold`, `extreme`, `primary`, `secondary`, `fit`,
#'   background and grid colours, and others).
#' @examples
#' pal <- ib_palette("okabe_ito")
#' pal$station
#' pal$semantic$threshold
#' @export
ib_palette <- function(name = ib_default_palette()) {
  if (!is.character(name) || length(name) != 1L || is.na(name)) {
    cli::cli_abort(c(
      "x" = "{.arg name} must be a single string.",
      "i" = "Available palettes: {.val {ib_palette_names()}}."
    ))
  }
  switch(name,
    okabe_ito = .ib_preset_okabe_ito(),
    viridis = .ib_preset_viridis(),
    classic = .ib_preset_classic(),
    cli::cli_abort(c(
      "x" = "Unknown palette {.val {name}}.",
      "i" = "Available palettes: {.val {ib_palette_names()}}."
    ))
  )
}

#' Colours for the levels of a category
#'
#' @description
#' Returns one colour per requested level from a palette colour group. Levels
#' the group does not know (for example a new station) get the next unused
#' colours of the palette's categorical series.
#'
#' @param palette An `ib_palette` from [ib_palette()].
#' @param group One of `"station"`, `"month"`, `"beaufort"`, `"time_of_day"`,
#'   `"return_period"`, `"rf_category"`.
#' @param levels Character vector of level names.
#'
#' @return Named character vector of colours, in the order of `levels`.
#' @examples
#' ib_group_colors(ib_palette(), "station", c("M2", "M9"))
#' @export
ib_group_colors <- function(palette, group, levels) {
  if (!inherits(palette, "ib_palette")) {
    cli::cli_abort(c(
      "x" = "{.arg palette} must be an {.cls ib_palette}.",
      "i" = "Create one with {.fn ib_palette}."
    ))
  }
  if (!is.character(group) || length(group) != 1L || !group %in% .ib_colour_groups) {
    available <- .ib_colour_groups
    cli::cli_abort(c(
      "x" = "Unknown colour group {.val {group}}.",
      "i" = "Available groups: {.val {available}}."
    ))
  }
  levels <- as.character(levels)
  known <- palette[[group]]
  out <- known[levels]
  missing_lv <- is.na(out)
  if (any(missing_lv)) {
    pool <- setdiff(palette$categorical, unname(known))
    out[missing_lv] <- rep_len(pool, sum(missing_lv))
  }
  names(out) <- levels
  out
}

#' Add an alpha channel to a colour
#'
#' @param col Colour(s) as hex strings or R colour names.
#' @param alpha Opacity between 0 and 1.
#'
#' @return Hex colour(s) in `#RRGGBBAA` form, which plotly and ggplot2 accept.
#' @examples
#' ib_alpha("#112233", 0.5)
#' @export
ib_alpha <- function(col, alpha) {
  if (!is.numeric(alpha) || length(alpha) != 1L || is.na(alpha) || alpha < 0 || alpha > 1) {
    cli::cli_abort(c(
      "x" = "{.arg alpha} must be a single number between 0 and 1.",
      "i" = "Got {.val {alpha}}."
    ))
  }
  m <- grDevices::col2rgb(col)
  grDevices::rgb(m[1, ], m[2, ], m[3, ], alpha = round(alpha * 255), maxColorValue = 255)
}

# --- Per-figure palette menu --------------------------------------------------

# Flatten a plotly list into the colour leaves it holds. Returns a named list:
# names are restyle/relayout paths ("marker.color", "shapes[0].line.color").
.ib_colour_leaves <- function(x, path = "") {
  colour_keys <- c("color", "fillcolor", "colorscale")
  out <- list()
  if (!is.list(x) || is.data.frame(x)) {
    return(out)
  }
  nms <- names(x)
  for (i in seq_along(x)) {
    named <- !is.null(nms) && !is.na(nms[i]) && nzchar(nms[i])
    child_path <- if (named) {
      if (nzchar(path)) paste0(path, ".", nms[i]) else nms[i]
    } else {
      paste0(path, "[", i - 1L, "]")
    }
    if (named && nms[i] %in% colour_keys) {
      out[[child_path]] <- x[[i]]
    } else if (is.list(x[[i]])) {
      out <- c(out, .ib_colour_leaves(x[[i]], child_path))
    }
  }
  out
}

#' Add a palette dropdown to a plotly figure
#'
#' @description
#' Adds an `updatemenus` dropdown with one button per preset. Choosing a
#' preset restyles the colours of the traces, shapes and annotations in the
#' browser, with no R round trip.
#'
#' The colours come from the figures themselves: `presets` holds one figure per
#' preset, each built with that preset by the same plotting code, so every
#' colour on a figure is whatever the plot function chose from the palette.
#' The buttons set the differences between those figures.
#'
#' @param p The plotly figure to show (normally `presets[[selected]]`).
#' @param presets Named list of plotly figures, one per preset, in dropdown
#'   order. All must have the same number of traces.
#' @param selected Name of the preset that `p` is drawn with.
#'
#' @return `p` with an `updatemenus` entry added.
#' @examples
#' \dontrun{
#' mk <- function(col) plotly::plot_ly(
#'   x = 1:3, y = 1:3, type = "scatter", mode = "markers", marker = list(color = col)
#' )
#' presets <- list(okabe_ito = mk("#E69F00"), classic = mk("#E41A1C"))
#' add_palette_menu(presets$okabe_ito, presets)
#' }
#' @export
add_palette_menu <- function(p, presets, selected = names(presets)[1]) {
  nms <- names(presets)
  if (!is.list(presets) || length(presets) < 2L || is.null(nms) || anyNA(nms) || !all(nzchar(nms))) {
    cli::cli_abort(c(
      "x" = "{.arg presets} must be a named list of at least two plotly figures.",
      "i" = "Names are the dropdown labels, for example {.code ib_palette_names()}."
    ))
  }
  if (!inherits(p, "plotly") || !all(vapply(presets, inherits, logical(1), what = "plotly"))) {
    cli::cli_abort(c(
      "x" = "{.arg p} and every element of {.arg presets} must be plotly objects."
    ))
  }
  if (!is.character(selected) || length(selected) != 1L || !selected %in% nms) {
    cli::cli_abort(c(
      "x" = "{.arg selected} must be one of the names of {.arg presets}.",
      "i" = "Names: {.val {nms}}."
    ))
  }

  built <- lapply(presets, plotly::plotly_build)
  n_traces <- vapply(built, function(b) length(b$x$data), integer(1))
  if (length(unique(n_traces)) != 1L) {
    cli::cli_abort(c(
      "x" = "All {.arg presets} must have the same number of traces.",
      "i" = "Trace counts: {.val {n_traces}}."
    ))
  }

  # Colour leaves per preset: traces (list of named lists) and layout.
  trace_leaves <- lapply(built, function(b) lapply(b$x$data, .ib_colour_leaves))
  layout_leaves <- lapply(built, function(b) .ib_colour_leaves(b$x$layout))

  trace_keys <- unique(unlist(lapply(trace_leaves, function(pt) lapply(pt, names))))
  per_key <- lapply(trace_keys, function(k) {
    lapply(trace_leaves, function(pt) lapply(pt, function(tr) tr[[k]]))
  })
  names(per_key) <- trace_keys
  changed_trace_keys <- Filter(function(k) {
    v <- per_key[[k]]
    !all(vapply(v[-1], identical, logical(1), y = v[[1]]))
  }, trace_keys)

  layout_keys <- unique(unlist(lapply(layout_leaves, names)))
  changed_layout_keys <- Filter(function(k) {
    v <- lapply(layout_leaves, function(l) l[[k]])
    !all(vapply(v[-1], identical, logical(1), y = v[[1]]))
  }, layout_keys)

  # Named empty lists serialise to {} (a plain list() would become []).
  empty_obj <- stats::setNames(list(), character(0))
  buttons <- lapply(nms, function(nm) {
    restyle <- empty_obj
    for (k in changed_trace_keys) {
      # NA serialises to JSON null, which restyle reads as "reset to default":
      # the right result for a trace that never had this attribute.
      restyle[[k]] <- lapply(per_key[[k]][[nm]], function(v) if (is.null(v)) NA else v)
    }
    relayout <- empty_obj
    for (k in changed_layout_keys) {
      relayout[[k]] <- layout_leaves[[nm]][[k]]
    }
    list(
      method = "update",
      label = nm,
      args = list(restyle, relayout)
    )
  })

  st <- .ib_structural
  plotly::layout(
    p,
    updatemenus = list(list(
      type = "dropdown",
      direction = "down",
      active = match(selected, nms) - 1L,
      buttons = buttons,
      x = 1, xanchor = "right",
      y = 1.12, yanchor = "top",
      bgcolor = st$dark_strip,
      bordercolor = st$grid_line,
      font = list(color = st$text_strong, size = 11),
      showactive = TRUE
    ))
  )
}

# Build a figure with every preset and attach the palette menu. `build` takes
# an ib_palette and returns a plotly figure (or NULL for "nothing to draw").
.ib_palette_figure <- function(palette, build) {
  if (!is.character(palette) || length(palette) != 1L || is.na(palette)) {
    cli::cli_abort(c(
      "x" = "{.arg palette} must be a single string.",
      "i" = "Available palettes: {.val {ib_palette_names()}}."
    ))
  }
  selected <- ib_palette(palette)$name
  figs <- lapply(
    stats::setNames(ib_palette_names(), ib_palette_names()),
    function(nm) build(ib_palette(nm))
  )
  if (is.null(figs[[selected]])) {
    return(NULL)
  }
  add_palette_menu(figs[[selected]], figs, selected = selected)
}
