# Tests for R/plotly_helpers.R

test_that("irishbuoys_layout returns plotly object", {
  skip_if_not_installed("plotly")
  p <- plotly::plot_ly(x = 1:5, y = 1:5, type = "scatter", mode = "markers")
  result <- irishbuoys_layout(p, title = "Test")
  expect_s3_class(result, "plotly")
})

test_that("irishbuoys_layout applies gray 70 background", {
  skip_if_not_installed("plotly")
  p <- plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "markers")
  result <- irishbuoys_layout(p)
  layout <- result$x$layoutAttrs
  # Check that at least one layout attribute set contains gray 70

  attrs <- unlist(layout, recursive = TRUE)
  expect_true(any(grepl("#B3B3B3", attrs)))
})

test_that("irishbuoys_layout sets title when provided", {
  skip_if_not_installed("plotly")
  p <- plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "markers")
  result <- irishbuoys_layout(p, title = "My Title")
  attrs <- unlist(result$x$layoutAttrs, recursive = TRUE)
  expect_true(any(grepl("My Title", attrs)))
})

test_that("irishbuoys_layout works without title", {
  skip_if_not_installed("plotly")
  p <- plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "markers")
  result <- irishbuoys_layout(p)
  expect_s3_class(result, "plotly")
})

test_that("irishbuoys_layout passes extra arguments", {
  skip_if_not_installed("plotly")
  p <- plotly::plot_ly(x = 1:3, y = 1:3, type = "scatter", mode = "markers")
  result <- irishbuoys_layout(p, title = "Test", height = 500)
  expect_s3_class(result, "plotly")
})

test_that("irishbuoys_ggplotly converts ggplot to plotly", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("ggplot2")
  gg <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point()
  result <- irishbuoys_ggplotly(gg)
  expect_s3_class(result, "plotly")
})

test_that("irishbuoys_ggplotly uses ggplot title when none provided", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("ggplot2")
  gg <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point() +
    ggplot2::ggtitle("From ggplot")
  result <- irishbuoys_ggplotly(gg)
  expect_s3_class(result, "plotly")
  attrs <- unlist(result$x$layoutAttrs, recursive = TRUE)
  expect_true(any(grepl("From ggplot", attrs)))
})

test_that("irishbuoys_ggplotly uses explicit title over ggplot title", {
  skip_if_not_installed("plotly")
  skip_if_not_installed("ggplot2")
  gg <- ggplot2::ggplot(mtcars, ggplot2::aes(x = wt, y = mpg)) +
    ggplot2::geom_point() +
    ggplot2::ggtitle("ggplot title")
  result <- irishbuoys_ggplotly(gg, title = "Override Title")
  expect_s3_class(result, "plotly")
  attrs <- unlist(result$x$layoutAttrs, recursive = TRUE)
  expect_true(any(grepl("Override Title", attrs)))
})
