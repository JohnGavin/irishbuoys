# Fix #45: Dashboard stale data — CI hardening
#
# Original issue: Dashboard showed stale data because pipeline errors
# were silently swallowed.
#
# Previously fixed (commit 5f929dc):
# - Syntax error in plan_data_validation.R:406
# - Removed `|| echo` from tar_make() step
# - dv_freshness target correctly aborts via cli::cli_abort()
#
# Remaining fixes (this commit):
#
# 1. Email freshness check now fails workflow (not just warns)
#    File: .github/workflows/weekly-update.yml
#    The tryCatch error handler was catching stop() and emitting only
#    ::warning::, allowing the workflow to continue with stale data.
#    Removed the tryCatch so stop() propagates and fails the step.
#
# 2. Added tar_validate() pre-check step before tar_make()
#    File: .github/workflows/weekly-update.yml
#    Catches plan-level errors (like syntax errors in plan_*.R files)
#    before the pipeline runs, providing faster feedback.
