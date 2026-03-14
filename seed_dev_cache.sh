#!/usr/bin/env bash
#
# seed_dev_cache.sh — Push dev shell to johngavin cachix (one-time or periodic)
#
# Unlike push_to_cachix.sh (which pushes ONLY irishbuoys package),
# this pushes the full development shell so CI can skip compiling
# 31 R packages that aren't on rstats-on-nix.
#
# When to run: Once after default.R/default.nix changes. Not needed on every push.
#
# Usage:
#   ./seed_dev_cache.sh
#
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Validation failed
#   3 - Build failed
#   4 - Push failed

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_step() { echo -e "${BLUE}$1${NC}"; }
log_success() { echo -e "${GREEN}$1${NC}"; }
log_error() { echo -e "${RED}ERROR: $1${NC}"; }
log_info() { echo -e "${NC}$1${NC}"; }

main() {
  echo "==========================================================="
  echo "   Seed johngavin cachix with dev shell"
  echo "==========================================================="
  echo ""

  # STEP 1: Validate environment
  log_step "Step 1/3: Validating environment..."

  if [ ! -f "default.nix" ]; then
    log_error "default.nix not found. Run from irishbuoys package root."
    exit 2
  fi

  if ! command -v nix-build &> /dev/null; then
    log_error "nix-build not found. Install Nix first."
    exit 2
  fi

  if ! command -v cachix &> /dev/null; then
    log_error "cachix not found."
    log_info "Install: nix-env -iA cachix -f https://cachix.org/api/v1/install"
    exit 2
  fi

  log_success "Environment validated"
  echo ""

  # STEP 2: Build dev shell
  log_step "Step 2/3: Building dev shell with nix-build..."
  log_info "This may take several minutes on first build..."

  RESULT=$(nix-build default.nix -A shell --no-out-link 2>/dev/null)

  if [ -z "$RESULT" ] || [ ! -e "$RESULT" ]; then
    log_error "nix-build failed. Check default.nix syntax."
    exit 3
  fi

  TOTAL_PATHS=$(nix-store -qR "$RESULT" | wc -l | tr -d ' ')
  R_PKG_PATHS=$(nix-store -qR "$RESULT" | grep -c "/nix/store/[a-z0-9]*-r-" || echo 0)

  log_success "Built: $RESULT"
  log_info "Closure: $TOTAL_PATHS paths ($R_PKG_PATHS R packages)"
  echo ""

  # STEP 3: Push to cachix
  log_step "Step 3/3: Pushing to johngavin cachix..."
  log_info "This pushes ALL paths (R packages + system libs) so CI gets binary hits."

  echo "$RESULT" | cachix push johngavin

  if [ $? -eq 0 ]; then
    log_success "Push complete"
  else
    log_error "Push failed"
    exit 4
  fi

  echo ""
  echo "==========================================================="
  log_success "SUCCESS! Dev shell pushed to johngavin cachix"
  echo "==========================================================="
  echo ""
  echo "What this means:"
  echo "  - CI will now pull $R_PKG_PATHS R packages as binaries"
  echo "  - No more compiling from source on cold CI runs"
  echo ""
  echo "When to re-run:"
  echo "  - After changing default.R / default.nix (new deps)"
  echo "  - Or use the seed-cachix.yml GitHub Action (weekly)"
  echo ""
  echo "Monitor: https://app.cachix.org/cache/johngavin"
  echo ""
}

main "$@"
