#' Exceedance plots: wave Manhattan and Q-Q
#'
#' @description
#' Design ideas from the qqman Manhattan and Q-Q plots (read for ideas only):
#' every buoy record gets a p-value from [p_hmax_exceedance()], the probability
#' that the largest of the record's N waves is at least as high as the
#' observed Hmax, given its Hs and mean period. Under the model these p-values
#' are uniform, so the plots show where the data depart from it.
#'
#' All colours come from the palette home ([ib_palette()]).
#'
#' @name plot_exceedance
#' @keywords internal
NULL

# --- Station blocks ----------------------------------------------------------

# Lay the stations out side by side along x, qqman-style: one block per
# station, time running left to right inside a block, in days since that
# station's first record. Returns the block table (start, end, centre, shade)
# and each station's first time.
.ib_station_blocks <- function(station_id, time, gap_frac = 0.03) {
  stations <- sort(unique(station_id))
  secs <- as.numeric(time)
  t0 <- vapply(stations, function(s) min(secs[station_id == s]), numeric(1))
  t1 <- vapply(stations, function(s) max(secs[station_id == s]), numeric(1))
  width <- pmax((t1 - t0) / 86400, 1)
  gap <- gap_frac * sum(width)
  start <- c(0, cumsum(width + gap))[seq_along(stations)]
  list(
    blocks = data.frame(
      station_id = stations, start = start, end = start + width,
      centre = start + width / 2,
      shade = seq_along(stations) %% 2L == 0L,
      stringsAsFactors = FALSE
    ),
    t0 = t0,
    gap = gap
  )
}

# x position of each record: its block start plus days since the station's
# first record.
.ib_block_x <- function(layout, station_id, time) {
  idx <- match(station_id, layout$blocks$station_id)
  layout$blocks$start[idx] + (as.numeric(time) - layout$t0[idx]) / 86400
}

# Rectangles shading every other station block.
.ib_block_shapes <- function(layout, st) {
  b <- layout$blocks[layout$blocks$shade, , drop = FALSE]
  lapply(seq_len(nrow(b)), function(i) {
    list(
      type = "rect", xref = "x", yref = "paper",
      x0 = b$start[i] - layout$gap / 2, x1 = b$end[i] + layout$gap / 2,
      y0 = 0, y1 = 1,
      fillcolor = ib_alpha(st$grid_base, 0.08),
      line = list(width = 0), layer = "below"
    )
  })
}

# The x axis of the block layout: station names at the block centres.
.ib_block_xaxis <- function(layout) {
  list(
    title = "Station (time runs left to right within each block)",
    tickmode = "array",
    tickvals = layout$blocks$centre,
    ticktext = layout$blocks$station_id,
    showgrid = FALSE,
    range = c(
      min(layout$blocks$start) - layout$gap / 2,
      max(layout$blocks$end) + layout$gap / 2
    )
  )
}

# A caption under the plot (plotly has no caption of its own); the text is
# wrapped with <br>.
.ib_caption_annotation <- function(text, st) {
  list(
    xref = "paper", yref = "paper", x = 0, y = -0.3,
    xanchor = "left", yanchor = "top", showarrow = FALSE,
    align = "left",
    text = paste(strwrap(text, width = 120), collapse = "<br>"),
    font = list(color = st$dark_text, size = 10)
  )
}

# Label for the top event of each station: an arrow pointing at the point.
.ib_top_event_annotations <- function(x, y, label, y_cap, st) {
  lapply(seq_along(x), function(i) {
    at_cap <- !is.null(y_cap) && y[i] >= y_cap
    list(
      x = x[i], y = y[i], text = label[i],
      showarrow = TRUE, arrowhead = 2, arrowsize = 0.8,
      arrowcolor = st$neutral_light,
      ax = 0, ay = if (at_cap) 28 else -28,
      font = list(color = st$text_strong, size = 10),
      bgcolor = st$dark_bg
    )
  })
}

# --- Manhattan ---------------------------------------------------------------

#' Create the wave exceedance Manhattan plot
#'
#' @description
#' One point per buoy record: x is time, with the stations laid out as blocks
#' (alternating shading); y is `-log10(p)`, where `p` comes from
#' [p_hmax_exceedance()] for the record's Hmax, Hs and mean period, with N =
#' [ib_record_duration_s()] / mean period waves.
#'
#' Two threshold lines mark the Hmax/Hs = 2.0 (rogue) and 2.2 (extreme)
#' definitions for a typical record (the median mean period). Their positions
#' are computed by calling [p_hmax_exceedance()], not typed. The y axis is
#' capped at `y_cap`: points above it are drawn as triangles at the cap and
#' their true value is in the hover text. The top event of each station is
#' labelled. Records the quality-control flag marks as suspect (`qc_flag` other
#' than 0 or 1) are drawn hollow and grey, never dropped; see issue #114.
#'
#' The x axis is a station-block layout, not a calendar axis: each station's
#' block is its own time span (days since that station's first record), so a
#' date range slider with a "last 3 months" window has no single meaning
#' across blocks and the figure has none. The dates are in the hover text; for
#' a time axis with a range slider see [create_plot_rogue_gusts_all()].
#'
#' Only records with `-log10(p) >= min_nlog10_p` are drawn, which keeps the
#' figure small; the title gives the counts. The caption reports the data
#' checks: rows dropped for NA, Hmax < Hs and Hmax/Hs > 3.
#'
#' @param data Data frame of buoy records with `time`, `station_id`,
#'   `wave_height` (Hs, m), `hmax` (m) and `wave_period` (mean period, s);
#'   optionally `qc_flag`.
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @param y_cap Upper limit of the y axis, in `-log10(p)` units.
#' @param min_nlog10_p Records below this `-log10(p)` are not drawn.
#' @param duration_s Record duration in seconds; default [ib_record_duration_s()].
#' @return plotly object, or `NULL` when there are no usable records.
#' @export
#' @family plots
#' @examples
#' \dontrun{
#' d <- data.frame(
#'   time = seq(as.POSIXct("2024-01-01", tz = "UTC"), by = "hour", length.out = 40),
#'   station_id = rep(c("M2", "M3"), 20),
#'   wave_height = 3, hmax = 3 * seq(1.5, 2.3, length.out = 40),
#'   wave_period = 8
#' )
#' create_plot_wave_manhattan(d)
#' }
create_plot_wave_manhattan <- function(data, palette = ib_default_palette(),
                                       y_cap = 20, min_nlog10_p = 1,
                                       duration_s = ib_record_duration_s()) {
  if (is.null(data) || nrow(data) == 0L) {
    return(NULL)
  }
  prep <- .ib_exceedance_prep(data, duration_s)
  d <- prep$data
  if (nrow(d) == 0L) {
    return(NULL)
  }

  stations <- sort(unique(d$station_id))
  lay <- .ib_station_blocks(d$station_id, d$time)
  d$x <- .ib_block_x(lay, d$station_id, d$time)
  d$y <- pmin(d$nlog10_p, y_cap)
  d$capped <- d$nlog10_p > y_cap
  d$hover <- paste0(
    "Station: ", d$station_id, "<br>",
    "Time: ", format(d$time, "%Y-%m-%d %H:%M"), "<br>",
    "Hs: ", round(d$wave_height, 2), " m<br>",
    "Hmax: ", round(d$hmax, 2), " m<br>",
    "Hmax/Hs: ", sprintf("%.2f", d$ratio), "<br>",
    "Mean period: ", round(d$wave_period, 1), " s (N = ",
    round(d$n_waves), " waves)<br>",
    "-log10(p): ", sprintf("%.2f", d$nlog10_p),
    ifelse(d$capped, " (above the axis cap)", ""), "<br>",
    ifelse(d$suspect, "QC flag: suspect", "QC flag: passed")
  )

  # Threshold lines: the p of Hmax/Hs = 2.0 and 2.2 for a typical record.
  ratios <- ib_rogue_ratio_thresholds()
  typical_tz <- stats::median(d$wave_period)
  thr_p <- p_hmax_exceedance(
    unname(ratios), hs = 1, tz = typical_tz, duration_s = duration_s
  )
  thr_y <- -log10(thr_p)

  shown <- d[d$nlog10_p >= min_nlog10_p, , drop = FALSE]
  tops <- do.call(rbind, lapply(stations, function(s) {
    ds <- d[d$station_id == s, , drop = FALSE]
    ds[which.max(ds$nlog10_p), , drop = FALSE]
  }))
  tops <- tops[tops$nlog10_p >= min_nlog10_p, , drop = FALSE]

  classes <- list(
    list(suspect = FALSE, capped = FALSE, symbol = "circle", size = 7),
    list(suspect = FALSE, capped = TRUE, symbol = "triangle-up", size = 11),
    list(suspect = TRUE, capped = FALSE, symbol = "circle-open", size = 7),
    list(suspect = TRUE, capped = TRUE, symbol = "triangle-up-open", size = 11)
  )

  title <- paste0(
    "Wave exceedance Manhattan: ", format(nrow(shown), big.mark = ","),
    " of ", format(nrow(d), big.mark = ","), " records with -log10(p) >= ",
    min_nlog10_p, " (", format(min(d$time), "%Y-%m-%d"), " to ",
    format(max(d$time), "%Y-%m-%d"), ")"
  )

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    cols <- ib_group_colors(pal, "station", stations)
    p <- plotly::plot_ly(height = 600)
    for (s in stations) {
      legend_done <- FALSE
      for (cl in classes) {
        rows <- shown[shown$station_id == s & shown$suspect == cl$suspect &
                        shown$capped == cl$capped, , drop = FALSE]
        if (nrow(rows) == 0L) next
        col <- if (cl$suspect) st$neutral_light else cols[[s]]
        marker <- list(symbol = cl$symbol, size = cl$size, opacity = 0.8, color = col)
        if (cl$suspect) {
          marker$line <- list(color = col, width = 1.5)
        }
        p <- plotly::add_trace(
          p, x = rows$x, y = rows$y, type = "scatter", mode = "markers",
          name = s, legendgroup = s, showlegend = !legend_done,
          marker = marker, text = rows$hover, hoverinfo = "text"
        )
        legend_done <- TRUE
      }
    }

    lines <- lapply(seq_along(thr_y), function(i) {
      list(
        type = "line", xref = "x", yref = "y",
        x0 = min(lay$blocks$start) - lay$gap / 2,
        x1 = max(lay$blocks$end) + lay$gap / 2,
        y0 = thr_y[i], y1 = thr_y[i],
        line = list(
          color = if (i == 1L) st$threshold else st$extreme,
          dash = "dash", width = 2
        )
      )
    })
    line_labels <- lapply(seq_along(thr_y), function(i) {
      list(
        x = max(lay$blocks$end), y = thr_y[i],
        text = paste0(
          "Hmax/Hs = ", format(unname(ratios)[i], nsmall = 1),
          " (p = ", format(thr_p[i], digits = 2), ")"
        ),
        showarrow = FALSE, xanchor = "right", yanchor = "bottom",
        font = list(
          color = if (i == 1L) st$threshold else st$extreme, size = 10
        )
      )
    })
    top_labels <- .ib_top_event_annotations(
      tops$x, tops$y,
      paste0(
        tops$station_id, ": Hmax/Hs ", sprintf("%.2f", tops$ratio),
        ifelse(tops$suspect, " (QC suspect)", "")
      ),
      y_cap, st
    )

    p |>
      irishbuoys_layout(
        title = title,
        xaxis = .ib_block_xaxis(lay),
        yaxis = list(title = "-log10(p)", range = c(0, y_cap * 1.1)),
        shapes = c(.ib_block_shapes(lay, st), lines),
        annotations = c(
          line_labels, top_labels,
          list(.ib_caption_annotation(prep$caption, st))
        )
      ) |>
      plotly::layout(margin = list(b = 170))
  })
}

# --- Q-Q ---------------------------------------------------------------------

# Observed against expected -log10(p) for one set of records, sorted from the
# most extreme, with a 95% band from the beta distribution of uniform order
# statistics. Long tables are thinned for plotting: the top `keep_top` ranks
# are all kept, the rest evenly spaced by rank.
.ib_qq_table <- function(df, max_points = 500L, keep_top = 200L) {
  n <- nrow(df)
  if (n == 0L) {
    return(data.frame(
      expected = numeric(0), observed = numeric(0),
      band_lo = numeric(0), band_hi = numeric(0)
    ))
  }
  observed <- sort(df$nlog10_p, decreasing = TRUE)
  p_exp <- stats::ppoints(n)
  rank_i <- if (n <= max_points) {
    seq_len(n)
  } else {
    top <- seq_len(min(keep_top, max_points %/% 2L))
    rest <- round(seq(length(top) + 1L, n, length.out = max_points - length(top)))
    sort(unique(c(top, rest)))
  }
  data.frame(
    expected = -log10(p_exp[rank_i]),
    observed = observed[rank_i],
    band_lo = -log10(stats::qbeta(0.975, rank_i, n - rank_i + 1)),
    band_hi = -log10(stats::qbeta(0.025, rank_i, n - rank_i + 1))
  )
}

#' Create the wave exceedance Q-Q plot
#'
#' @description
#' Observed against expected `-log10(p)` per station, with a 95% band (from the
#' distribution of uniform order statistics). Under the model of
#' [p_hmax_exceedance()] the per-record p-values are uniform, so points on the
#' diagonal mean the model fits; an upward tail means more extreme waves than
#' the model predicts, and a station far off the line points to sensor faults
#' (see issue #114).
#'
#' Reference lines: the diagonal is the Forristall model itself; the Rayleigh
#' curve is the same records scored under the Rayleigh special case
#' (`alpha = 1 / sqrt(2)`, `beta = 2`), pooled over stations.
#'
#' Long stations are thinned for plotting (the whole upper tail is kept). All
#' records are used, including QC-suspect ones; the caption reports the data
#' checks.
#'
#' @inheritParams create_plot_wave_manhattan
#' @param max_points Most points drawn per station.
#' @return plotly object, or `NULL` when there are no usable records.
#' @export
#' @family plots
#' @examples
#' \dontrun{
#' d <- data.frame(
#'   time = seq(as.POSIXct("2024-01-01", tz = "UTC"), by = "hour", length.out = 40),
#'   station_id = rep(c("M2", "M3"), 20),
#'   wave_height = 3, hmax = 3 * seq(1.5, 2.3, length.out = 40),
#'   wave_period = 8
#' )
#' create_plot_exceedance_qq(d)
#' }
create_plot_exceedance_qq <- function(data, palette = ib_default_palette(),
                                      max_points = 500L,
                                      duration_s = ib_record_duration_s()) {
  if (is.null(data) || nrow(data) == 0L) {
    return(NULL)
  }
  prep <- .ib_exceedance_prep(data, duration_s)
  d <- prep$data
  if (nrow(d) == 0L) {
    return(NULL)
  }

  stations <- sort(unique(d$station_id))
  tables <- lapply(
    stats::setNames(stations, stations),
    function(s) .ib_qq_table(d[d$station_id == s, , drop = FALSE], max_points)
  )

  ray <- .ib_rayleigh()
  ray_fit <- .ib_hmax_exceed(
    d$hmax, d$wave_height, d$wave_period, duration_s, ray$alpha, ray$beta
  )
  ray_tab <- .ib_qq_table(
    data.frame(nlog10_p = -ray_fit$log_p / log(10)), max_points
  )
  x_max <- max(c(ray_tab$expected, vapply(tables, function(t) max(t$expected), numeric(1))))
  y_max <- max(c(ray_tab$observed, vapply(tables, function(t) max(t$observed), numeric(1))))

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    cols <- ib_group_colors(pal, "station", stations)
    p <- plotly::plot_ly(height = 600)
    for (s in stations) {
      tb <- tables[[s]]
      p <- plotly::add_trace(
        p, x = c(tb$expected, rev(tb$expected)),
        y = c(tb$band_hi, rev(tb$band_lo)),
        type = "scatter", mode = "lines", fill = "toself",
        fillcolor = ib_alpha(cols[[s]], 0.18),
        line = list(width = 0), name = paste0("95% band (", s, ")"),
        legendgroup = s, showlegend = FALSE, hoverinfo = "skip"
      )
    }
    p <- plotly::add_trace(
      p, x = c(0, x_max), y = c(0, x_max), type = "scatter", mode = "lines",
      name = "Forristall (model: observed = expected)",
      line = list(color = st$reference, dash = "dash", width = 2),
      hoverinfo = "name"
    )
    p <- plotly::add_trace(
      p, x = ray_tab$expected, y = ray_tab$observed, type = "scatter",
      mode = "lines", name = "Rayleigh (same records, all stations)",
      line = list(color = st$extreme, dash = "dot", width = 2),
      hoverinfo = "name"
    )
    for (s in stations) {
      tb <- tables[[s]]
      p <- plotly::add_trace(
        p, x = tb$expected, y = tb$observed, type = "scatter", mode = "markers",
        name = s, legendgroup = s,
        marker = list(color = cols[[s]], size = 6, opacity = 0.8),
        text = paste0(
          "Station: ", s, "<br>Expected -log10(p): ", sprintf("%.2f", tb$expected),
          "<br>Observed -log10(p): ", sprintf("%.2f", tb$observed)
        ),
        hoverinfo = "text"
      )
    }
    p |>
      irishbuoys_layout(
        title = "Wave exceedance Q-Q plot: observed against expected -log10(p), shaded 95% band per station",
        xaxis = list(title = "Expected -log10(p)", range = c(0, x_max * 1.05)),
        yaxis = list(title = "Observed -log10(p)", range = c(0, y_max * 1.05)),
        annotations = list(.ib_caption_annotation(prep$caption, st))
      ) |>
      plotly::layout(margin = list(b = 170))
  })
}
