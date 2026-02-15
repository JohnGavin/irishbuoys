#!/usr/bin/env bash
#
# push_to_cachix.sh - Push ONLY this project's R package to johngavin cachix
#
# CRITICAL: Only the single project derivation is pushed. Standard R packages
# (dplyr, arrow, duckdb, etc.) are ALREADY on rstats-on-nix and must NEVER
# be pushed to johngavin. We use `echo $PATH | cachix push` (single path)
# instead of `cachix push $PATH` (which pushes the entire closure/all deps).
#
# Step 5 of 9-step workflow. Builds from package.nix, pushes ONE derivation.
#
# Usage:
#   ./push_to_cachix.sh
#
# Exit codes:
#   0 - Success
#   1 - General error
#   2 - Validation failed (missing files, not authenticated)
#   3 - Build failed (nix-build error)
#   4 - Push failed (cachix push error)
#   5 - Pin failed (cachix pin error)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Error handling
trap 'handle_error $? $LINENO' ERR

handle_error() {
  local exit_code=$1
  local line_number=$2
  echo -e "${RED}ERROR: Script failed at line ${line_number} with exit code ${exit_code}${NC}"
  echo -e "${YELLOW}Check the error message above for details${NC}"
  exit $exit_code
}

log_step() { echo -e "${BLUE}$1${NC}"; }
log_success() { echo -e "${GREEN}$1${NC}"; }
log_error() { echo -e "${RED}ERROR: $1${NC}"; }
log_warning() { echo -e "${YELLOW}WARNING: $1${NC}"; }
log_info() { echo -e "${NC}$1${NC}"; }

# Retry function with exponential backoff
retry_command() {
  local max_attempts="${1:-3}"
  local timeout="${2:-5}"
  local command="${@:3}"
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if eval "$command"; then
      return 0
    else
      if [ $attempt -lt $max_attempts ]; then
        local wait_time=$((timeout * attempt))
        log_warning "Attempt $attempt/$max_attempts failed. Retrying in ${wait_time}s..."
        sleep $wait_time
        ((attempt++))
      else
        log_error "All $max_attempts attempts failed"
        return 1
      fi
    fi
  done
}

main() {
  echo "==========================================================="
  echo "   Push irishbuoys to johngavin cachix"
  echo "==========================================================="
  echo ""

  # STEP 1: Validate environment
  log_step "Step 1/5: Validating environment..."

  if [ ! -f "DESCRIPTION" ]; then
    log_error "DESCRIPTION not found. Run from irishbuoys package root."
    exit 2
  fi

  if [ ! -f "package.nix" ]; then
    log_error "package.nix not found. Create it first."
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

  # STEP 2: Get package info
  log_step "Step 2/5: Reading package information..."

  PKG_NAME=$(grep "^Package:" DESCRIPTION | awk '{print $2}' | tr -d '\r' || echo "")
  PKG_VERSION=$(grep "^Version:" DESCRIPTION | awk '{print $2}' | tr -d '\r' || echo "")

  if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ]; then
    log_error "Could not read package name/version from DESCRIPTION"
    exit 2
  fi

  log_success "Package: $PKG_NAME v$PKG_VERSION"
  echo ""

  # STEP 3: Build package
  log_step "Step 3/5: Building package with nix-build..."
  log_info "This may take a few minutes on first build..."

  BUILD_LOG="/tmp/nix-build-${PKG_NAME}.log"
  if ! nix-build package.nix --no-out-link > "$BUILD_LOG" 2>&1; then
    log_error "nix-build failed"
    log_info "Build log: $BUILD_LOG"
    log_info "Check syntax: nix-instantiate --parse package.nix"
    tail -20 "$BUILD_LOG"
    exit 3
  fi

  RESULT=$(nix-build package.nix --no-out-link 2>&1)
  log_success "Built: $RESULT"
  echo ""

  # STEP 4: Push ONLY this package to cachix (not dependencies!)
  #
  # CRITICAL: `cachix push johngavin $PATH` pushes the ENTIRE closure
  # (all dependencies). That wastes quota pushing dplyr, arrow, etc.
  # that are already on rstats-on-nix.
  #
  # `echo $PATH | cachix push johngavin` pushes ONLY that single path.
  #
  log_step "Step 4/5: Pushing ONLY $PKG_NAME to johngavin cachix..."
  log_info "Single derivation only (dependencies are on rstats-on-nix)"

  if ! retry_command 3 5 "echo '$RESULT' | cachix push johngavin"; then
    log_error "Failed to push to cachix after 3 attempts"
    log_info "Check network connection"
    log_info "Check cachix status: https://status.cachix.org/"
    exit 4
  fi

  log_success "Pushed ONLY $PKG_NAME to johngavin cachix (1 path)"
  echo ""

  # STEP 5: Pin package (only for release versions)
  log_step "Step 5/5: Pinning $PKG_NAME v$PKG_VERSION..."

  if [[ "$PKG_VERSION" == *.9000 ]]; then
    log_warning "Development version detected (.9000 suffix)"
    log_info "Skipping pin - dev versions subject to garbage collection"
    echo ""
  else
    PIN_NAME="${PKG_NAME}-v${PKG_VERSION}"
    log_info "Release version - pinning forever"
    log_info "Pin name: $PIN_NAME"

    if ! retry_command 3 5 "cachix pin johngavin '$PIN_NAME' '$RESULT' --keep-forever"; then
      log_error "Failed to pin package after 3 attempts"
      log_warning "Package pushed but not pinned - may be garbage collected"
      log_info "Manually pin: cachix pin johngavin $PIN_NAME $RESULT --keep-forever"
      exit 5
    fi

    log_success "Pinned as $PIN_NAME (protected from GC forever)"
    echo ""
  fi

  # SUCCESS
  echo "==========================================================="
  if [[ "$PKG_VERSION" == *.9000 ]]; then
    log_success "SUCCESS! $PKG_NAME pushed to cachix (dev version, not pinned)"
  else
    log_success "SUCCESS! $PKG_NAME pushed and pinned to cachix"
  fi
  echo "==========================================================="
  echo ""
  echo "Pushed to johngavin cache:"
  if [[ "$PKG_VERSION" == *.9000 ]]; then
    echo "   $PKG_NAME v$PKG_VERSION ONLY (dev version - subject to GC)"
  else
    echo "   $PKG_NAME v$PKG_VERSION ONLY (pinned forever)"
  fi
  echo "   Dependencies NOT pushed (they are on rstats-on-nix)"
  echo ""
  echo "Links:"
  echo "   Monitor cache: https://app.cachix.org/cache/johngavin"
  echo "   Package: $RESULT"
  echo ""
  echo "Next steps:"
  echo "   1. Commit nix files if changed: git add package.nix"
  echo "   2. Push to GitHub: git push"
  echo ""
  echo "Note: Users pulling $PKG_NAME get dependencies from"
  echo "   rstats-on-nix cache, and only $PKG_NAME from johngavin cache"
  echo ""
}

main "$@"
