#!/usr/bin/env Rscript
# Preview the weekly summary email locally. NEVER sends email.
#
# Run from the project root, inside the project nix shell:
#   nix-shell default.nix --run "Rscript inst/scripts/preview_weekly_email.R"
#
# Options:
#   --db PATH    read an existing DuckDB file instead of fetching
#   --out PATH   output HTML path (default: <session tmp parent>/irishbuoys_weekly_email_preview_<date>.html)
#   --days N     days to fetch from ERDDAP when no --db is given (default 21)
#
# Without --db the script builds a temporary database holding only the last N
# days, using the project's incremental_update() against the public ERDDAP
# service (read-only HTTP GETs). It never writes inst/extdata/irish_buoys.duckdb.
#
# It prints the latest observation time per station and its age, then the
# output path. It exits non-zero, without rendering, when the data is older
# than validate_email_freshness() allows. There is no bypass flag.

args <- commandArgs(trailingOnly = TRUE)

get_opt <- function(flag, default = NULL) {
  i <- match(flag, args)
  if (is.na(i)) return(default)
  if (i == length(args)) {
    cat("Missing value for ", flag, "\n", sep = "", file = stderr())
    quit(status = 2L)
  }
  args[i + 1L]
}

known <- c("--db", "--out", "--days")
bad <- args[startsWith(args, "--") & !(args %in% known)]
if (length(bad) > 0L) {
  cat("Unknown option(s): ", paste(bad, collapse = ", "), "\n", sep = "", file = stderr())
  quit(status = 2L)
}

if (!file.exists("DESCRIPTION")) {
  cat("Run this script from the project root (no DESCRIPTION found).\n", file = stderr())
  quit(status = 2L)
}

pkgload::load_all(quiet = TRUE)

db_path <- get_opt("--db")
out_file <- get_opt(
  "--out",
  file.path(
    dirname(tempdir()),
    paste0("irishbuoys_weekly_email_preview_", format(Sys.Date()), ".html")
  )
)
days <- suppressWarnings(as.numeric(get_opt("--days", "21")))
if (is.na(days) || days < 14) {
  cat("--days must be a number >= 14 (current week plus previous week).\n", file = stderr())
  quit(status = 2L)
}

result <- tryCatch(
  {
    if (is.null(db_path)) {
      cat("Fetching the last ", days, " days from ERDDAP into a temporary database...\n", sep = "")
      db_path <- email_preview_fetch_recent(days = days)
    }
    render_weekly_email_preview(db_path = db_path, out_file = out_file)
    0L
  },
  error = function(e) {
    cat("REFUSED: ", conditionMessage(e), "\n", sep = "", file = stderr())
    1L
  }
)
quit(status = result)
