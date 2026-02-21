# fix_021.R - Email reports, Nix sync, DT tables, package cleanup
# Issue: Post-PR #19 cleanup - multiple gaps addressed
#
# Changes made:
#
# Task 3: Replace knitr::kable with DT::datatable
#   - wave_analysis.qmd: 8 replacements (7 knitr::asis_output -> htmltools::div, 1 knitr::kable -> DT::datatable)
#   - debug.qmd: 5 replacements (3 knitr::kable -> DT::datatable, 2+ knitr::asis_output -> htmltools::div)
#   - telemetry.qmd: 1 replacement (knitr::kable -> DT::datatable)
#
# Task 4: Replace rprojroot with here
#   - test-doc-dependencies.R: rprojroot::find_package_root_file() -> here::here()
#   - DESCRIPTION: removed rprojroot, added here
#
# Task 5: Add missing packages to DESCRIPTION + default.R
#   - DESCRIPTION: added here, covr, htmltools; removed rprojroot; alphabetized
#   - default.R: added shiny, shinylive to viz_pkgs; added blastula, withr, here, covr,
#     knitr, rmarkdown to dev_tools; removed duplicate copula
#
# Task 8: Regenerated default.nix via Rscript default.R
#
# Task 1: Added data ingestion stats to email
#   - generate_weekly_summary(): added update_result param, ingestion_stats, db_stats
#   - create_email_summary(): added ingestion table + db totals section
#   - generate_and_send_summary(): migrated from EMAIL_SMTP_* to GMAIL_USERNAME/GMAIL_APP_PASSWORD
#
# Task 6: Created plan_nix_sync.R (DESCRIPTION drift detection)
#   - Targets: nix_desc_file, nix_desc_deps, nix_sync_check, nix_default_nix
#   - Detects when DESCRIPTION changes but default.nix is stale
#
# Task 2: Wired email into targets + weekly CI
#   - Created plan_email_report.R with 3 targets (summary, html, send)
#   - Updated _targets.R to include plan_nix_sync + plan_email_report
#   - Updated weekly-update.yml with GMAIL_* secrets
#
# Task 7: Fixed shinylive/pkgdown conflict
#   - Added documentation note to _pkgdown.yml about shinylive rendering
#
# User action required:
#   - Add GMAIL_USERNAME and GMAIL_APP_PASSWORD secrets to GitHub repo settings
