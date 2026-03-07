# Fix #49: Nested nix-shell segfault from R_LIBS_SITE contamination
#
# Root cause: Impure nix-shells inherit R_LIBS_SITE from outer shell,
# mixing .so files from different nixpkgs revisions -> ABI mismatch -> segfault.
#
# Fix:
# 1. default.nix shellHook: uses pkgs.lib.closePropagation to compute
#    correct R_LIBS_SITE from transitive R package deps at Nix eval time
# 2. .Rprofile: warns if R_LIBS_SITE has >300 paths (contamination diagnostic)
# 3. default.R: notes shellHook needs manual verification after regeneration
#
# Key insight: Never clear R_LIBS_SITE="" — Nix uses it to provide packages.
# Override with correct paths via closePropagation instead.
#
# Diagnostic: echo $R_LIBS_SITE | tr ':' '\n' | wc -l
#   Clean: ~218 paths. Contaminated: >500 paths.
#
# Reference: NixOS/nixpkgs#293777, rix::rix_init() gap (handles R_LIBS_USER not R_LIBS_SITE)
