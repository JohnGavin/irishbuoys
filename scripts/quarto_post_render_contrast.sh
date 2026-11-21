#!/usr/bin/env bash
# Guarded post-render hook: dark-mode contrast audit.
#
# The audit script lives in the owner's global llm checkout (one home, never
# copied into a project). It does not exist in GitHub Actions, so this wrapper
# skips with a message and exit 0 when it is absent, and delegates to it
# (passing on Quarto's environment and its exit status) when it is present.
# A missing audit script is therefore visible in the render log but never
# fails a build.

# IB_CONTRAST_HOOK overrides the path (used to test the absent case).
GLOBAL_HOOK="${IB_CONTRAST_HOOK:-${HOME}/docs_gh/llm/.claude/scripts/quarto_post_render_contrast.sh}"

if [ ! -x "$GLOBAL_HOOK" ]; then
  echo "post-render-contrast: SKIPPED (not run): $GLOBAL_HOOK not found or not executable (expected in CI)"
  exit 0
fi

exec "$GLOBAL_HOOK" "$@"
