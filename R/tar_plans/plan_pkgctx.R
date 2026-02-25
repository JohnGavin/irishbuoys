#' Package Context (pkgctx) Targets Plan
#'
#' @description
#' Generate the self-context .ctx.yaml file for this package using pkgctx.
#' This file provides compact API documentation that Claude can use
#' to understand package functions without reading full source.
#'
#' Dependency contexts (dplyr, targets, etc.) are managed centrally by the
#' `llmcontent` package at `/Users/johngavin/docs_gh/proj/data/llm/content/`.
#' They are NOT generated per-project.
#'
#' @details
#' The self-context file is stored in inst/extdata/ctx/ but excluded from
#' the package build via .Rbuildignore. It is for local development only.
#'
#' @references
#' - https://github.com/b-rodrigues/pkgctx
#' - https://brodrigues.co/posts/2026-01-13-data_science_llm_age.html

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

#' Run pkgctx command via nix
#' @param pkg Package specification (e.g., "dplyr", "bioc:GenomicRanges", ".")
#' @param output_file Output .ctx.yaml file path
#' @param compact Use compact mode (default TRUE for 67% token reduction)
#' @param type "r" or "python"
#' @noRd
run_pkgctx <- function(pkg, output_file, compact = TRUE, type = "r") {
  # Ensure output directory exists
  dir.create(dirname(output_file), recursive = TRUE, showWarnings = FALSE)

  # Build command
  compact_flag <- if (compact) "--compact" else ""
  cmd <- sprintf(
    'nix run github:b-rodrigues/pkgctx -- %s %s %s > "%s" 2>&1',
    type, pkg, compact_flag, output_file
  )

  # Execute
  result <- tryCatch({
    system(cmd, intern = FALSE, ignore.stdout = FALSE, ignore.stderr = FALSE)
  }, error = function(e) {
    cli::cli_warn("pkgctx failed for {pkg}: {e$message}")
    1L
  })

  # Return success/failure
  if (result == 0 && file.exists(output_file) && file.size(output_file) > 0) {
    cli::cli_alert_success("Generated {output_file}")
    return(output_file)
  } else {
    cli::cli_alert_danger("Failed to generate {output_file}")
    return(NA_character_)
  }
}

#' Parse DESCRIPTION to get package dependencies
#' @param desc_path Path to DESCRIPTION file
#' @noRd
get_description_deps <- function(desc_path = "DESCRIPTION") {
  if (!file.exists(desc_path)) {
    return(character())
  }

  desc <- read.dcf(desc_path)

  # Extract Imports and Suggests
  imports <- if ("Imports" %in% colnames(desc)) {
    strsplit(desc[, "Imports"], ",\\s*")[[1]]
  } else character()

  suggests <- if ("Suggests" %in% colnames(desc)) {
    strsplit(desc[, "Suggests"], ",\\s*")[[1]]
  } else character()

  # Clean package names (remove version constraints)
  clean_pkg <- function(x) {
    gsub("\\s*\\([^)]+\\)", "", trimws(x))
  }

  deps <- unique(c(sapply(imports, clean_pkg), sapply(suggests, clean_pkg)))
  deps <- deps[deps != "" & !is.na(deps)]

  # Exclude base R packages
  base_pkgs <- c("stats", "graphics", "grDevices", "utils", "datasets",
                 "methods", "base", "tools", "parallel", "compiler",
                 "grid", "splines", "stats4", "tcltk")

  deps[!deps %in% base_pkgs]
}

# ============================================================================
# PKGCTX TARGETS PLAN
# ============================================================================

plan_pkgctx <- list(

  # ==========================================================================
  # CONTEXT DIRECTORY
  # ==========================================================================

  targets::tar_target(
    pkgctx_dir,
    {
      ctx_dir <- "inst/extdata/ctx"
      dir.create(ctx_dir, recursive = TRUE, showWarnings = FALSE)
      ctx_dir
    }
  ),

  # ==========================================================================
  # SELF-CONTEXT ONLY
  # ==========================================================================
  # Dependency contexts (dplyr, targets, etc.) live in the centralised

  # llmcontent package, NOT generated per-project.

  targets::tar_target(
    pkgctx_self,
    {
      pkg_name <- read.dcf("DESCRIPTION")[, "Package"]
      output_file <- file.path(pkgctx_dir, paste0(pkg_name, ".ctx.yaml"))

      run_pkgctx(".", output_file, compact = TRUE)
    }
  ),

  # ==========================================================================
  # API DRIFT DETECTION
  # ==========================================================================

  targets::tar_target(
    pkgctx_api_drift,
    {
      pkg_name <- read.dcf("DESCRIPTION")[, "Package"]
      ctx_file <- file.path(pkgctx_dir, paste0(pkg_name, ".ctx.yaml"))

      if (!file.exists(ctx_file)) {
        return(tibble::tibble(
          status = "missing",
          message = "No context file exists. Run pkgctx_self first.",
          drift_detected = NA
        ))
      }

      # Generate fresh context to temp file
      temp_file <- tempfile(fileext = ".ctx.yaml")
      cmd <- sprintf(
        'nix run github:b-rodrigues/pkgctx -- r . --compact > "%s" 2>/dev/null',
        temp_file
      )
      system(cmd, ignore.stdout = TRUE, ignore.stderr = TRUE)

      if (!file.exists(temp_file) || file.size(temp_file) == 0) {
        return(tibble::tibble(
          status = "error",
          message = "Failed to generate fresh context",
          drift_detected = NA
        ))
      }

      # Compare files
      existing <- readLines(ctx_file, warn = FALSE)
      fresh <- readLines(temp_file, warn = FALSE)
      unlink(temp_file)

      # Filter out timestamp lines for comparison
      filter_timestamps <- function(lines) {
        lines[!grepl("^#.*generated|^#.*timestamp", lines, ignore.case = TRUE)]
      }

      existing_filtered <- filter_timestamps(existing)
      fresh_filtered <- filter_timestamps(fresh)

      drift_detected <- !identical(existing_filtered, fresh_filtered)

      if (drift_detected) {
        cli::cli_alert_warning("API drift detected! Context file may be stale.")
        cli::cli_alert_info("Run: targets::tar_make(names = 'pkgctx_self') to update")
      } else {
        cli::cli_alert_success("No API drift - context file is current")
      }

      tibble::tibble(
        status = if (drift_detected) "drift" else "current",
        message = if (drift_detected) {
          "API has changed since last context generation"
        } else {
          "Context file matches current API"
        },
        drift_detected = drift_detected,
        ctx_file = ctx_file,
        last_modified = file.mtime(ctx_file)
      )
    },
    cue = targets::tar_cue(mode = "always")  # Always check
  ),

  # ==========================================================================
  # SUMMARY
  # ==========================================================================

  targets::tar_target(
    pkgctx_summary,
    {
      self_exists <- file.exists(pkgctx_self)

      ctx_files <- list.files(pkgctx_dir, pattern = "\\.ctx\\.yaml$", full.names = TRUE)
      total_size_kb <- sum(file.size(ctx_files)) / 1024

      tibble::tibble(
        metric = c("Self Context", "Total Files", "Total Size (KB)",
                   "Context Directory"),
        value = c(
          if (self_exists) "Yes" else "No",
          as.character(length(ctx_files)),
          sprintf("%.1f", total_size_kb),
          pkgctx_dir
        )
      )
    }
  )
)
