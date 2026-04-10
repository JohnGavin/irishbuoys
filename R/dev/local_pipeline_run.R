# local_pipeline_run.R — Reproducible local equivalent of data-update.yml CI.
#
# Usage (from irishbuoys/ project root, inside nix-shell):
#   Rscript R/dev/local_pipeline_run.R
#
# Or from outside nix-shell (handles R_LIBS_SITE contamination):
#   env -u R_LIBS_SITE -u R_LIBS_USER -u R_LIBS \
#     nix-shell default.nix -A shell --run 'Rscript R/dev/local_pipeline_run.R'
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

cli::cli_h1("Step 1: Fetch fresh ERDDAP data")
pkgload::load_all(quiet = TRUE)

lookback <- as.integer(Sys.getenv("LOOKBACK_HOURS", unset = "500"))
result <- incremental_update(
  db_path = "inst/extdata/irish_buoys.duckdb",
  lookback_hours = lookback
)
cat("Status:", result$status, "\n")
cat("Records added:", result$records_added, "\n")
if (!is.null(result$summary)) {
  print(result$summary[, c("station_id", "latest")])
}
if (result$status == "error") {
  stop("Data fetch failed: ", result$error)
}

cli::cli_h1("Step 2: Run targets pipeline")
targets::tar_config_set(store = "_targets")
targets::tar_make(
  names = !tidyselect::starts_with("vignette_") &
          !tidyselect::starts_with("qa_") &
          !tidyselect::starts_with("pkgctx_") &
          !tidyselect::starts_with("pkgdown_")
)

cli::cli_h1("Step 3: Render vignettes")
vignettes <- c("dashboard_static", "wave_analysis", "telemetry", "api-usage")
for (qmd in vignettes) {
  cli::cli_alert_info("Rendering {qmd}")
  tryCatch(
    quarto::quarto_render(file.path("vignettes", paste0(qmd, ".qmd"))),
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
