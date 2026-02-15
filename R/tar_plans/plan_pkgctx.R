#' Package Context (pkgctx) Targets Plan
#'
#' @description
#' Generate .ctx.yaml files for LLM context using pkgctx.
#' These files provide compact API documentation that Claude can use
#' to understand package functions without reading full source.
#'
#' Pattern:
#' - pkgctx_* : targets for generating context files
#'
#' @details
#' Output files are stored in inst/extdata/ctx/ for inclusion in the package.
#' This follows the "LLM-ready documentation" pattern where context files
#' are generated as part of the build process.
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

  # Filter to packages that are likely useful for LLM context

  # Exclude base R packages and very common ones
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
  # CURRENT PACKAGE CONTEXT
  # ==========================================================================

  # Generate context for the current package
  targets::tar_target(
    pkgctx_self,
    {
      pkg_name <- read.dcf("DESCRIPTION")[, "Package"]
      output_file <- file.path(pkgctx_dir, paste0(pkg_name, ".ctx.yaml"))

      run_pkgctx(".", output_file, compact = TRUE)
    }
  ),

  # ==========================================================================
  # DEPENDENCY CONTEXTS
  # ==========================================================================

  # Get list of dependencies to generate context for
  targets::tar_target(
    pkgctx_deps_list,
    {
      deps <- get_description_deps("DESCRIPTION")

      # Priority packages (always generate)
      priority <- c("dplyr", "tidyr", "purrr", "ggplot2", "tibble",
                    "targets", "DBI", "duckdb", "arrow", "pointblank",
                    "cli", "rlang", "httr2", "jsonlite", "lubridate")

      # Only include priority packages that are actually dependencies
      deps_to_generate <- intersect(priority, deps)

      cli::cli_alert_info("Dependencies to generate context for: {paste(deps_to_generate, collapse = ', ')}")
      deps_to_generate
    }
  ),

  # Generate context for each priority dependency
  targets::tar_target(
    pkgctx_deps,
    {
      if (length(pkgctx_deps_list) == 0) {
        return(tibble::tibble(package = character(), ctx_file = character(), success = logical()))
      }

      results <- lapply(pkgctx_deps_list, function(pkg) {
        output_file <- file.path(pkgctx_dir, paste0(pkg, ".ctx.yaml"))

        # Skip if recent file exists (within 7 days)
        if (file.exists(output_file)) {
          file_age_days <- as.numeric(difftime(Sys.time(), file.mtime(output_file), units = "days"))
          if (file_age_days < 7) {
            cli::cli_alert_info("Skipping {pkg} (generated {round(file_age_days, 1)} days ago)")
            return(tibble::tibble(package = pkg, ctx_file = output_file, success = TRUE, skipped = TRUE))
          }
        }

        result <- run_pkgctx(pkg, output_file, compact = TRUE)
        tibble::tibble(
          package = pkg,
          ctx_file = result,
          success = !is.na(result),
          skipped = FALSE
        )
      })

      dplyr::bind_rows(results)
    }
  ),

  # ==========================================================================
  # API DRIFT DETECTION
  # ==========================================================================

  # Check if package API has changed since last context generation
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
      deps_generated <- sum(pkgctx_deps$success, na.rm = TRUE)
      deps_total <- nrow(pkgctx_deps)

      ctx_files <- list.files(pkgctx_dir, pattern = "\\.ctx\\.yaml$", full.names = TRUE)
      total_size_kb <- sum(file.size(ctx_files)) / 1024

      tibble::tibble(
        metric = c("Self Context", "Dependencies Generated", "Dependencies Total",
                   "Total Files", "Total Size (KB)", "Context Directory"),
        value = c(
          if (self_exists) "Yes" else "No",
          as.character(deps_generated),
          as.character(deps_total),
          as.character(length(ctx_files)),
          sprintf("%.1f", total_size_kb),
          pkgctx_dir
        )
      )
    }
  )
)
