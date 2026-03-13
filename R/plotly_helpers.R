#' Standard Plotly Theme for Irish Buoys Package
#'
#' @description
#' Applies consistent dark styling to all plotly plots in the irishbuoys package.
#' Uses black background with white grid lines to match the Quarto cosmo dashboard
#' theme. Bottom-positioned horizontal legend with white hoverlabels.
#'
#' @param p A plotly object
#' @param title Optional title string
#' @param ... Additional arguments passed to plotly::layout()
#'
#' @return A styled plotly object
#'
#' @export
#' @examples
#' \dontrun{
#' library(plotly)
#' p <- plot_ly(data = mtcars, x = ~wt, y = ~mpg, type = "scatter", mode = "markers")
#' p |> irishbuoys_layout(title = "Weight vs MPG")
#' }
irishbuoys_layout <- function(p, title = NULL, ...) {
  dots <- list(...)

  # Default axis styling — deep-merged with caller overrides so grid lines
  # survive when callers pass xaxis/yaxis with title, rangeslider, etc.
  axis_theme <- list(
    gridcolor = "rgba(255, 255, 255, 0.4)",
    gridwidth = 1,
    zerolinecolor = "rgba(255, 255, 255, 0.3)",
    tickfont = list(color = "#cccccc"),
    titlefont = list(color = "#e0e0e0")
  )

  xaxis <- utils::modifyList(axis_theme, if (!is.null(dots$xaxis)) dots$xaxis else list())
  yaxis <- utils::modifyList(axis_theme, if (!is.null(dots$yaxis)) dots$yaxis else list())

  # Remove xaxis/yaxis from extra args to prevent duplication
  extra <- dots[!names(dots) %in% c("xaxis", "yaxis")]

  do.call(plotly::layout, c(
    list(
      p = p,
      title = list(text = title, font = list(size = 14, color = "#e0e0e0")),
      plot_bgcolor = "#1a1a1a",
      paper_bgcolor = "#1a1a1a",
      xaxis = xaxis,
      yaxis = yaxis,
      legend = list(
        orientation = "h",
        y = -0.15,
        x = 0.5,
        xanchor = "center",
        font = list(color = "#e0e0e0", size = 12),
        bgcolor = "rgba(40, 40, 40, 0.8)",
        bordercolor = "#555555",
        borderwidth = 1
      ),
      hoverlabel = list(
        bgcolor = "white",
        font = list(color = "black", size = 12)
      ),
      margin = list(b = 80)
    ),
    extra
  ))
}


#' Apply Irish Buoys theme to ggplotly object
#'
#' @description
#' Wrapper for ggplotly that applies the standard irishbuoys theme.
#' Useful when converting ggplot2 plots to plotly.
#'
#' @param gg A ggplot2 object
#' @param title Optional title to override ggplot title
#' @param ... Additional arguments passed to plotly::ggplotly()
#'
#' @return A styled plotly object
#'
#' @export
irishbuoys_ggplotly <- function(gg, title = NULL, ...) {
  p <- plotly::ggplotly(gg, ...)

  # Get title from ggplot if not provided
  if (is.null(title) && !is.null(gg$labels$title)) {
    title <- gg$labels$title
  }

  irishbuoys_layout(p, title = title)
}
