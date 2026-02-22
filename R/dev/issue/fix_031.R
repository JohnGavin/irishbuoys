# fix_031.R — Adopt 5 CI features from b-rodrigues/nix_targets_pipeline
#
# Source: https://github.com/b-rodrigues/nix_targets_pipeline
#
# Features adopted:
#   1. targets-runs orphan branch — Store pipeline state on separate branch
#   2. DeterminateSystems/magic-nix-cache-action — Free Nix binary cache
#   3. DeterminateSystems/nix-installer-action — Better Nix installer
#   4. Explicit nix-build step — Build env before nix-shell
#   5. Failure artifacts — Upload workdir on failure for debugging
#
# Architecture change:
#   BEFORE (fix #30): _targets/ committed to main with Git LFS
#   AFTER  (fix #31): _targets/ stored on targets-runs orphan branch
#
#   This removes _targets/ from main, keeping it clean of binary
#   pipeline artifacts. The weekly-update workflow restores _targets/
#   from targets-runs before each run for incremental pipeline builds.
#
# Files changed:
#   .github/workflows/R-CMD-check.yml    — DeterminateSystems + magic-nix-cache + nix-build + failure artifacts
#   .github/workflows/weekly-update.yml  — Full rewrite: targets-runs branch + all 5 features
#   .github/workflows/api-drift.yml      — DeterminateSystems + magic-nix-cache
#   .gitignore                           — Add _targets/ back (state on targets-runs, not main)
#   .gitattributes                       — Remove _targets/ LFS entries (no longer on main)
#   AGENTS.md                            — Updated CI architecture docs
#   DESCRIPTION                          — Version 0.1.3 -> 0.1.4
#
# Skills/rules updated:
#   ~/.claude/skills/ci-workflows-github-actions/skill.md — New templates + three-tier caching
#   ~/.claude/skills/r-package-workflow/skill.md           — Never-skip-steps rule
#   ~/.claude/skills/subagent-delegation.md                — Solve blockers + parallelize
#   ~/.claude/skills/nix-rix-r-environment/skill.md        — CLI tools not on PATH
#
# Caching strategy (three-tier):
#   1. DeterminateSystems/magic-nix-cache-action — Free, automatic, no quota
#   2. cachix rstats-on-nix                      — Pre-built standard R packages
#   3. cachix johngavin                          — Project-specific irishbuoys package
#
# How targets-runs branch works:
#   1. weekly-update.yml checks out main (source code)
#   2. Restores _targets/ from targets-runs branch (incremental state)
#   3. Runs tar_make() — only rebuilds changed targets
#   4. Renders vignettes — tar_load() works because _targets/ is present
#   5. Commits inst/extdata/*.rds + docs/ to main
#   6. Saves _targets/ state to targets-runs branch
#
# Manual step required after merge:
#   The _targets/ files committed to main in fix #30 are still tracked.
#   To untrack them (optional — they'll be ignored by .gitignore):
#     git rm --cached -r _targets/
#     git commit -m "Remove _targets/ from main (now on targets-runs branch)"
#
# Lessons learned (from fix #30 session):
#   1. Never skip mandatory workflow steps — solve blockers instead
#   2. Use nix-shell -p <tool> when a CLI tool isn't on PATH
#   3. Understand CI architecture before dismissing steps
#   4. Parallelize agents from the start, don't wait to be asked
#   5. Match agent model to task complexity (haiku/sonnet/opus)
#
# Verification:
#   - All 4 workflows use DeterminateSystems installer + magic-nix-cache
#   - R-CMD-check has failure artifact upload
#   - weekly-update uses targets-runs branch pattern
#   - .gitignore re-ignores _targets/
#   - .gitattributes has no _targets/ LFS entries
#   - devtools::check(args = "--no-vignettes") — passes
