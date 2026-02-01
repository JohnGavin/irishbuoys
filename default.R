#!/usr/bin/env Rscript
# Generate default.nix for irishbuoys with analysis vignette packages
# Includes targets, crew, mirai for parallel processing and oceanographic packages

# Core R packages for data work
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

# Pipeline and parallel processing packages
pipeline_pkgs <- c(
  "targets",        # Pipeline framework
  "tarchetypes",    # Targets archetypes
  "crew",           # Worker pools
  "mirai"           # Async parallel
)

# Analysis and modeling packages for oceanographic data
analysis_pkgs <- c(
  "mgcv",           # GAM models
  "forecast",       # Time series forecasting
  "extRemes",       # Extreme value analysis
  "evd",            # Extreme value distributions
  "quantreg",       # Quantile regression
  "zoo",            # Time series infrastructure
  "xts"             # Extensible time series
)

# Visualization packages
viz_pkgs <- c(
  "ggplot2",        # Grammar of graphics
  "plotly",         # Interactive plots
  "scales"          # Scale functions
)

# Development tools
dev_tools <- c(
  "rix",
  "desc",
  "devtools",
  "usethis",
  "pkgload",
  "testthat",
  "gert",           # Git operations
  "quarto"          # Documentation
)

# All packages
all_r_pkgs <- c(core_pkgs, pipeline_pkgs, analysis_pkgs, viz_pkgs, dev_tools)

# System packages
system_pkgs <- c("git", "pandoc", "quarto")

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

cat("default.nix generated with analysis vignette packages\n")
cat("Core: arrow, duckdb, dplyr, tidyr, lubridate, jsonlite, httr2\n")
cat("Pipeline: targets, tarchetypes, crew, mirai\n")
cat("Analysis: mgcv, forecast, extRemes, evd, quantreg, zoo, xts\n")
cat("Viz: ggplot2, plotly, scales\n")
cat("Dev: rix, desc, devtools, usethis, testthat, gert, quarto\n")
