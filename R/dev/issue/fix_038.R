# Fix #38: Email summary sends stale data - add freshness validation
#
# Root Cause Analysis (3 interlocking failures):
# 1. DuckDB is ephemeral in CI (gitignored, excluded from targets-runs).
#    Every CI run starts with an empty database.
# 2. Pipeline errors don't prevent email sending. When tar_make() errors
#    partway through, email_sent still runs using CACHED email_summary_data
#    from the targets-runs branch (potentially weeks old).
# 3. validate_email_freshness() in generate_weekly_summary() never executes
#    when email_summary_data is cached (the function only runs when the
#    target is rebuilt, not when it's restored from cache).
#
# Fix (belt-and-suspenders, 4 layers):
#
# Layer 1: R/tar_plans/plan_email_report.R
#   - Added data_update dependency via update_result parameter (DAG edge)
#   - Added validate_email_freshness() in email_sent target body
#     (runs even when email_summary_data is cached)
#   - Aborts with error if no ingestion data or all stations > 96h stale
#
# Layer 2: .github/workflows/weekly-update.yml
#   - Added pre-pipeline "Fetch fresh data" step: explicit incremental_update()
#     with LOOKBACK_HOURS=168 (7 days) BEFORE tar_make()
#   - Ensures DuckDB has fresh data regardless of target caching
#   - Fails workflow if ERDDAP fetch returns error status
#
# Layer 3: .github/workflows/weekly-update.yml
#   - Added post-pipeline "Verify email data freshness" step
#   - Reads email_summary_data target and checks max data age
#   - Warns if > 96h old (doesn't fail, since email_sent gate handles abort)
#
# Layer 4: R/email_summary.R
#   - validate_email_freshness() exported function (aborts ALL stale, warns some)
#   - Called in generate_weekly_summary() after ingestion_stats query
#   - Empty ingestion_stats now warns instead of silent pass
#
# Also fixed pre-existing test bugs:
#   - expect_named missing data_coverage (3 tests)
#   - SQL injection test expectation (dplyr parameterizes safely)
#   - NA timestamp test || on vector
#
# Verification:
# devtools::test(filter = "email")  # 95 pass, 0 fail
# devtools::test()                  # 672 pass, 0 fail
