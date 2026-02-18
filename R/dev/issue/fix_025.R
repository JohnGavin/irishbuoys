# Fix #25: push_to_cachix.sh pushes 36 paths instead of 1
# Cachix push hard abort, version bump
#
# Issue: https://github.com/JohnGavin/irishbuoys/issues/25
# Branch: fix-issue-25-cachix-push
#
# Root Cause:
#   `echo $RESULT | cachix push johngavin` pushes the ENTIRE closure
#   (all runtime dependencies), not just the single store path.
#   `cachix push` has NO flag to prevent this. The previous script
#   comments and AGENTS.md incorrectly claimed it pushed only 1 path.
#
#   `cachix watch-exec` was also tried but `--watch-mode auto` is buggy
#   in cachix 1.10.1 (falls back to `store` mode, pushing 320+ paths).
#
# Solution: Pre-check approach
#   Before pushing, query https://johngavin.cachix.org/<hash>.narinfo
#   for each R package dependency. If all deps return HTTP 200 (already
#   cached), `cachix push` will skip them and push only the 1 new path.
#   If any deps are NOT cached, the script ABORTs (exit 4).
#
#   Post-push: also counts "Pushing " lines in the log and ABORTs if > 1.
#
# Changes:
#
# 1. push_to_cachix.sh:
#    - Added pre-check: queries narinfo for each R package dep before push
#    - Hard ABORT (exit 4) if uncached deps detected (prevents pushing closure)
#    - Post-push hard ABORT (exit 4) if > 1 path was pushed
#    - Preserves push log for diagnosis on failure
#    - Restructured from 5 steps to 4 (build+push combined)
#    - First-time setup documented: manual seed required for empty cache
#
# 2. DESCRIPTION:
#    - Version bump 0.1.0 -> 0.1.1 (bug fix = patch increment)
#
# 3. AGENTS.md (parent directory, outside git repo):
#    - Updated Cachix Push Rule section
#    - Removed incorrect claim about echo|cachix push being single-path
#
# Verification:
#   devtools::document()  # No changes expected
#   devtools::test()      # 0 failures
#   devtools::check()     # 0 errors, 0 warnings
#   ./push_to_cachix.sh   # Pushed exactly 1 path, pinned as irishbuoys-v0.1.1
