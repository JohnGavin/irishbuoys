#' Standard Plotly Theme for Irish Buoys Package
#'
#' @description
#' Applies consistent styling to all plotly plots in the irishbuoys package.
#' Includes grey background, bottom-positioned horizontal legend, and
#' white hoverlabels for readability.
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
      font = list(size = 14, color = "#333333")
    ),
    plot_bgcolor = "#cccccc",         # gray80
    paper_bgcolor = "#f0f0f0",        # lighter grey surround
    legend = list(
      orientation = "h",
      y = -0.15,
      x = 0.5,
      xanchor = "center",
      font = list(color = "#1a1a1a", size = 12),  # near black for visibility
      bgcolor = "#e0e0e0",            # grey, not white
      bordercolor = "#888888",
      borderwidth = 1
    ),
    hoverlabel = list(
      bgcolor = "#f8f8f8",
      font = list(color = "#1a1a1a", size = 12)
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
