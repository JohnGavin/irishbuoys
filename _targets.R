# _targets.R file for Irish Buoys Package
# This file orchestrates modular pipeline components from R/tar_plans/

# Load required packages
library(targets)
library(tarchetypes)
library(crew)

# Load package functions (not installed, so use load_all)
pkgload::load_all(quiet = TRUE)

# Set target options
# Note: Don't include "irishbuoys" in packages - we load_all() above instead
tar_option_set(
  packages = c(
    "duckdb", "DBI", "dplyr", "ggplot2", "cli",
    "extRemes",  # For extreme value analysis
    "copula",    # For joint dependence analysis (issue #13)
    "DT",        # For telemetry tables
    "gert"       # For git metrics
  ),
  format = "rds",
  memory = "transient",
  garbage_collection = TRUE,
  # Disable crew parallel workers to avoid DuckDB lock conflicts
  # Re-enable when targets don't share database connections
  # controller = crew::crew_controller_local(workers = 2)
  controller = NULL
)

# Source all R functions (excluding R/dev/ and R/tar_plans/)
for (file in list.files("R", pattern = "\\.R$", full.names = TRUE)) {
  if (!grepl("R/(dev|tar_plans)/", file)) {
    source(file)
  }
}

# Source and load all pipeline plans
plan_files <- list.files("R/tar_plans", pattern = "^plan_.*\\.R$", full.names = TRUE)
for (plan_file in plan_files) {
  source(plan_file)
}

# Combine all plans into single pipeline
# Note: Plans are loaded dynamically from R/tar_plans/, but we list them
# explicitly here to ensure correct execution order and visibility
list(
  plan_data_acquisition,
  plan_quality_control,
  plan_wave_analysis,
  plan_joint_analysis,  # Joint distributions between buoys (issue #13)
  plan_dashboard,
  plan_api,  # Static JSON API at docs/api/v1/ (issue #32)
  plan_doc_examples,
  plan_dashboard_captions,
  plan_telemetry,
  plan_evidence,  # Claude session evidence and verification logs
  plan_vignettes,  # MANDATORY: All vignettes rendered via targets for reproducibility
  plan_pkgctx,  # LLM context files via pkgctx (https://github.com/b-rodrigues/pkgctx)
  plan_qa_gates,  # MANDATORY: Adversarial QA, quality gates, coverage (cannot be skipped)
  plan_nix_sync,  # DESCRIPTION/default.nix drift detection
  plan_email_report  # Weekly email summary via Gmail
)