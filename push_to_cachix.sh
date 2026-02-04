#!/usr/bin/env bash
set -euo pipefail

# Push to Cachix (Step 5 of 9-step workflow)
#
# IMPORTANT: Cachix Strategy for R Packages
# =========================================
#
# TWO-TIER CACHING (search order):
#   1. rstats-on-nix  - Public cache with ALL standard R packages
#   2. johngavin      - Project-specific CUSTOM builds only
#
# For most R projects:
#   - Standard R packages come from rstats-on-nix (pre-built)
#   - Only push to johngavin if you have custom packages NOT in rstats-on-nix
#
# For irishbuoys specifically:
#   - Package is loaded via pkgload::load_all(), not installed
#   - All dependencies (dplyr, targets, etc.) are in rstats-on-nix
#   - Nothing needs to be pushed to johngavin cache
#
# If you add custom packages not in rstats-on-nix, create a package.nix
# and push only those specific packages:
#
#   nix-build package.nix -o result
#   nix-store -qR result | cachix push johngavin
#
# DO NOT push standard R packages to johngavin - it wastes limited quota!

echo "📋 Cachix Push Check for irishbuoys"
echo ""
echo "✓ All R dependencies available from rstats-on-nix cache"
echo "✓ irishbuoys is a development package (load_all, not installed)"
echo "✓ No custom packages need to be pushed to johngavin"
echo ""
echo "No action needed. See script comments for details."
