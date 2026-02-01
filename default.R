#!/usr/bin/env Rscript
# Generate minimal default.nix for irishbuoys
# Focus on core data packages, avoiding macOS gfortran issues

# Minimal core R packages for data work
core_pkgs <- c(
  "arrow",          # Apache Arrow for data
  "duckdb",         # DuckDB for data queries
  "DBI",            # Database interface
  "dplyr",          # Data manipulation
  "tidyr",          # Data tidying
  "lubridate",      # Date/time handling
  "jsonlite",       # JSON handling
  "httr2",          # HTTP requests
  "cli",            # CLI formatting
  "glue",           # String interpolation
  "rlang",          # R language utilities
  "ranger",         # Random forest for wave prediction
  "gh"              # GitHub API
)

# Development tools
dev_tools <- c(
  "rix",
  "desc", 
  "devtools",
  "usethis",
  "pkgload"
)

# All packages
all_r_pkgs <- c(core_pkgs, dev_tools)

# System packages
system_pkgs <- c("git", "pandoc")

# Generate default.nix
rix::rix(
  r_ver = "4.5.2",
  r_pkgs = all_r_pkgs,
  system_pkgs = system_pkgs,
  git_pkgs = NULL,
  ide = "none",
  project_path = ".",
  overwrite = TRUE,
  print = FALSE
)

cat("✅ Minimal default.nix generated\n")
cat("📦 Core packages: arrow, duckdb, dplyr, tidyr, lubridate, jsonlite\n")
cat("🔧 Dev tools: rix, desc, devtools, usethis, pkgload\n")
cat("ℹ️  Excluded problematic packages (plotly, ggplot2, targets, crew, etc.)\n")
cat("   These can be added back once macOS gfortran igraph issue is fixed\n")
