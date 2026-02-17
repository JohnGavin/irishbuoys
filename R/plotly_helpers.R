#' Standard Plotly Theme for Irish Buoys Package
#'
#' @description
#' Applies consistent styling to all plotly plots in the irishbuoys package.
#' Includes gray 70 background (#B3B3B3), bottom-positioned horizontal legend,
#' and white hoverlabels for readability.
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

  p |> plotly::layout(
    title = list(
      text = title,
      font = list(size = 14, color = "#1a1a1a")
    ),
    plot_bgcolor = "#B3B3B3",
    paper_bgcolor = "#B3B3B3",
    xaxis = list(
      gridcolor = "#666666",
      gridwidth = 0.5,
      zerolinecolor = "#333333",
      tickfont = list(color = "#1a1a1a"),
      titlefont = list(color = "#1a1a1a")
    ),
    yaxis = list(
      gridcolor = "#666666",
      gridwidth = 0.5,
      zerolinecolor = "#333333",
      tickfont = list(color = "#1a1a1a"),
      titlefont = list(color = "#1a1a1a")
    ),
    legend = list(
      orientation = "h",
      y = -0.15,
      x = 0.5,
      xanchor = "center",
      font = list(color = "#1a1a1a", size = 12),
      bgcolor = "#D9D9D9",
      bordercolor = "#999999",
      borderwidth = 1
    ),
    hoverlabel = list(
      bgcolor = "white",
      font = list(color = "black", size = 12)
    ),
    margin = list(b = 80),  # Extra bottom margin for legend
    ...
  )
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
