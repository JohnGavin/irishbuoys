# local_pipeline_run.R — Reproducible local equivalent of data-update.yml CI.
#
# Usage (from anywhere — script auto-detects package root):
#
#   # From inside nix-shell, inside irishbuoys/:
#   Rscript R/dev/local_pipeline_run.R
#
#   # From outside nix-shell, from ANY directory:
#   env -u R_LIBS_SITE -u R_LIBS_USER -u R_LIBS \
#     nix-shell ~/docs_gh/proj/data/weather/irish_buoy_network/irishbuoys/default.nix \
#     -A shell --run 'Rscript ~/docs_gh/proj/data/weather/irish_buoy_network/irishbuoys/R/dev/local_pipeline_run.R'
#
# What it does (mirrors data-update.yml steps):
#   1. Fetch fresh ERDDAP data via incremental_update()
#   2. Run tar_make() excluding slow/dev-only targets
#   3. Render vignettes via quarto
#   4. Copy rendered vignettes to docs/articles/
#   5. Report summary
#
# What it does NOT do (those are manual):
#   - git commit / push (user decides when)
#   - deploy to GitHub Pages (triggered by push to main)
#   - run devtools::check() or tests (separate step)
#
# Note on M4 outage: if dv_station_completeness aborts because a buoy
# is offline, temporarily bump LOOKBACK_DAYS_VALIDATION in
# R/tar_plans/plan_data_validation.R (e.g. 7 -> 14) before running.
# Revert before committing. See CHANGELOG.md 2026-04-09 entry.

# Ensure we're in the package root regardless of where Rscript was invoked.
# Locate DESCRIPTION by walking up from this script's location.
pkg_root <- tryCatch(
  rprojroot::find_package_root_file(),
  error = function(e) {
    # Fallback: derive from this script's path via --file= arg
    args <- commandArgs(trailingOnly = FALSE)
    file_arg <- grep("^--file=", args, value = TRUE)
    if (length(file_arg) > 0) {
      script_path <- normalizePath(sub("^--file=", "", file_arg[1]), mustWork = TRUE)
      # Script is at R/dev/local_pipeline_run.R → package root is ../..
      normalizePath(file.path(dirname(script_path), "..", ".."), mustWork = TRUE)
    } else {
      stop("Cannot determine package root. Run from irishbuoys/ or use Rscript with full path.")
    }
  }
)
setwd(pkg_root)
cli::cli_alert_info("Working directory: {getwd()}")

cli::cli_h1("Step 1: Fetch fresh ERDDAP data")
pkgload::load_all(quiet = TRUE)

lookback <- as.integer(Sys.getenv("LOOKBACK_HOURS", unset = "500"))
result <- incremental_update(
  db_path = "inst/extdata/irish_buoys.duckdb",
  lookback_hours = lookback
)
cat("Status:", result$status, "\n")
cat("Records added:", result$records_added, "\n")
if (!is.null(result$summary) && nrow(result$summary) > 0) {
  cols <- intersect(c("station_id", "latest", "n_records"), names(result$summary))
  if (length(cols) > 0) print(result$summary[, cols, drop = FALSE])
}
if (result$status == "error") {
  stop("Data fetch failed: ", result$error)
}

cli::cli_h1("Step 2: Run targets pipeline")
targets::tar_config_set(store = "_targets")
# callr_function = NULL runs tar_make() in-process rather than forking a
# subprocess. The callr fork gets killed by the system during long-running
# C computations (spatial_extremal_dependence: ~7 min of SpatialExtremes
# bootstrap). In-process avoids this and also gives real-time log output.
targets::tar_make(
  names = !tidyselect::starts_with("vignette_") &
          !tidyselect::starts_with("qa_") &
          !tidyselect::starts_with("pkgctx_") &
          !tidyselect::starts_with("pkgdown_"),
  callr_function = NULL
)

cli::cli_h1("Step 3: Render vignettes (fingerprint-cached)")

# Fingerprint-based skip: hash QMD source + targets store metadata timestamp.
# If neither changed since last render, skip re-rendering.
fp_dir <- file.path(pkg_root, ".vignette_fingerprints")
if (!dir.exists(fp_dir)) dir.create(fp_dir)

vignette_fingerprint <- function(qmd_name) {
  qmd_path <- file.path("vignettes", paste0(qmd_name, ".qmd"))
  store_meta <- file.path("_targets", "meta", "meta")
  digest::digest(c(
    digest::digest(file = qmd_path),
    if (file.exists(store_meta)) as.character(file.mtime(store_meta)) else ""
  ))
}

vignettes <- c("dashboard_static", "wave_analysis", "telemetry", "api-usage")
for (qmd in vignettes) {
  html_path <- file.path("docs", "vignettes", paste0(qmd, ".html"))
  fp_path <- file.path(fp_dir, paste0(qmd, ".fingerprint"))
  current_fp <- vignette_fingerprint(qmd)
  stored_fp <- if (file.exists(fp_path)) readLines(fp_path, n = 1) else ""

  if (file.exists(html_path) && identical(current_fp, stored_fp)) {
    cli::cli_alert_success("Skipping {qmd} (unchanged)")
    next
  }

  cli::cli_alert_info("Rendering {qmd}")
  tryCatch({
    quarto::quarto_render(file.path("vignettes", paste0(qmd, ".qmd")))
    writeLines(current_fp, fp_path)
  },
  error = function(e) cli::cli_alert_warning("{qmd} render failed: {e$message}")
  )
}

cli::cli_h1("Step 4: Copy vignettes to docs/articles/")
if (!dir.exists("docs/articles")) dir.create("docs/articles", recursive = TRUE)
for (name in c("wave_analysis", "telemetry", "dashboard_static", "api-usage")) {
  html <- file.path("docs", "vignettes", paste0(name, ".html"))
  if (file.exists(html)) {
    file.copy(html, file.path("docs", "articles", basename(html)), overwrite = TRUE)
    cli::cli_alert_success("Copied {name}.html")
  }
  files_dir <- file.path("docs", "vignettes", paste0(name, "_files"))
  if (dir.exists(files_dir)) {
    dest <- file.path("docs", "articles", paste0(name, "_files"))
    if (dir.exists(dest)) unlink(dest, recursive = TRUE)
    file.copy(files_dir, "docs/articles/", recursive = TRUE)
    cli::cli_alert_success("Copied {name}_files/")
  }
}

cli::cli_h1("Done")
cli::cli_alert_info("Next: review changes, commit, push to main")
cli::cli_alert_info("Pages deploy triggers automatically on push")
