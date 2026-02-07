#' Plot Creation Functions for Wave Analysis Dashboard
#'
#' @description
#' Functions that create plotly objects for the wave analysis vignette.
#' Each function returns a plotly object that can be stored as a target.
#'
#' @name plot_functions
#' @keywords internal
NULL

#' Create Rogue Wave All Stations Plot
#'
#' @param rogue_events Data frame of rogue wave events
#' @return plotly object
#' @export
create_plot_rogue_all <- function(rogue_events) {
  if (is.null(rogue_events) || nrow(rogue_events) == 0) {
    return(NULL)
  }

  plotly::plot_ly(
    rogue_events,
    x = ~time, y = ~rogue_ratio, color = ~station_id,
    type = "scatter", mode = "markers",
    marker = list(size = 8, opacity = 0.7),
    text = ~paste0(
      "Station: ", station_id, "<br>",
      "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
      "Rogue Ratio: ", round(rogue_ratio, 3), "<br>",
      "Hmax: ", round(hmax, 2), " m<br>",
      "Hs: ", round(wave_height, 2), " m<br>",
      "Wind: ", round(wind_speed, 1), " m/s<br>",
      "Gust: ", round(gust, 1), " m/s"
    ),
    hoverinfo = "text"
  ) |>
    irishbuoys_layout(
      title = paste0(
        "All Rogue Wave Events (n=", nrow(rogue_events), ", ",
        format(min(rogue_events$time), "%Y-%m-%d"), " to ",
        format(max(rogue_events$time), "%Y-%m-%d"), ")"
      ),
      xaxis = list(title = "Time"),
      yaxis = list(title = "Hmax / Hs Ratio"),
      shapes = list(
        list(
          type = "line",
          x0 = min(rogue_events$time), x1 = max(rogue_events$time),
          y0 = 2.0, y1 = 2.0,
          line = list(color = "red", dash = "dash", width = 2)
        ),
        list(
          type = "line",
          x0 = min(rogue_events$time), x1 = max(rogue_events$time),
          y0 = 2.2, y1 = 2.2,
          line = list(color = "darkred", dash = "dot", width = 1.5)
        )
      ),
      annotations = list(
        list(
          x = max(rogue_events$time), y = 2.0,
          text = "Rogue threshold (2.0)",
          showarrow = FALSE, xanchor = "right", yanchor = "bottom",
          font = list(color = "red", size = 10)
        ),
        list(
          x = max(rogue_events$time), y = 2.2,
          text = "Severe (2.2)",
          showarrow = FALSE, xanchor = "right", yanchor = "bottom",
          font = list(color = "darkred", size = 10)
        )
      )
    )
}

#' Create Rogue Wave By Station Subplot
#'
#' @param rogue_events Data frame of rogue wave events
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_rogue_by_station <- function(rogue_events, date_caption = NULL) {
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
  station_colors <- c(
    M2 = "#e41a1c", M3 = "#377eb8", M4 = "#4daf4a",
    M5 = "#984ea3", M6 = "#ff7f00"
  )

  plots <- lapply(seq_along(stations), function(i) {
    st <- stations[i]
    d <- rogue_events[rogue_events$station_id == st, ]
    n_st <- nrow(d)

    plotly::plot_ly(
      d, x = ~time, y = ~hmax,
      type = "scatter", mode = "markers",
      marker = list(
        size = 8, opacity = 0.85,
        color = station_colors[st],
        line = list(width = 0.5, color = "black")
      ),
      text = ~paste0(
        "Station: ", station_id, "<br>",
        "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
        "Hmax: ", round(hmax, 2), " m<br>",
        "Hs: ", round(wave_height, 2), " m<br>",
        "Ratio: ", round(rogue_ratio, 3), "<br>",
        "Wind: ", round(wind_speed, 1), " m/s"
      ),
      hoverinfo = "text",
      showlegend = FALSE
    ) |>
      plotly::layout(
        annotations = list(list(
          text = paste0("<b>", st, "</b> (n=", n_st, ")"),
          x = 0.02, y = 0.95, xref = "paper", yref = "paper",
          showarrow = FALSE,
          font = list(size = 13, color = station_colors[st])
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
}

#' Create Wind Speed by Beaufort Scale Plot
#'
#' @param rogue_conditions Data frame with rogue wave conditions
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_wind_beaufort <- function(rogue_conditions, date_caption = NULL) {
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

  beaufort_colors <- c(
    "0-5 (Calm-Fresh)" = "#2166ac",
    "6-7 (Strong-Near Gale)" = "#4393c3",
    "8-9 (Gale-Severe)" = "#d6604d",
    "10 (Storm)" = "#f4a582",
    "11 (Violent Storm)" = "#b2182b",
    "12 (Hurricane)" = "#67001f"
  )

  rc <- rogue_conditions
  rc$beaufort <- classify_beaufort(rc$wind_speed)

  plotly::plot_ly(
    rc, x = ~wind_speed, y = ~rogue_ratio, color = ~beaufort,
    colors = beaufort_colors,
    type = "scatter", mode = "markers",
    marker = list(size = 10, opacity = 0.8, line = list(width = 1, color = "#333333")),
    text = ~paste0(
      "Station: ", station_id, "<br>",
      "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
      "Wind: ", round(wind_speed, 1), " m/s<br>",
      "Beaufort: ", beaufort, "<br>",
      "Rogue Ratio: ", round(rogue_ratio, 3), "<br>",
      "Hmax: ", round(hmax, 2), " m<br>",
      "Hs: ", round(wave_height, 2), " m"
    ),
    hoverinfo = "text"
  ) |>
    irishbuoys_layout(
      title = paste0("Rogue Waves by Wind Speed (", date_caption, ")"),
      xaxis = list(title = "Wind Speed (m/s)"),
      yaxis = list(title = "Hmax / Hs Ratio"),
      shapes = list(
        list(
          type = "line",
          x0 = 0, x1 = max(rc$wind_speed, na.rm = TRUE) * 1.05,
          y0 = 2.0, y1 = 2.0,
          line = list(color = "red", dash = "dash", width = 2)
        )
      )
    )
}

#' Create Week of Year Stacked Bar Plot
#'
#' @param rogue_conditions Data frame with rogue wave conditions
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_week_of_year <- function(rogue_conditions, date_caption = NULL) {
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

  month_colors <- c(
    "Jan" = "#1f77b4", "Feb" = "#2ca02c", "Mar" = "#8c564b",
    "Apr" = "#ff7f0e", "May" = "#d62728", "Jun" = "#9467bd",
    "Jul" = "#e377c2", "Aug" = "#17becf", "Sep" = "#7f7f7f",
    "Oct" = "#393b79", "Nov" = "#637939", "Dec" = "#8c6d31"
  )

  plotly::plot_ly(
    week_counts, x = ~week, y = ~n, color = ~month_name,
    colors = month_colors,
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
}

#' Create Time of Day Bar Plot
#'
#' @param rogue_conditions Data frame with rogue wave conditions
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_time_of_day <- function(rogue_conditions, date_caption = NULL) {
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

  tod_colors <- c(
    Morning = "#f4a582", Afternoon = "#d6604d",
    Evening = "#4393c3", Night = "#2166ac"
  )

  total_events <- sum(tod_data$n)

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
        showarrow = FALSE, font = list(color = "#333333", size = 11)
      ))
    )
}

#' Create Monthly Wave Height Bar Plot
#'
#' @param seasonal_means_wave Seasonal means from calculate_seasonal_means
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_monthly_wave <- function(seasonal_means_wave, date_caption = NULL) {
  if (is.null(seasonal_means_wave) || !"monthly" %in% names(seasonal_means_wave)) {
    return(NULL)
  }

  monthly <- seasonal_means_wave$monthly
  monthly$month_name <- factor(monthly$month_name, levels = month.abb)

  plotly::plot_ly(
    monthly, x = ~month_name, y = ~mean,
    type = "bar",
    marker = list(color = "steelblue"),
    error_y = list(type = "data", array = ~sd, color = "gray40"),
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
}

#' Create Monthly Wind Speed Bar Plot
#'
#' @param seasonal_means_wind Seasonal means from calculate_seasonal_means
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_monthly_wind <- function(seasonal_means_wind, date_caption = NULL) {
  if (is.null(seasonal_means_wind) || !"monthly" %in% names(seasonal_means_wind)) {
    return(NULL)
  }

  monthly <- seasonal_means_wind$monthly
  monthly$month_name <- factor(monthly$month_name, levels = month.abb)

  plotly::plot_ly(
    monthly, x = ~month_name, y = ~mean,
    type = "bar",
    marker = list(color = "darkorange"),
    error_y = list(type = "data", array = ~sd, color = "gray40"),
    text = ~paste0(
      "Month: ", month_name, "<br>",
      "Mean Wind: ", round(mean, 2), " m/s<br>",
      "SD: ", round(sd, 2), " m/s"
    ),
    hoverinfo = "text"
  ) |>
    irishbuoys_layout(
      title = paste0("Monthly Mean Wind Speed", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
      xaxis = list(title = "Month"),
      yaxis = list(title = "Mean Wind Speed (m/s)")
    )
}

#' Create Annual Trends Line Plot
#'
#' @param annual_trends Annual trends from calculate_annual_trends
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_annual_trends <- function(annual_trends, date_caption = NULL) {
  if (is.null(annual_trends) || !"annual_stats" %in% names(annual_trends)) {
    return(NULL)
  }

  annual <- annual_trends$annual_stats

  plotly::plot_ly(
    annual, x = ~year, y = ~mean,
    type = "scatter", mode = "lines+markers",
    marker = list(size = 8, color = "steelblue"),
    line = list(color = "steelblue"),
    error_y = list(type = "data", array = ~sd, color = "gray60"),
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
}

#' Create Return Levels Plot
#'
#' @param return_levels Return levels data frame
#' @param variable Variable name for title ("wave", "wind", or "hmax")
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_return_levels <- function(return_levels, variable = "wave", date_caption = NULL) {
  if (is.null(return_levels)) {
    return(NULL)
  }

  colors <- list(
    wave = "steelblue",
    wind = "darkorange",
    hmax = "darkred"
  )
  fill_colors <- list(
    wave = "rgba(70, 130, 180, 0.2)",
    wind = "rgba(255, 140, 0, 0.2)",
    hmax = "rgba(139, 0, 0, 0.2)"
  )
  titles <- list(
    wave = "Wave Height Return Levels - GEV",
    wind = "Wind Speed Return Levels - GEV",
    hmax = "Max Wave Height Return Levels - GEV"
  )
  y_labels <- list(
    wave = "Hs (m)",
    wind = "Wind Speed (m/s)",
    hmax = "Hmax (m)"
  )

  col <- colors[[variable]]
  fill_col <- fill_colors[[variable]]
  title <- titles[[variable]]
  y_label <- y_labels[[variable]]

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
}

#' Create Gust Factor by Category Plot
#'
#' @param gust_analysis Gust factor analysis results
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_gust_by_category <- function(gust_analysis, date_caption = NULL) {
  if (is.null(gust_analysis)) {
    return(NULL)
  }

  # Try by_station_category first, fallback to by_category
  if ("by_station_category" %in% names(gust_analysis) && !is.null(gust_analysis$by_station_category)) {
    gust_sc <- gust_analysis$by_station_category

    plotly::plot_ly(
      gust_sc, x = ~wind_category, y = ~mean_gf, color = ~station_id,
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
        xaxis = list(title = "Wind Speed Category (m/s)"),
        yaxis = list(title = "Mean Gust Factor"),
        barmode = "group",
        shapes = list(
          list(
            type = "line", x0 = -0.5, x1 = 4.5,
            y0 = 1.3, y1 = 1.3,
            line = list(color = "red", dash = "dash", width = 2)
          )
        ),
        annotations = list(
          list(
            x = 4, y = 1.3, text = "Typical (1.3)",
            showarrow = FALSE, yanchor = "bottom", font = list(color = "red", size = 10)
          )
        )
      )
  } else if ("by_category" %in% names(gust_analysis)) {
    gust_cat <- gust_analysis$by_category

    plotly::plot_ly(
      gust_cat, x = ~wind_category, y = ~mean_gf,
      type = "bar",
      marker = list(color = "darkorange"),
      text = ~paste0(
        "Category: ", wind_category, "<br>",
        "Mean GF: ", round(mean_gf, 2), "<br>",
        "P95 GF: ", round(p95_gf, 2)
      ),
      hoverinfo = "text"
    ) |>
      irishbuoys_layout(
        title = paste0("Gust Factor by Wind Speed Category", if (!is.null(date_caption)) paste0(" (", date_caption, ")") else ""),
        xaxis = list(title = "Wind Speed Category (m/s)"),
        yaxis = list(title = "Gust Factor"),
        shapes = list(
          list(
            type = "line", x0 = -0.5, x1 = nrow(gust_cat) - 0.5,
            y0 = 1.3, y1 = 1.3,
            line = list(color = "red", dash = "dash", width = 2)
          )
        ),
        annotations = list(
          list(
            x = nrow(gust_cat) - 1, y = 1.3, text = "Typical (1.3)",
            showarrow = FALSE, yanchor = "bottom", font = list(color = "red", size = 10)
          )
        )
      )
  } else {
    return(NULL)
  }
}

#' Create Rogue Gusts by Station Plot
#'
#' @param gust_analysis Gust factor analysis results
#' @return plotly object
#' @export
create_plot_rogue_gusts <- function(gust_analysis) {
  if (is.null(gust_analysis) ||
      !"by_station" %in% names(gust_analysis) ||
      is.null(gust_analysis$by_station)) {
    return(NULL)
  }

  bs <- gust_analysis$by_station

  plotly::plot_ly(
    bs, x = ~station_id, y = ~pct_rogue,
    type = "bar",
    marker = list(
      color = ~n_rogue,
      colorscale = list(c(0, "#fee0d2"), c(1, "#de2d26")),
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
}

#' Create STL Decomposition Plot
#'
#' @param wave_stl STL decomposition from calculate_wave_seasonality
#' @param date_caption Date range caption
#' @return ggplot2 object
#' @export
create_plot_stl <- function(wave_stl, date_caption = NULL) {
  if (is.null(wave_stl) || !"components" %in% names(wave_stl)) {
    return(NULL)
  }

  stl_df <- wave_stl$components
  stl_long <- tidyr::pivot_longer(stl_df,
    cols = c("original", "seasonal", "trend", "remainder"),
    names_to = "component", values_to = "value")
  stl_long$component <- factor(stl_long$component,
    levels = c("original", "trend", "seasonal", "remainder"))

  p <- ggplot2::ggplot(stl_long, ggplot2::aes(x = .data$time, y = .data$value)) +
    ggplot2::geom_line(color = "steelblue", alpha = 0.7) +
    ggplot2::facet_wrap(~component, scales = "free_y", ncol = 1) +
    ggplot2::labs(
      x = "Time", y = "Wave Height (m)",
      title = paste0("STL Decomposition",
                     if (!is.null(date_caption)) paste0(" (", date_caption, ")") else "")
    ) +
    ggplot2::theme_minimal()

  p
}

#' Create Rogue Gusts All Stations Plot
#'
#' @param rogue_gust_events Data frame of rogue gust events
#' @return plotly object
#' @export
create_plot_rogue_gusts_all <- function(rogue_gust_events) {
  if (is.null(rogue_gust_events) || nrow(rogue_gust_events) == 0) {
    return(NULL)
  }

  plotly::plot_ly(
    rogue_gust_events,
    x = ~time, y = ~gust_ratio, color = ~station_id,
    type = "scatter", mode = "markers",
    marker = list(size = 8, opacity = 0.7),
    text = ~paste0(
      "Station: ", station_id, "<br>",
      "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
      "Gust Ratio: ", round(gust_ratio, 3), "<br>",
      "Gust: ", round(gust, 1), " m/s<br>",
      "Wind: ", round(wind_speed, 1), " m/s<br>",
      "Wave Hs: ", round(wave_height, 2), " m"
    ),
    hoverinfo = "text"
  ) |>
    irishbuoys_layout(
      title = paste0(
        "All Rogue Gust Events (n=", nrow(rogue_gust_events), ", ",
        format(min(rogue_gust_events$time), "%Y-%m-%d"), " to ",
        format(max(rogue_gust_events$time), "%Y-%m-%d"), ")"
      ),
      xaxis = list(title = "Time"),
      yaxis = list(title = "Gust / Wind Ratio"),
      shapes = list(
        list(
          type = "line",
          x0 = min(rogue_gust_events$time), x1 = max(rogue_gust_events$time),
          y0 = 1.5, y1 = 1.5,
          line = list(color = "red", dash = "dash", width = 2)
        )
      ),
      annotations = list(
        list(
          x = max(rogue_gust_events$time), y = 1.5,
          text = "Rogue gust threshold (1.5)",
          showarrow = FALSE, xanchor = "right", yanchor = "bottom",
          font = list(color = "red", size = 10)
        )
      )
    )
}

#' Create Rogue Gusts By Station Subplot
#'
#' @param rogue_gust_events Data frame of rogue gust events
#' @param date_caption Date range caption
#' @return plotly object
#' @export
create_plot_rogue_gusts_by_station <- function(rogue_gust_events, date_caption = NULL) {
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
  station_colors <- c(
    M2 = "#e41a1c", M3 = "#377eb8", M4 = "#4daf4a",
    M5 = "#984ea3", M6 = "#ff7f00"
  )

  plots <- lapply(seq_along(stations), function(i) {
    st <- stations[i]
    d <- rogue_gust_events[rogue_gust_events$station_id == st, ]
    n_st <- nrow(d)

    plotly::plot_ly(
      d, x = ~time, y = ~gust_ratio,
      type = "scatter", mode = "markers",
      marker = list(
        size = 8, opacity = 0.85,
        color = station_colors[st],
        line = list(width = 0.5, color = "black")
      ),
      text = ~paste0(
        "Station: ", station_id, "<br>",
        "Time: ", format(time, "%Y-%m-%d %H:%M"), "<br>",
        "Gust Ratio: ", round(gust_ratio, 3), "<br>",
        "Gust: ", round(gust, 1), " m/s<br>",
        "Wind: ", round(wind_speed, 1), " m/s"
      ),
      hoverinfo = "text",
      showlegend = FALSE
    ) |>
      plotly::layout(
        annotations = list(list(
          text = paste0("<b>", st, "</b> (n=", n_st, ")"),
          x = 0.02, y = 0.95, xref = "paper", yref = "paper",
          showarrow = FALSE,
          font = list(size = 13, color = station_colors[st])
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
}

#' Create Rogue Gusts vs Rogue Waves Scatter Plot
#'
#' @param analysis_data Full analysis data with both ratios computed
#' @return plotly object
#' @export
create_plot_gusts_vs_waves <- function(analysis_data) {
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

  plotly::plot_ly(
    d, x = ~rogue_ratio, y = ~gust_ratio, color = ~station_id,
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
             line = list(color = "blue", dash = "dash", width = 1)),
        list(type = "line", x0 = 1.5, x1 = 4.0, y0 = 1.5, y1 = 1.5,
             line = list(color = "orange", dash = "dash", width = 1))
      ),
      annotations = list(
        list(x = 2.0, y = 3.0, text = "Wave rogue (2.0)",
             showarrow = FALSE, xanchor = "left", font = list(color = "blue", size = 9)),
        list(x = 4.0, y = 1.5, text = "Gust rogue (1.5)",
             showarrow = FALSE, yanchor = "bottom", font = list(color = "orange", size = 9))
      )
    )
}
