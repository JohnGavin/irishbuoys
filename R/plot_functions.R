#' Plot Creation Functions for Wave Analysis Dashboard
#'
#' @description
#' Functions that create plotly objects for the wave analysis vignette.
#' Each function returns a plotly object that can be stored as a target.
#'
#' Every colour comes from a palette preset (see [ib_palette()]); no colour is
#' typed in this file. Each plotly figure carries a dropdown
#' ([add_palette_menu()]) that restyles it between the presets in the browser.
#' Wind and gust speeds are in knots (ERDDAP metadata, [get_data_dictionary()]).
#'
#' @name plot_functions
#' @keywords internal
NULL

#' Create Rogue Wave All Stations Plot
#'
#' @param rogue_events Data frame of rogue wave events
#' @param palette Name of a palette preset, see [ib_palette_names()].
#'   Defaults to [ib_default_palette()].
#' @return plotly object
#' @examples
#' \dontrun{
#' rogue <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:10) * 3600,
#'   station_id = rep(c("M2", "M3"), 5),
#'   rogue_ratio = runif(10, 2.0, 2.5),
#'   hmax = runif(10, 8, 15), wave_height = runif(10, 3, 6),
#'   wind_speed = runif(10, 10, 30), gust = runif(10, 15, 45)
#' )
#' create_plot_rogue_all(rogue)
#' }
#' @export
create_plot_rogue_all <- function(rogue_events, palette = ib_default_palette()) {
  if (is.null(rogue_events) || nrow(rogue_events) == 0) {
    return(NULL)
  }

  stations <- sort(unique(rogue_events$station_id))

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    plotly::plot_ly(
      rogue_events,
      x = ~time, y = ~rogue_ratio, color = ~station_id,
      colors = ib_group_colors(pal, "station", stations),
      type = "scatter", mode = "markers",
      marker = list(size = 8, opacity = 0.7),
      text = ~paste0(
        "Station: ", station_id, "<br>",
        "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
        "Rogue Ratio: ", round(rogue_ratio, 3), "<br>",
        "Hmax: ", round(hmax, 2), " m<br>",
        "Hs: ", round(wave_height, 2), " m<br>",
        "Wind: ", round(wind_speed, 1), " kn<br>",
        "Gust: ", round(gust, 1), " kn"
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0(
          "All Rogue Wave Events (n=", nrow(rogue_events), ", ",
          format(min(rogue_events$time), "%Y-%m-%d"), " to ",
          format(max(rogue_events$time), "%Y-%m-%d"), ")"
        ),
        xaxis = list(
          title = "Time",
          rangeslider = list(type = "date", thickness = 0.05)
        ),
        yaxis = list(title = "Hmax / Hs Ratio"),
        shapes = list(
          list(
            type = "line",
            x0 = min(rogue_events$time), x1 = max(rogue_events$time),
            y0 = 2.0, y1 = 2.0,
            line = list(color = st$threshold, dash = "dash", width = 2)
          ),
          list(
            type = "line",
            x0 = min(rogue_events$time), x1 = max(rogue_events$time),
            y0 = 2.2, y1 = 2.2,
            line = list(color = st$extreme, dash = "dot", width = 1.5)
          )
        ),
        annotations = list(
          list(
            x = max(rogue_events$time), y = 2.0,
            text = "Rogue threshold (2.0)",
            showarrow = FALSE, xanchor = "right", yanchor = "bottom",
            font = list(color = st$threshold, size = 10)
          ),
          list(
            x = max(rogue_events$time), y = 2.2,
            text = "Severe (2.2)",
            showarrow = FALSE, xanchor = "right", yanchor = "bottom",
            font = list(color = st$extreme, size = 10)
          )
        )
      )
  })
}

#' Create Rogue Wave By Station Subplot
#'
#' @param rogue_events Data frame of rogue wave events
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' rogue <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:10) * 3600,
#'   station_id = rep(c("M2", "M3"), 5),
#'   rogue_ratio = runif(10, 2.0, 2.5),
#'   hmax = runif(10, 8, 15), wave_height = runif(10, 3, 6),
#'   wind_speed = runif(10, 10, 30)
#' )
#' create_plot_rogue_by_station(rogue)
#' }
#' @export
create_plot_rogue_by_station <- function(rogue_events, date_caption = NULL,
                                         palette = ib_default_palette()) {
  if (is.null(rogue_events) || nrow(rogue_events) == 0) {
    return(NULL)
  }

  if (is.null(date_caption)) {
    date_caption <- paste0(
      format(min(rogue_events$time), "%Y-%m-%d"), " to ",
      format(max(rogue_events$time), "%Y-%m-%d")
    )
  }

  stations <- sort(unique(rogue_events$station_id))

  .ib_palette_figure(palette, function(pal) {
    station_colors <- ib_group_colors(pal, "station", stations)

    plots <- lapply(seq_along(stations), function(i) {
      st <- stations[i]
      d <- rogue_events[rogue_events$station_id == st, ]
      n_st <- nrow(d)

      plotly::plot_ly(
        d, x = ~time, y = ~hmax,
        type = "scatter", mode = "markers",
        marker = list(
          size = 8, opacity = 0.85,
          color = station_colors[[st]],
          line = list(width = 0.5, color = ib_alpha(pal$semantic$text_strong, 0.3))
        ),
        text = ~paste0(
          "Station: ", station_id, "<br>",
          "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
          "Hmax: ", round(hmax, 2), " m<br>",
          "Hs: ", round(wave_height, 2), " m<br>",
          "Ratio: ", round(rogue_ratio, 3), "<br>",
          "Wind: ", round(wind_speed, 1), " kn"
        ),
        hoverinfo = "text",
        showlegend = FALSE
      ) |>
        plotly::layout(
          annotations = list(list(
            text = paste0("<b>", st, "</b> (n=", n_st, ")"),
            x = 0.02, y = 0.95, xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 13, color = station_colors[[st]])
          )),
          yaxis = list(title = "Hmax (m)")
        )
    })

    plotly::subplot(plots, nrows = length(stations), shareX = TRUE, titleY = TRUE) |>
      irishbuoys_layout(
        title = paste0("Rogue Wave Events by Station (n=", nrow(rogue_events), ", ", date_caption, ")"),
        height = length(stations) * 350,  # Triple height for better y-axis readability
        xaxis = list(
          title = "Time",
          rangeslider = list(type = "date", thickness = 0.05)
        )
      )
  })
}

#' Create Rogue Wave Plot for One Station
#'
#' @description
#' Hmax / Hs ratio over time for a single station. Replaces the five inline
#' per-station figures of the wave analysis vignette. Returns an empty figure
#' (no palette menu, because there is nothing to colour) when the station has
#' no events.
#'
#' @param rogue_events Data frame of rogue wave events with `station_id`,
#'   `time`, `rogue_ratio`, `hmax` and `wave_height`.
#' @param station Single station id, for example `"M2"`.
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' create_plot_rogue_station(rogue_events, "M2")
#' }
#' @export
create_plot_rogue_station <- function(rogue_events, station,
                                      palette = ib_default_palette()) {
  if (!is.character(station) || length(station) != 1L || is.na(station)) {
    cli::cli_abort(c(
      "x" = "{.arg station} must be a single station id.",
      "i" = "For example {.val M2}."
    ))
  }
  if (is.null(rogue_events) || nrow(rogue_events) == 0 ||
      !station %in% rogue_events$station_id) {
    return(plotly::plotly_empty() |>
      plotly::layout(title = paste0(station, ": No data")))
  }

  d <- rogue_events[rogue_events$station_id == station, ]

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      d, x = ~time, y = ~rogue_ratio, type = "scatter", mode = "markers",
      marker = list(size = 8, color = ib_group_colors(pal, "station", station)[[1]]),
      hoverinfo = "text",
      text = ~paste0(
        "Time: ", format(time, "%Y-%m-%d %H:%M"),
        "<br>Ratio: ", round(rogue_ratio, 2),
        "<br>Max Wave: ", round(hmax, 1), "m",
        "<br>Signif Wave: ", round(wave_height, 1), "m"
      )
    ) |>
      irishbuoys_layout(
        title = paste0(station, " Rogue Events (n=", nrow(d), ")"),
        xaxis = list(title = "Time"), yaxis = list(title = "Rogue Ratio"),
        hovermode = "closest"
      )
  })
}

#' Create Wind Speed by Beaufort Scale Plot
#'
#' @param rogue_conditions Data frame with rogue wave conditions
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' conditions <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:10) * 3600,
#'   station_id = rep(c("M2", "M3"), 5),
#'   wind_speed = runif(10, 5, 35),
#'   rogue_ratio = runif(10, 2.0, 2.5),
#'   hmax = runif(10, 8, 15), wave_height = runif(10, 3, 6)
#' )
#' create_plot_wind_beaufort(conditions)
#' }
#' @export
create_plot_wind_beaufort <- function(rogue_conditions, date_caption = NULL,
                                      palette = ib_default_palette()) {
  if (is.null(rogue_conditions) || !"wind_speed" %in% names(rogue_conditions)) {
    return(NULL)
  }

  if (is.null(date_caption)) {
    date_caption <- paste0(
      format(min(rogue_conditions$time), "%Y-%m-%d"), " to ",
      format(max(rogue_conditions$time), "%Y-%m-%d")
    )
  }

  # Classify Beaufort
  classify_beaufort <- function(ws) {
    cut(ws,
      breaks = c(-Inf, 10.7, 17.1, 24.4, 28.4, 32.6, Inf),
      labels = c(
        "0-5 (Calm-Fresh)", "6-7 (Strong-Near Gale)",
        "8-9 (Gale-Severe)", "10 (Storm)",
        "11 (Violent Storm)", "12 (Hurricane)"
      ),
      right = TRUE
    )
  }

  rc <- rogue_conditions
  rc$beaufort <- classify_beaufort(rc$wind_speed)

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    plotly::plot_ly(
      rc, x = ~wind_speed, y = ~rogue_ratio, color = ~beaufort,
      colors = pal$beaufort,
      type = "scatter", mode = "markers",
      marker = list(size = 10, opacity = 0.8, line = list(width = 1, color = st$marker_outline)),
      text = ~paste0(
        "Station: ", station_id, "<br>",
        "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
        "Wind: ", round(wind_speed, 1), " kn<br>",
        "Beaufort: ", beaufort, "<br>",
        "Rogue Ratio: ", round(rogue_ratio, 3), "<br>",
        "Hmax: ", round(hmax, 2), " m<br>",
        "Hs: ", round(wave_height, 2), " m"
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Rogue Waves by Wind Speed (", date_caption, ")"),
        xaxis = list(title = "Wind Speed (kn)"),
        yaxis = list(title = "Hmax / Hs Ratio"),
        shapes = list(
          list(
            type = "line",
            x0 = 0, x1 = max(rc$wind_speed, na.rm = TRUE) * 1.05,
            y0 = 2.0, y1 = 2.0,
            line = list(color = st$threshold, dash = "dash", width = 2)
          )
        )
      )
  })
}

#' Create Week of Year Stacked Bar Plot
#'
#' @param rogue_conditions Data frame with rogue wave conditions
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' conditions <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:30) * 86400,
#'   rogue_ratio = runif(30, 2.0, 2.5),
#'   hmax = runif(30, 8, 15)
#' )
#' create_plot_week_of_year(conditions)
#' }
#' @export
create_plot_week_of_year <- function(rogue_conditions, date_caption = NULL,
                                     palette = ib_default_palette()) {
  if (is.null(rogue_conditions)) {
    return(NULL)
  }

  if (is.null(date_caption)) {
    date_caption <- paste0(
      format(min(rogue_conditions$time), "%Y-%m-%d"), " to ",
      format(max(rogue_conditions$time), "%Y-%m-%d")
    )
  }

  rc <- rogue_conditions
  rc$week <- as.integer(format(rc$time, "%V"))
  rc$month_name <- factor(format(rc$time, "%b"), levels = month.abb)

  week_counts <- rc |>
    dplyr::group_by(.data$week, .data$month_name) |>
    dplyr::summarise(
      n = dplyr::n(),
      mean_ratio = round(mean(.data$rogue_ratio, na.rm = TRUE), 2),
      max_hmax = round(max(.data$hmax, na.rm = TRUE), 1),
      .groups = "drop"
    )

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      week_counts, x = ~week, y = ~n, color = ~month_name,
      colors = pal$month,
      type = "bar",
      text = ~paste0(
        "Week ", week, "<br>",
        "Month: ", month_name, "<br>",
        "Rogue Events: ", n, "<br>",
        "Mean Ratio: ", mean_ratio, "<br>",
        "Max Hmax: ", max_hmax, " m"
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Rogue Wave Events by Week of Year (n=", nrow(rogue_conditions), ", ", date_caption, ")"),
        xaxis = list(title = "Week of Year", dtick = 2),
        yaxis = list(title = "Count of Rogue Events"),
        barmode = "stack"
      )
  })
}

#' Create Time of Day Bar Plot
#'
#' @param rogue_conditions Data frame with rogue wave conditions
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' conditions <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:20) * 3600,
#'   time_of_day = rep(c("Morning", "Afternoon", "Evening", "Night"), 5),
#'   rogue_ratio = runif(20, 2.0, 2.5)
#' )
#' create_plot_time_of_day(conditions)
#' }
#' @export
create_plot_time_of_day <- function(rogue_conditions, date_caption = NULL,
                                    palette = ib_default_palette()) {
  if (is.null(rogue_conditions) || !"time_of_day" %in% names(rogue_conditions)) {
    return(NULL)
  }

  if (is.null(date_caption)) {
    date_caption <- paste0(
      format(min(rogue_conditions$time), "%Y-%m-%d"), " to ",
      format(max(rogue_conditions$time), "%Y-%m-%d")
    )
  }

  rc <- rogue_conditions
  rc$time_of_day <- factor(rc$time_of_day, levels = c("Morning", "Afternoon", "Evening", "Night"))

  tod_data <- rc |>
    dplyr::group_by(.data$time_of_day) |>
    dplyr::summarise(
      n = dplyr::n(),
      hours = dplyr::case_when(
        .data$time_of_day[1] == "Morning" ~ "06:00-12:00",
        .data$time_of_day[1] == "Afternoon" ~ "12:00-18:00",
        .data$time_of_day[1] == "Evening" ~ "18:00-22:00",
        .data$time_of_day[1] == "Night" ~ "22:00-06:00"
      ),
      n_hours = dplyr::case_when(
        .data$time_of_day[1] == "Morning" ~ 6L,
        .data$time_of_day[1] == "Afternoon" ~ 6L,
        .data$time_of_day[1] == "Evening" ~ 4L,
        .data$time_of_day[1] == "Night" ~ 8L
      ),
      rate_per_hour = round(.data$n / .data$n_hours, 1),
      mean_ratio = round(mean(.data$rogue_ratio, na.rm = TRUE), 2),
      .groups = "drop"
    )

  total_events <- sum(tod_data$n)

  .ib_palette_figure(palette, function(pal) {
    tod_colors <- pal$time_of_day

    plotly::plot_ly(
      tod_data, x = ~time_of_day, y = ~n,
      type = "bar",
      marker = list(color = ~tod_colors[as.character(time_of_day)]),
      text = ~paste0(
        time_of_day, " (", hours, ")<br>",
        "Events: ", n, "<br>",
        "Rate: ", rate_per_hour, " events/hour<br>",
        "Mean Ratio: ", mean_ratio
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Rogue Waves by Time of Day (Total: ", total_events, " events, ", date_caption, ")"),
        xaxis = list(title = "Time of Day (hover for hours)"),
        yaxis = list(title = "Count"),
        annotations = list(list(
          text = paste0("Total: ", total_events, " rogue events"),
          x = 0.98, y = 0.98, xref = "paper", yref = "paper",
          showarrow = FALSE, font = list(color = pal$semantic$annotation, size = 11)
        ))
      )
  })
}

#' Create Monthly Wave Height Bar Plot
#'
#' @param seasonal_means_wave Seasonal means from calculate_seasonal_means
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' seasonal <- list(
#'   monthly = data.frame(
#'     month_name = month.abb,
#'     mean = runif(12, 1, 4),
#'     sd = runif(12, 0.3, 1.0)
#'   )
#' )
#' create_plot_monthly_wave(seasonal)
#' }
#' @export
create_plot_monthly_wave <- function(seasonal_means_wave, date_caption = NULL,
                                     palette = ib_default_palette()) {
  if (is.null(seasonal_means_wave) || !"monthly" %in% names(seasonal_means_wave)) {
    return(NULL)
  }

  monthly <- seasonal_means_wave$monthly
  monthly$month_name <- factor(monthly$month_name, levels = month.abb)

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      monthly, x = ~month_name, y = ~mean,
      type = "bar",
      marker = list(color = pal$semantic$primary),
      error_y = list(type = "data", array = ~sd, color = pal$semantic$neutral),
      text = ~paste0(
        "Month: ", month_name, "<br>",
        "Mean Hs: ", round(mean, 2), " m<br>",
        "SD: ", round(sd, 2), " m"
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Monthly Mean Wave Height", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
        xaxis = list(title = "Month"),
        yaxis = list(title = "Mean Hs (m)")
      )
  })
}

#' Create Monthly Wind Speed Bar Plot
#'
#' @param seasonal_means_wind Seasonal means from calculate_seasonal_means
#'   (wind speed in knots)
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' seasonal <- list(
#'   monthly = data.frame(
#'     month_name = month.abb,
#'     mean = runif(12, 5, 15),
#'     sd = runif(12, 1, 4)
#'   )
#' )
#' create_plot_monthly_wind(seasonal)
#' }
#' @export
create_plot_monthly_wind <- function(seasonal_means_wind, date_caption = NULL,
                                     palette = ib_default_palette()) {
  if (is.null(seasonal_means_wind) || !"monthly" %in% names(seasonal_means_wind)) {
    return(NULL)
  }

  monthly <- seasonal_means_wind$monthly
  monthly$month_name <- factor(monthly$month_name, levels = month.abb)

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      monthly, x = ~month_name, y = ~mean,
      type = "bar",
      marker = list(color = pal$semantic$secondary),
      error_y = list(type = "data", array = ~sd, color = pal$semantic$neutral),
      text = ~paste0(
        "Month: ", month_name, "<br>",
        "Mean Wind: ", round(mean, 2), " kn<br>",
        "SD: ", round(sd, 2), " kn"
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Monthly Mean Wind Speed", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
        xaxis = list(title = "Month"),
        yaxis = list(title = "Mean Wind Speed (kn)")
      )
  })
}

#' Create Annual Trends Line Plot
#'
#' @param annual_trends Annual trends from calculate_annual_trends
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' trends <- list(
#'   annual_stats = data.frame(
#'     year = 2018:2024,
#'     mean = runif(7, 1.5, 3.5),
#'     sd = runif(7, 0.3, 1.0)
#'   )
#' )
#' create_plot_annual_trends(trends)
#' }
#' @export
create_plot_annual_trends <- function(annual_trends, date_caption = NULL,
                                      palette = ib_default_palette()) {
  if (is.null(annual_trends) || !"annual_stats" %in% names(annual_trends)) {
    return(NULL)
  }

  annual <- annual_trends$annual_stats

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    plotly::plot_ly(
      annual, x = ~year, y = ~mean,
      type = "scatter", mode = "lines+markers",
      marker = list(size = 8, color = st$primary),
      line = list(color = st$primary),
      error_y = list(type = "data", array = ~sd, color = st$neutral_light),
      text = ~paste0(
        "Year: ", year, "<br>",
        "Mean Hs: ", round(mean, 2), " m<br>",
        "SD: ", round(sd, 2), " m"
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Annual Wave Height Trend", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
        xaxis = list(title = "Year"),
        yaxis = list(title = "Mean Hs (m)")
      )
  })
}

#' Create Return Levels Plot
#'
#' @param return_levels Return levels data frame
#' @param variable Variable name for title ("wave", "wind", or "hmax")
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' rl <- data.frame(
#'   return_period = c(1, 5, 10, 25, 50, 100),
#'   return_level = c(5.2, 7.1, 8.3, 9.8, 11.0, 12.5),
#'   lower = c(4.8, 6.3, 7.2, 8.1, 8.9, 9.6),
#'   upper = c(5.6, 7.9, 9.4, 11.5, 13.1, 15.4)
#' )
#' create_plot_return_levels(rl, variable = "wave")
#' }
#' @export
create_plot_return_levels <- function(return_levels, variable = "wave", date_caption = NULL,
                                      palette = ib_default_palette()) {
  if (is.null(return_levels)) {
    return(NULL)
  }

  titles <- list(
    wave = "Wave Height Return Levels - GEV",
    wind = "Wind Speed Return Levels - GEV",
    hmax = "Max Wave Height Return Levels - GEV"
  )
  y_labels <- list(
    wave = "Hs (m)",
    wind = "Wind Speed (kn)",
    hmax = "Hmax (m)"
  )
  title <- titles[[variable]]
  y_label <- y_labels[[variable]]

  .ib_palette_figure(palette, function(pal) {
    colors <- list(
      wave = pal$semantic$primary,
      wind = pal$semantic$secondary,
      hmax = pal$semantic$tertiary
    )
    col <- colors[[variable]]
    fill_col <- if (is.null(col)) NULL else ib_alpha(col, 0.2)

    plotly::plot_ly(
      return_levels, x = ~return_period, y = ~return_level,
      type = "scatter", mode = "lines+markers",
      marker = list(size = 8, color = col),
      line = list(color = col),
      text = ~paste0(
        "Return Period: ", return_period, " years<br>",
        y_label, ": ", round(return_level, 2), "<br>",
        "95% CI: [", round(lower, 2), ", ", round(upper, 2), "]"
      ),
      hoverinfo = "text",
      name = "Return Level"
    ) |>
      plotly::add_ribbons(
        ymin = ~lower, ymax = ~upper,
        fillcolor = fill_col,
        line = list(color = "transparent"),
        name = "95% CI", showlegend = TRUE
      ) |>
      irishbuoys_layout(
        title = paste0(title, if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
        xaxis = list(title = "Return Period (years)", type = "log"),
        yaxis = list(title = y_label)
      )
  })
}

#' Create Per-Station Return Levels Plot
#'
#' @description
#' Creates a horizontal dotplot showing GPD return levels by station for a
#' given variable, with error bars for confidence intervals. Text labels
#' at each point replace the legend for clarity.
#'
#' @param return_levels_df Data frame from `return_levels_per_station` target
#'   with columns: station, variable, return_period, return_level, lower, upper
#' @param variable_filter Character, which variable to plot (one of
#'   "avg_wave", "rogue_wave", "avg_wind", "wind_gust")
#' @param palette Name of a palette preset, see [ib_palette_names()].
#'
#' @return plotly object, or NULL if no data for the requested variable
#'
#' @examples
#' \dontrun{
#' rl_df <- data.frame(
#'   station = rep(c("M2", "M3", "M4"), each = 3),
#'   variable = "avg_wave",
#'   variable_label = "Avg Wave Height (m)",
#'   return_period = rep(c(1, 5, 10), 3),
#'   return_level = runif(9, 4, 12),
#'   lower = runif(9, 3, 8),
#'   upper = runif(9, 9, 16)
#' )
#' create_plot_return_levels_per_station(rl_df, "avg_wave")
#' }
#' @export
create_plot_return_levels_per_station <- function(return_levels_df, variable_filter,
                                                  palette = ib_default_palette()) {
  if (is.null(return_levels_df) || nrow(return_levels_df) == 0) {
    return(NULL)
  }

  d <- return_levels_df[return_levels_df$variable == variable_filter, ]
  d <- d[!is.na(d$return_level), ]

  if (nrow(d) == 0) {
    return(NULL)
  }

  label <- d$variable_label[1]

  d$period_label <- paste0(d$return_period, "-yr")
  d$period_label <- factor(d$period_label, levels = c("1-yr", "5-yr", "10-yr"))

  .ib_palette_figure(palette, function(pal) {
    period_colors <- pal$return_period

    p <- plotly::plot_ly()
    for (pl in levels(d$period_label)) {
      dp <- d[d$period_label == pl, ]
      col <- period_colors[[pl]]
      p <- p |> plotly::add_trace(
        data = dp, x = ~return_level, y = ~station,
        type = "scatter", mode = "markers+text",
        text = pl, textposition = "middle right",
        textfont = list(size = 11, color = col),
        marker = list(size = 6, color = col),
        error_x = list(
          type = "data", symmetric = FALSE,
          array = ~upper - return_level,
          arrayminus = ~return_level - lower,
          color = col, thickness = 1.5
        ),
        hovertext = ~paste0(
          station, " ", pl, ": ", round(return_level, 2),
          " [", round(lower, 2), ", ", round(upper, 2), "]"
        ),
        hoverinfo = "text", showlegend = FALSE
      )
    }
    p |> irishbuoys_layout(
      title = paste0("Per-Station Return Levels: ", label, " (GPD, 95th pct threshold)"),
      xaxis = list(title = label),
      yaxis = list(title = "")
    )
  })
}

#' Create Gust Factor by Category Plot
#'
#' @param gust_analysis Gust factor analysis results
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' gust <- list(
#'   by_station_category = data.frame(
#'     station_id = rep(c("M2", "M3"), each = 3),
#'     wind_category = rep(c("0-10", "10-20", "20+"), 2),
#'     mean_gf = runif(6, 1.1, 1.8),
#'     p95_gf = runif(6, 1.5, 2.5),
#'     n = sample(50:500, 6)
#'   )
#' )
#' create_plot_gust_by_category(gust)
#' }
#' @export
create_plot_gust_by_category <- function(gust_analysis, date_caption = NULL,
                                         palette = ib_default_palette()) {
  if (is.null(gust_analysis)) {
    return(NULL)
  }

  # Try by_station_category first, fallback to by_category
  if ("by_station_category" %in% names(gust_analysis) && !is.null(gust_analysis$by_station_category)) {
    gust_sc <- gust_analysis$by_station_category
    stations <- sort(unique(gust_sc$station_id))

    .ib_palette_figure(palette, function(pal) {
      st <- pal$semantic
      plotly::plot_ly(
        gust_sc, x = ~wind_category, y = ~mean_gf, color = ~station_id,
        colors = ib_group_colors(pal, "station", stations),
        type = "bar",
        text = ~paste0(
          "Station: ", station_id, "<br>",
          "Category: ", wind_category, "<br>",
          "Mean GF: ", round(mean_gf, 2), "<br>",
          "P95 GF: ", round(p95_gf, 2), "<br>",
          "n: ", n
        ),
        hoverinfo = "text"
      ) |>
        irishbuoys_layout(
          title = paste0("Gust Factor by Wind Category and Station", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
          xaxis = list(title = "Wind Speed Category (kn)"),
          yaxis = list(title = "Mean Gust Factor"),
          barmode = "group",
          shapes = list(
            list(
              type = "line", x0 = -0.5, x1 = 4.5,
              y0 = 1.3, y1 = 1.3,
              line = list(color = st$threshold, dash = "dash", width = 2)
            )
          ),
          annotations = list(
            list(
              x = 4, y = 1.3, text = "Typical (1.3)",
              showarrow = FALSE, yanchor = "bottom", font = list(color = st$threshold, size = 10)
            )
          )
        )
    })
  } else if ("by_category" %in% names(gust_analysis)) {
    gust_cat <- gust_analysis$by_category

    .ib_palette_figure(palette, function(pal) {
      st <- pal$semantic
      plotly::plot_ly(
        gust_cat, x = ~wind_category, y = ~mean_gf,
        type = "bar",
        marker = list(color = st$secondary),
        text = ~paste0(
          "Category: ", wind_category, "<br>",
          "Mean GF: ", round(mean_gf, 2), "<br>",
          "P95 GF: ", round(p95_gf, 2)
        ),
        hoverinfo = "text"
      ) |>
        irishbuoys_layout(
          title = paste0("Gust Factor by Wind Speed Category", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
          xaxis = list(title = "Wind Speed Category (kn)"),
          yaxis = list(title = "Gust Factor"),
          shapes = list(
            list(
              type = "line", x0 = -0.5, x1 = nrow(gust_cat) - 0.5,
              y0 = 1.3, y1 = 1.3,
              line = list(color = st$threshold, dash = "dash", width = 2)
            )
          ),
          annotations = list(
            list(
              x = nrow(gust_cat) - 1, y = 1.3, text = "Typical (1.3)",
              showarrow = FALSE, yanchor = "bottom", font = list(color = st$threshold, size = 10)
            )
          )
        )
    })
  } else {
    return(NULL)
  }
}

#' Create Rogue Gusts by Station Plot
#'
#' @param gust_analysis Gust factor analysis results
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' gust <- list(
#'   rogue_gust_threshold = 1.5,
#'   by_station = data.frame(
#'     station_id = c("M2", "M3", "M4"),
#'     n = c(1000, 800, 600),
#'     n_rogue = c(15, 12, 8),
#'     pct_rogue = c(1.5, 1.5, 1.3),
#'     mean_gf = c(1.25, 1.30, 1.22),
#'     max_gf = c(2.8, 3.1, 2.5)
#'   )
#' )
#' create_plot_rogue_gusts(gust)
#' }
#' @export
create_plot_rogue_gusts <- function(gust_analysis, palette = ib_default_palette()) {
  if (is.null(gust_analysis) ||
      !"by_station" %in% names(gust_analysis) ||
      is.null(gust_analysis$by_station)) {
    return(NULL)
  }

  bs <- gust_analysis$by_station

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      bs, x = ~station_id, y = ~pct_rogue,
      type = "bar",
      marker = list(
        color = ~n_rogue,
        colorscale = list(c(0, pal$semantic$scale_low), c(1, pal$semantic$scale_high)),
        showscale = TRUE,
        colorbar = list(title = "n events")
      ),
      text = ~paste0(
        "Station: ", station_id, "<br>",
        "Rogue Gusts: ", n_rogue, " (", round(pct_rogue, 3), "%)<br>",
        "Threshold: GF > ", round(gust_analysis$rogue_gust_threshold, 1), "<br>",
        "Total obs: ", n, "<br>",
        "Mean GF: ", round(mean_gf, 2), "<br>",
        "Max GF: ", round(max_gf, 2)
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0(
          "'Rogue Gust' Events by Station (GF > ",
          round(gust_analysis$rogue_gust_threshold, 1), ")"
        ),
        xaxis = list(title = "Station"),
        yaxis = list(title = "% of Observations")
      )
  })
}

#' Create STL Decomposition Plot
#'
#' @description
#' A ggplot2 figure, so it has no in-browser palette menu; its colours still
#' come from the chosen preset.
#'
#' @param wave_stl STL decomposition from calculate_wave_seasonality
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return ggplot2 object
#' @examples
#' \dontrun{
#' stl_data <- list(
#'   components = data.frame(
#'     time = as.POSIXct("2024-01-01") + (1:100) * 86400,
#'     original = sin(1:100 / 10) + rnorm(100, 0, 0.2) + 2,
#'     seasonal = sin(1:100 / 10),
#'     trend = seq(1.8, 2.2, length.out = 100),
#'     remainder = rnorm(100, 0, 0.2)
#'   )
#' )
#' create_plot_stl(stl_data)
#' }
#' @export
create_plot_stl <- function(wave_stl, date_caption = NULL, palette = ib_default_palette()) {
  if (is.null(wave_stl) || !"components" %in% names(wave_stl)) {
    return(NULL)
  }

  st <- ib_palette(palette)$semantic

  stl_df <- wave_stl$components
  stl_long <- tidyr::pivot_longer(stl_df,
    cols = c("original", "seasonal", "trend", "remainder"),
    names_to = "component", values_to = "value")
  stl_long$component <- factor(stl_long$component,
    levels = c("original", "trend", "seasonal", "remainder"))

  p <- ggplot2::ggplot(stl_long, ggplot2::aes(x = .data$time, y = .data$value)) +
    ggplot2::geom_line(color = st$primary, alpha = 0.7) +
    ggplot2::facet_wrap(~component, scales = "free_y", ncol = 1) +
    ggplot2::labs(
      x = "Time", y = "Wave Height (m)",
      title = paste0("STL Decomposition",
                     if (!is.null(date_caption)) paste0(" (", date_caption, ")") else "")
    ) +
    ggplot2::theme_minimal() +
    ggplot2::theme(
      panel.background = ggplot2::element_rect(fill = st$panel, color = NA),
      plot.background = ggplot2::element_rect(fill = st$panel, color = NA),
      strip.background = ggplot2::element_rect(fill = st$strip, color = NA),
      strip.text = ggplot2::element_text(color = st$ink),
      panel.grid.major = ggplot2::element_line(color = st$grid_major, linewidth = 0.3),
      panel.grid.minor = ggplot2::element_line(color = st$grid_minor, linewidth = 0.1),
      axis.text = ggplot2::element_text(color = st$ink),
      axis.title = ggplot2::element_text(color = st$ink),
      plot.title = ggplot2::element_text(color = st$ink)
    )

  p
}

#' Create Rogue Gusts All Stations Plot
#'
#' @description
#' Gust / wind ratio per event, with the stations laid out as blocks
#' (alternating shading; time runs left to right inside a block), the rogue
#' gust threshold line and a label on the top event of each station. There is
#' no p-value model for gusts yet.
#'
#' @param rogue_gust_events Data frame of rogue gust events
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' gusts <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:10) * 3600,
#'   station_id = rep(c("M2", "M3"), 5),
#'   gust_ratio = runif(10, 1.5, 3.0),
#'   gust = runif(10, 20, 50),
#'   wind_speed = runif(10, 10, 25),
#'   wave_height = runif(10, 2, 6)
#' )
#' create_plot_rogue_gusts_all(gusts)
#' }
#' @export
create_plot_rogue_gusts_all <- function(rogue_gust_events, palette = ib_default_palette()) {
  if (is.null(rogue_gust_events) || nrow(rogue_gust_events) == 0) {
    return(NULL)
  }

  stations <- sort(unique(rogue_gust_events$station_id))
  threshold <- ib_rogue_gust_threshold()
  lay <- .ib_station_blocks(rogue_gust_events$station_id, rogue_gust_events$time)
  x <- .ib_block_x(lay, rogue_gust_events$station_id, rogue_gust_events$time)
  hover <- paste0(
    "Station: ", rogue_gust_events$station_id, "<br>",
    "Time: ", format(rogue_gust_events$time, "%Y-%m-%d %H:%M"), "<br>",
    "Gust Ratio: ", round(rogue_gust_events$gust_ratio, 3), "<br>",
    "Gust: ", round(rogue_gust_events$gust, 1), " kn<br>",
    "Wind: ", round(rogue_gust_events$wind_speed, 1), " kn<br>",
    "Wave Hs: ", round(rogue_gust_events$wave_height, 2), " m"
  )
  top_idx <- vapply(stations, function(s) {
    idx <- which(rogue_gust_events$station_id == s)
    idx[which.max(rogue_gust_events$gust_ratio[idx])]
  }, integer(1))

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    station_colors <- ib_group_colors(pal, "station", stations)
    p <- plotly::plot_ly()
    for (s in stations) {
      idx <- rogue_gust_events$station_id == s
      p <- plotly::add_trace(
        p, x = x[idx], y = rogue_gust_events$gust_ratio[idx],
        type = "scatter", mode = "markers", name = s,
        marker = list(size = 8, opacity = 0.7, color = station_colors[[s]]),
        text = hover[idx], hoverinfo = "text"
      )
    }
    x_lo <- min(lay$blocks$start) - lay$gap / 2
    x_hi <- max(lay$blocks$end) + lay$gap / 2
    top_labels <- .ib_top_event_annotations(
      x[top_idx], rogue_gust_events$gust_ratio[top_idx],
      paste0(stations, ": gust ratio ",
             sprintf("%.2f", rogue_gust_events$gust_ratio[top_idx])),
      NULL, st
    )
    p |>
      irishbuoys_layout(
        title = paste0(
          "All Rogue Gust Events (n=", nrow(rogue_gust_events), ", ",
          format(min(rogue_gust_events$time), "%Y-%m-%d"), " to ",
          format(max(rogue_gust_events$time), "%Y-%m-%d"), ")"
        ),
        xaxis = .ib_block_xaxis(lay),
        yaxis = list(title = "Gust / Wind Ratio"),
        shapes = c(
          .ib_block_shapes(lay, st),
          list(list(
            type = "line", xref = "x", yref = "y",
            x0 = x_lo, x1 = x_hi, y0 = threshold, y1 = threshold,
            line = list(color = st$threshold, dash = "dash", width = 2)
          ))
        ),
        annotations = c(
          list(list(
            x = x_hi, y = threshold,
            text = paste0("Rogue gust threshold (", threshold, ")"),
            showarrow = FALSE, xanchor = "right", yanchor = "bottom",
            font = list(color = st$threshold, size = 10)
          )),
          top_labels
        )
      )
  })
}

#' Create Rogue Gusts By Station Subplot
#'
#' @param rogue_gust_events Data frame of rogue gust events
#' @param date_caption Date range caption
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' gusts <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:10) * 3600,
#'   station_id = rep(c("M2", "M3"), 5),
#'   gust_ratio = runif(10, 1.5, 3.0),
#'   gust = runif(10, 20, 50),
#'   wind_speed = runif(10, 10, 25)
#' )
#' create_plot_rogue_gusts_by_station(gusts)
#' }
#' @export
create_plot_rogue_gusts_by_station <- function(rogue_gust_events, date_caption = NULL,
                                               palette = ib_default_palette()) {
  if (is.null(rogue_gust_events) || nrow(rogue_gust_events) == 0) {
    return(NULL)
  }

  if (is.null(date_caption)) {
    date_caption <- paste0(
      format(min(rogue_gust_events$time), "%Y-%m-%d"), " to ",
      format(max(rogue_gust_events$time), "%Y-%m-%d")
    )
  }

  stations <- sort(unique(rogue_gust_events$station_id))

  .ib_palette_figure(palette, function(pal) {
    station_colors <- ib_group_colors(pal, "station", stations)

    plots <- lapply(seq_along(stations), function(i) {
      st <- stations[i]
      d <- rogue_gust_events[rogue_gust_events$station_id == st, ]
      n_st <- nrow(d)

      plotly::plot_ly(
        d, x = ~time, y = ~gust_ratio,
        type = "scatter", mode = "markers",
        marker = list(
          size = 8, opacity = 0.85,
          color = station_colors[[st]],
          line = list(width = 0.5, color = ib_alpha(pal$semantic$text_strong, 0.3))
        ),
        text = ~paste0(
          "Station: ", station_id, "<br>",
          "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
          "Gust Ratio: ", round(gust_ratio, 3), "<br>",
          "Gust: ", round(gust, 1), " kn<br>",
          "Wind: ", round(wind_speed, 1), " kn"
        ),
        hoverinfo = "text",
        showlegend = FALSE
      ) |>
        plotly::layout(
          annotations = list(list(
            text = paste0("<b>", st, "</b> (n=", n_st, ")"),
            x = 0.02, y = 0.95, xref = "paper", yref = "paper",
            showarrow = FALSE,
            font = list(size = 13, color = station_colors[[st]])
          )),
          yaxis = list(title = "Gust Ratio")
        )
    })

    plotly::subplot(plots, nrows = length(stations), shareX = TRUE, titleY = TRUE) |>
      irishbuoys_layout(
        title = paste0("Rogue Gust Events by Station (n=", nrow(rogue_gust_events), ", ", date_caption, ")"),
        height = length(stations) * 350,
        xaxis = list(
          title = "Time",
          rangeslider = list(type = "date", thickness = 0.05)
        )
      )
  })
}

#' Create Rogue Gusts vs Rogue Waves Scatter Plot
#'
#' @param analysis_data Full analysis data with both ratios computed
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object
#' @examples
#' \dontrun{
#' data <- data.frame(
#'   time = as.POSIXct("2024-01-01") + (1:20) * 3600,
#'   station_id = rep(c("M2", "M3"), 10),
#'   gust = runif(20, 15, 50),
#'   wind_speed = runif(20, 8, 25),
#'   hmax = runif(20, 5, 15),
#'   wave_height = runif(20, 2, 6)
#' )
#' create_plot_gusts_vs_waves(data)
#' }
#' @export
create_plot_gusts_vs_waves <- function(analysis_data, palette = ib_default_palette()) {
  if (is.null(analysis_data)) {
    return(NULL)
  }

  # Compute both ratios
  d <- analysis_data |>
    dplyr::filter(!is.na(.data$gust), !is.na(.data$wind_speed),
                  !is.na(.data$hmax), !is.na(.data$wave_height),
                  .data$wind_speed > 0, .data$wave_height > 0) |>
    dplyr::mutate(
      gust_ratio = .data$gust / .data$wind_speed,
      rogue_ratio = .data$hmax / .data$wave_height
    ) |>
    dplyr::filter(.data$rogue_ratio > 2.0 | .data$gust_ratio > 1.5)

  if (nrow(d) == 0) {
    return(NULL)
  }

  stations <- sort(unique(d$station_id))

  .ib_palette_figure(palette, function(pal) {
    st <- pal$semantic
    plotly::plot_ly(
      d, x = ~rogue_ratio, y = ~gust_ratio, color = ~station_id,
      colors = ib_group_colors(pal, "station", stations),
      type = "scatter", mode = "markers",
      marker = list(size = 8, opacity = 0.6),
      text = ~paste0(
        "Station: ", station_id, "<br>",
        "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
        "Rogue Ratio (wave): ", round(rogue_ratio, 3), "<br>",
        "Gust Ratio (wind): ", round(gust_ratio, 3)
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = "Rogue Waves vs Rogue Gusts",
        xaxis = list(title = "Wave Rogue Ratio (Hmax/Hs)"),
        yaxis = list(title = "Gust Ratio (Gust/Wind)"),
        shapes = list(
          list(type = "line", x0 = 2.0, x1 = 2.0, y0 = 1.0, y1 = 3.0,
               line = list(color = st$ref_wave, dash = "dash", width = 1)),
          list(type = "line", x0 = 1.5, x1 = 4.0, y0 = 1.5, y1 = 1.5,
               line = list(color = st$ref_gust, dash = "dash", width = 1))
        ),
        annotations = list(
          list(x = 2.0, y = 3.0, text = "Wave rogue (2.0)",
               showarrow = FALSE, xanchor = "left", font = list(color = st$ref_wave, size = 9)),
          list(x = 4.0, y = 1.5, text = "Gust rogue (1.5)",
               showarrow = FALSE, yanchor = "bottom", font = list(color = st$ref_gust, size = 9))
        )
      )
  })
}

# Subsample rows without disturbing the caller's random-number stream.
.ib_sample_rows <- function(n, size, seed = 42L) {
  if (n <= size) {
    return(seq_len(n))
  }
  if (exists(".Random.seed", envir = globalenv(), inherits = FALSE)) {
    old_seed <- get(".Random.seed", envir = globalenv(), inherits = FALSE)
    on.exit(assign(".Random.seed", old_seed, envir = globalenv()), add = TRUE)
  }
  set.seed(seed)
  sample.int(n, size)
}

#' Create Random Forest Actual vs Predicted Plot
#'
#' @description
#' Scatter of actual against predicted significant wave height on the test set,
#' coloured by 2 m wave-height category, with the y = x line and a LOESS fit.
#' Replaces the inline figure of the wave analysis vignette.
#'
#' @param wave_rf_eval Evaluation list from the `wave_rf_eval` target, with a
#'   `predictions` data frame (`actual`, `predicted`, `residual`, `category`)
#'   and an `overall` data frame (`metric`, `value`).
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object, or NULL when `wave_rf_eval` is NULL
#' @examples
#' \dontrun{
#' create_plot_rf_actual_vs_predicted(targets::tar_read(wave_rf_eval))
#' }
#' @export
create_plot_rf_actual_vs_predicted <- function(wave_rf_eval, palette = ib_default_palette()) {
  if (is.null(wave_rf_eval)) {
    return(NULL)
  }

  preds <- wave_rf_eval$predictions
  rf_r2 <- wave_rf_eval$overall$value[wave_rf_eval$overall$metric == "R_squared"]
  preds_plot <- preds[.ib_sample_rows(nrow(preds), 5000L), ]

  # LOESS fit line for actual model performance
  preds_sorted <- preds_plot[order(preds_plot$actual), ]
  loess_fit <- stats::loess(predicted ~ actual, data = preds_sorted, span = 0.3)
  preds_sorted$fitted <- stats::predict(loess_fit)

  max_actual <- max(preds$actual, na.rm = TRUE)

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      preds_plot, x = ~actual, y = ~predicted, type = "scatter", mode = "markers",
      color = ~category, colors = pal$rf_category,
      marker = list(size = 6, opacity = 0.7),
      hoverinfo = "text",
      text = ~paste0(
        "Actual: ", round(actual, 2), " m",
        "<br>Predicted: ", round(predicted, 2), " m",
        "<br>Residual: ", round(residual, 2), " m",
        "<br>Category: ", category
      )
    ) |>
      plotly::add_trace(
        x = c(0, max_actual), y = c(0, max_actual),
        type = "scatter", mode = "lines",
        line = list(dash = "dash", color = pal$semantic$reference, width = 1),
        name = "y = x (perfect)", showlegend = TRUE,
        hoverinfo = "skip", inherit = FALSE
      ) |>
      plotly::add_trace(
        data = preds_sorted, x = ~actual, y = ~fitted,
        type = "scatter", mode = "lines",
        line = list(color = pal$semantic$loess, width = 2),
        name = "LOESS fit", showlegend = TRUE,
        hoverinfo = "skip", inherit = FALSE
      ) |>
      irishbuoys_layout(
        title = paste0(
          "Actual vs Predicted Signif Wave on test set (n=",
          format(nrow(preds), big.mark = ","), ", R²=", round(rf_r2, 3), ")<br>",
          "<sup>Dashed line = y=x (perfect prediction, not a fit). ",
          "Points coloured by 2m wave-height bins (Low/Moderate/High/Extreme) to show where the model struggles. ",
          "Click a legend entry to hide that category; the y=x line remains as reference.</sup>"
        ),
        xaxis = list(title = "Actual Signif Wave (m)"),
        yaxis = list(title = "Predicted Signif Wave (m)"),
        hovermode = "closest"
      )
  })
}

#' Create Random Forest Residuals by Category Plot
#'
#' @description
#' Box plots of the test-set residuals (actual minus predicted) per 2 m
#' wave-height category. Replaces the inline figure of the wave analysis
#' vignette.
#'
#' @param wave_rf_eval Evaluation list from the `wave_rf_eval` target, with a
#'   `predictions` data frame (`residual`, `category`).
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object, or NULL when `wave_rf_eval` is NULL
#' @examples
#' \dontrun{
#' create_plot_rf_residuals(targets::tar_read(wave_rf_eval))
#' }
#' @export
create_plot_rf_residuals <- function(wave_rf_eval, palette = ib_default_palette()) {
  if (is.null(wave_rf_eval)) {
    return(NULL)
  }

  preds <- wave_rf_eval$predictions

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      preds, y = ~residual, x = ~category, type = "box",
      color = ~category, colors = pal$rf_category,
      boxpoints = "outliers",
      hoverinfo = "text",
      text = ~paste0("Category: ", category, "<br>Residual: ", round(residual, 2), " m")
    ) |>
      irishbuoys_layout(
        title = paste0(
          "Residuals by 2m Wave Height Category (test set)<br>",
          "<sup>Categories: Low (0-2m), Moderate (2-4m), High (4-6m), Extreme (>6m). ",
          "2m bins separate calm seas from storm conditions. ",
          "Residual = Actual - Predicted; zero = perfect. Wider boxes = more error.</sup>"
        ),
        xaxis = list(title = "Wave Height Category"),
        yaxis = list(title = "Residual (Actual - Predicted, m)"),
        showlegend = FALSE,
        shapes = list(
          list(type = "line", x0 = -0.5, x1 = 3.5, y0 = 0, y1 = 0,
               line = list(dash = "dash", color = pal$semantic$reference, width = 1))
        )
      )
  })
}

#' Create Random Forest Feature Importance Plot
#'
#' @description
#' Horizontal bars of the ten most important predictors (impurity-based
#' importance). Replaces the inline figure of the wave analysis vignette.
#'
#' @param wave_rf_model Model list from the `wave_rf_model` target, with an
#'   `importance` data frame (`variable`, `importance`).
#' @param palette Name of a palette preset, see [ib_palette_names()].
#' @return plotly object, or NULL when `wave_rf_model` is NULL
#' @examples
#' \dontrun{
#' create_plot_rf_importance(targets::tar_read(wave_rf_model))
#' }
#' @export
create_plot_rf_importance <- function(wave_rf_model, palette = ib_default_palette()) {
  if (is.null(wave_rf_model)) {
    return(NULL)
  }

  imp <- utils::head(wave_rf_model$importance, 10)
  imp <- imp[order(imp$importance), ]  # ascending for horizontal bar
  imp$variable <- factor(imp$variable, levels = imp$variable)

  .ib_palette_figure(palette, function(pal) {
    plotly::plot_ly(
      imp, y = ~variable, x = ~importance, type = "bar",
      orientation = "h",
      marker = list(color = pal$semantic$importance)
    ) |>
      irishbuoys_layout(
        title = paste0(
          "Top 10 Feature Importance (Impurity-based, <a href='https://imbs-hl.github.io/ranger/'>ranger</a>)<br>",
          "<sup>Higher = variable contributes more to reducing prediction error. ",
          "Lagged wave heights dominate because wave conditions persist hour-to-hour.</sup>"
        ),
        xaxis = list(title = "Importance"),
        yaxis = list(title = ""),
        margin = list(l = 150, b = 80)
      )
  })
}
