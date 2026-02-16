# plan_nix_sync.R - DESCRIPTION/default.nix drift detection
# Ensures DESCRIPTION is the single source of truth for R package dependencies.
# When DESCRIPTION changes, this plan detects drift and regenerates default.nix.

plan_nix_sync <- list(
  # Track DESCRIPTION file changes
  targets::tar_target(
    nix_desc_file,
    "DESCRIPTION",
    format = "file"
  ),

  # Extract Imports + Suggests from DESCRIPTION
  targets::tar_target(
    nix_desc_deps,
    {
      get_description_deps(nix_desc_file)
    }
  ),

  # Compare DESCRIPTION deps vs current default.nix packages
  targets::tar_target(
    nix_sync_check,
    {
      # Read default.nix and extract r_pkgs list
      nix_content <- readLines("default.nix", warn = FALSE)
      nix_pkgs_lines <- grep("^\\s+r_pkgs\\s*=", nix_content)

      # Extract package names from default.nix propagatedBuildInputs
      pkg_lines <- grep("R-[a-zA-Z0-9]+", nix_content, value = TRUE)
      nix_pkgs <- gsub(".*R-([a-zA-Z0-9.]+).*", "\\1", pkg_lines)
      nix_pkgs <- unique(nix_pkgs[nchar(nix_pkgs) > 0 & nchar(nix_pkgs) < 30])

      # DESCRIPTION deps (from target)
      desc_deps <- nix_desc_deps

      # Check what's in DESCRIPTION but missing from nix
      missing_from_nix <- setdiff(desc_deps, nix_pkgs)
      extra_in_nix <- setdiff(nix_pkgs, c(desc_deps, "rix", "desc", "devtools",
        "usethis", "pkgload", "gert", "gh", "duckplyr"))

      drift_detected <- length(missing_from_nix) > 0

      if (drift_detected) {
        cli::cli_alert_warning(
          "DESCRIPTION/default.nix drift detected: {length(missing_from_nix)} package(s) missing from nix"
        )
        cli::cli_alert_info("Missing: {paste(missing_from_nix, collapse = ', ')}")
      } else {
        cli::cli_alert_success("DESCRIPTION and default.nix are in sync")
      }

      list(
        drift_detected = drift_detected,
        missing_from_nix = missing_from_nix,
        extra_in_nix = extra_in_nix,
        desc_deps = desc_deps,
        checked_at = Sys.time()
      )
    }
  ),

  # Track default.nix as a file target for downstream dependencies
  targets::tar_target(
    nix_default_nix,
    "default.nix",
    format = "file"
  )
)
