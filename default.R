#!/usr/bin/env Rscript
# Generate default.nix for irishbuoys with analysis vignette packages
# Includes targets, crew, mirai for parallel processing and oceanographic packages

# Core R packages for data work
core_pkgs <- c(
  "arrow",          # Apache Arrow for data
  "dbplyr",         # Database backend for dplyr (translates dplyr to SQL)
  "duckdb",         # DuckDB for data queries
  "duckplyr",       # dplyr backend for DuckDB
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
  "mev",            # Multivariate extreme values (GPD)
  "SpatialExtremes",# Spatial extreme value modelling
  "quantreg",       # Quantile regression
  "copula",         # Copula models for dependence
  "kendallknight",  # O(n log n) Kendall correlation
  "zoo",            # Time series infrastructure
  "xts",            # Extensible time series
  "pointblank"      # Data validation
)

# Visualization packages
viz_pkgs <- c(
  "ggplot2",        # Grammar of graphics
  "plotly",         # Interactive plots
  "scales",         # Scale functions
  "DT",             # Interactive tables
  "dygraphs",       # Time series plots
  "perspectiveR",   # WASM pivot tables (FINOS Perspective)
  "shiny",          # Shiny web apps
  "shinylive"       # Shinylive deployment
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
  "quarto",         # Documentation
  "blastula",       # Email reports
  "withr",          # Test helpers
  "here",           # Project root detection
  "covr",           # Test coverage
  "knitr",          # Vignette engine
  "rmarkdown"       # Document rendering
)

# All packages
all_r_pkgs <- c(core_pkgs, pipeline_pkgs, analysis_pkgs, viz_pkgs, dev_tools)

# System packages
system_pkgs <- c("git", "pandoc", "quarto")

# Use a ~1 month old date for stable, pre-built cachix binaries
# NOTE: After regenerating, manually verify that default.nix retains the
# shellHook that overrides R_LIBS_SITE using closePropagation.
# This prevents nested nix-shell segfaults from ABI mismatch.
# See: memory/nix-segfault-fix.md
rix::rix(
  date = "2026-01-19",
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
cat("Analysis: mgcv, forecast, extRemes, evd, copula, quantreg, zoo, xts\n")
cat("Viz: ggplot2, plotly, scales, shiny, shinylive\n")
cat("Dev: rix, desc, devtools, usethis, testthat, gert, quarto, blastula, here, covr\n")
