# Fix Script: Issue #18 - QA Gates as Targets + Test Coverage
# Date: 2026-02-15
# Branch: fix/issue-18-qa-gates-coverage
# PR: TBD
#
# Problem:
#   1. Mandatory QA steps (adversarial QA, quality gates, self-review)
#      were documented but kept getting skipped by the agent
#   2. Test coverage was 8.8% (12 of 15 source files at 0%)
#   3. No R/dev/issue/fix_*.R logging (Step 9 always skipped)
#
# Root cause:
#   Agent context window limitations cause attention to drop for
#   instructions in the bottom half of CLAUDE.md/skills. Documented
#   protocols that rely on agent memory are unreliable.
#
# Solution:
#   1. Created plan_qa_gates.R with 5 targets that run automatically
#      in tar_make() - adversarial QA, coverage, self-review, quality gate
#   2. Added test files for 6 previously untested source files:
#      - test-wave-science.R (wave_science.R: 0% -> target ~100%)
#      - test-data-dictionary.R (data_dictionary.R: 0% -> target ~100%)
#      - test-rogue-waves.R (rogue_waves.R: 32.6% -> target ~60%)
#      - test-joint-analysis.R (joint_analysis.R: 0% -> target ~40%)
#      - test-trend-analysis.R (trend_analysis.R: 0% -> target ~40%)
#      - test-extreme-values.R (extreme_values.R: 0% -> target ~30%)
#      - test-validation.R (validation.R: 9.4% -> target ~30%)
#   3. This fix script (Step 9 compliance)
#
# Files created:
#   R/tar_plans/plan_qa_gates.R
#   tests/testthat/test-wave-science.R
#   tests/testthat/test-data-dictionary.R
#   tests/testthat/test-rogue-waves.R
#   tests/testthat/test-joint-analysis.R
#   tests/testthat/test-trend-analysis.R
#   tests/testthat/test-extreme-values.R
#   tests/testthat/test-validation.R
#   R/dev/issue/fix_018.R (this file)
#
# Files modified:
#   _targets.R (added plan_qa_gates to pipeline)
#
# Verification:
#   devtools::test()  # All tests pass
#   covr::package_coverage()  # Coverage > 30% (target: 60%+)
