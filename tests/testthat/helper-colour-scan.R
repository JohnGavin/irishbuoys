# Helpers for the colour-literal and unit-label tests (llm-style "one home per
# value": every colour lives in R/palettes.R, see issue #116).

# Locate a file in the source tree from a test; NULL when it is not shipped
# (for example under R CMD check, where vignettes/ is not on the test path).
source_tree_file <- function(...) {
  p <- testthat::test_path("..", "..", ...)
  if (file.exists(p)) normalizePath(p) else NULL
}

# R code of the knitr chunks (```{r ...} ... ```) of a .qmd file. Raw HTML,
# CSS and JavaScript blocks are not R code and are out of scope here: they sit
# outside the palette (see the allow-list policy in the PR description).
qmd_r_chunks <- function(lines) {
  starts <- grep("^```\\{r[ ,}]", lines)
  chunks <- character()
  for (s in starts) {
    rel_end <- grep("^```\\s*$", lines[-seq_len(s)])[1]
    body <- lines[(s + 1L):(s + rel_end - 1L)]
    chunks <- c(chunks, paste(body, collapse = "\n"))
  }
  chunks
}

# Every string constant in a piece of R code, as the string value (no quotes).
r_string_constants <- function(code) {
  parsed <- parse(text = code, keep.source = TRUE)
  pd <- utils::getParseData(parsed)
  if (is.null(pd)) return(character())
  s <- pd$text[pd$token == "STR_CONST"]
  # Strip one layer of quotes; raw strings are not used in this code base.
  sub("^([\"'])(.*)\\1$", "\\2", s)
}

# Is a string a colour literal: hex, rgb()/rgba(), an R colour name or the
# transparent sentinel?
is_colour_literal <- function(x) {
  grepl("^#[0-9A-Fa-f]{3,8}$", x) |
    grepl("^rgba?\\(", x) |
    tolower(x) %in% c(grDevices::colors(), "transparent")
}

# Colour literals found in R code: data frame (literal), one row per hit.
colour_literals_in_code <- function(code) {
  strs <- r_string_constants(code)
  hits <- strs[is_colour_literal(strs)]
  data.frame(literal = hits, stringsAsFactors = FALSE)
}

# Read the allow-list (file, literal, reason). Every entry must carry a reason.
read_colour_allowlist <- function() {
  # Tab-separated (*.csv is git-ignored in this repo).
  path <- testthat::test_path("colour-literal-allowlist.tsv")
  utils::read.delim(path, stringsAsFactors = FALSE, na.strings = character(),
                    quote = "", comment.char = "")
}

# Scan one file; return the literals that are NOT on the allow-list, plus the
# allow-list rows that matched (so stale entries can be detected).
scan_file_for_colours <- function(path, label, allow) {
  lines <- readLines(path, warn = FALSE)
  code <- if (grepl("\\.qmd$", path)) {
    qmd_r_chunks(lines)
  } else {
    paste(lines, collapse = "\n")
  }
  found <- do.call(rbind, c(
    list(data.frame(literal = character(), stringsAsFactors = FALSE)),
    lapply(code, colour_literals_in_code)
  ))
  a <- allow[allow$file == label, , drop = FALSE]
  list(
    violations = setdiff(found$literal, a$literal),
    used_allow = intersect(a$literal, found$literal)
  )
}
