# Colour-literal guard (issue #116, PR A): every colour lives in R/palettes.R.
# No hex, rgb()/rgba() or named colour may appear as a string constant in
# R/plot_functions.R or in the R chunks of the deployed .qmd files, unless it
# is on tests/testthat/colour-literal-allowlist.tsv with a stated reason.

scanned_files <- c(
  "R/plot_functions.R",
  "vignettes/dashboard_static.qmd",
  "vignettes/wave_analysis.qmd"
)

test_that("scanner detects each literal form (it can go red)", {
  code <- 'x <- list(a = "#ff0000", b = "steelblue", c = "rgba(0,0,0,0.5)",
             d = "red", e = "Station: ", f = "bar", g = "transparent")'
  hits <- colour_literals_in_code(code)$literal
  expect_setequal(hits, c("#ff0000", "steelblue", "rgba(0,0,0,0.5)", "red", "transparent"))
  # A comment mentioning a colour is not a string constant
  expect_equal(nrow(colour_literals_in_code("x <- 1 # \"red\" here")), 0L)
})

test_that("qmd chunk extraction returns only R code", {
  lines <- c("text \"red\"", "```{r setup}", "x <- 1", "```", "<style>color: #fff</style>",
             "```{r}", "y <- 2", "```")
  expect_equal(qmd_r_chunks(lines), c("x <- 1", "y <- 2"))
})

test_that("allow-list entries all carry a reason", {
  allow <- read_colour_allowlist()
  expect_true(all(c("file", "literal", "reason") %in% names(allow)))
  expect_true(all(nzchar(trimws(allow$reason))))
  expect_true(all(allow$file %in% scanned_files))
})

test_that("no unlisted colour literals in plot code or deployed pages", {
  allow <- read_colour_allowlist()
  for (f in scanned_files) {
    path <- source_tree_file(f)
    skip_if(is.null(path), paste("source file not available:", f))
    res <- scan_file_for_colours(path, f, allow)
    expect_equal(
      res$violations, character(),
      info = paste0(f, ": colour literals outside R/palettes.R: ",
                    paste(unique(res$violations), collapse = ", "))
    )
  }
})

test_that("every allow-list entry is still needed (no stale entries)", {
  allow <- read_colour_allowlist()
  for (i in seq_len(nrow(allow))) {
    path <- source_tree_file(allow$file[i])
    skip_if(is.null(path), "source file not available")
    res <- scan_file_for_colours(path, allow$file[i], allow)
    expect_true(allow$literal[i] %in% res$used_allow,
                info = paste("stale allow-list entry:", allow$file[i], allow$literal[i]))
  }
})

test_that("no m/s label remains on wind or gust plots (data are in knots)", {
  path <- source_tree_file("R/plot_functions.R")
  skip_if(is.null(path), "R/plot_functions.R not available")
  strs <- r_string_constants(paste(readLines(path, warn = FALSE), collapse = "\n"))
  expect_equal(strs[grepl("m/s", strs, fixed = TRUE)], character())
  expect_true(any(grepl("(kn)", strs, fixed = TRUE)))
})

test_that("wave_analysis and dashboard_static state wind and gust units as kn", {
  for (f in c("vignettes/wave_analysis.qmd", "vignettes/dashboard_static.qmd")) {
    path <- source_tree_file(f)
    skip_if(is.null(path), paste("source file not available:", f))
    strs <- r_string_constants(paste(qmd_r_chunks(readLines(path, warn = FALSE)), collapse = "\n"))
    expect_equal(strs[grepl("m/s", strs, fixed = TRUE)], character(), info = f)
  }
})
