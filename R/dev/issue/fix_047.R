# Fix #47: Telemetry backport — remaining items
#
# What was already implemented:
# All 5 telemetry sections: commit velocity, GitHub activity,
# codebase metrics, top targets by size, top targets by compute time.
# Targets and vignette tabs were wired.
#
# Remaining fixes (this commit):
#
# 1. Changed top 10 to top 5 for both size and time tables
#    File: R/tar_plans/plan_telemetry.R
#    - table_telemetry_top_size: utils::head(10) -> utils::head(5)
#    - table_telemetry_top_time: utils::head(10) -> utils::head(5)
#    - Updated captions to say "Top 5" instead of "Top 10"
#
# 2. Added CI Workflow Runtimes tab
#    File: R/tar_plans/plan_telemetry.R
#    - New target table_telemetry_ci_workflows displaying
#      telemetry_github_activity$recent_workflows as a DT table
#    File: vignettes/telemetry.qmd
#    - New "CI Workflows" tab under "Git Activity" section
#    - tar_load(table_telemetry_ci_workflows) added to setup chunk
