#!/usr/bin/env bash
#
# push_to_cachix.sh - Push ONLY this project's R package to johngavin cachix
#
# CRITICAL: Only the single project derivation is pushed. Standard R packages
# (dplyr, arrow, duckdb, etc.) are ALREADY on rstats-on-nix and must NEVER
# be pushed to johngavin.
#
# METHOD: Before pushing, the script pre-checks that all R package
# dependencies are ALREADY in the johngavin cache. If they are,
# `cachix push` skips them and pushes only the new irishbuoys path
# (1 path). If deps are NOT cached, the script ABORTS to prevent
# pushing 30+ dependency packages.
#
# FIRST-TIME SETUP: If this is the first push ever (empty cache),
# manually seed the cache once:
#   RESULT=$(nix-build package.nix --no-out-link)
#   echo "$RESULT" | cachix push johngavin
# Then subsequent pushes via this script will push only 1 path.
#
# WARNING: Do NOT use `cachix push johngavin $PATH` or
# `echo $PATH | cachix push johngavin` - BOTH push the entire closure
# (all runtime dependencies), wasting cachix quota on packages that
# are already available from rstats-on-nix.
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
  log_step "Step 1/4: Validating environment..."

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
  log_step "Step 2/4: Reading package information..."

  PKG_NAME=$(grep "^Package:" DESCRIPTION | awk '{print $2}' | tr -d '\r' || echo "")
  PKG_VERSION=$(grep "^Version:" DESCRIPTION | awk '{print $2}' | tr -d '\r' || echo "")

  if [ -z "$PKG_NAME" ] || [ -z "$PKG_VERSION" ]; then
    log_error "Could not read package name/version from DESCRIPTION"
    exit 2
  fi

  log_success "Package: $PKG_NAME v$PKG_VERSION"
  echo ""

  # STEP 3: Build package
  log_step "Step 3/4: Building package with nix-build..."
  log_info "This may take a few minutes on first build..."

  RESULT=$(nix-build package.nix --no-out-link 2>&1 | tail -1)

  if [ -z "$RESULT" ] || { [ ! -d "$RESULT" ] && [ ! -L "$RESULT" ]; }; then
    log_error "nix-build failed"
    log_info "Check syntax: nix-instantiate --parse package.nix"
    exit 3
  fi

  log_success "Built: $RESULT"
  echo ""

  # STEP 4: Pre-check then push ONLY this package
  #
  # `cachix push` ALWAYS pushes the full closure. There is no flag to
  # prevent this. However, it SKIPS paths already present in the cache.
  #
  # Strategy: Before pushing, verify that all R package dependencies
  # are ALREADY in the johngavin cache (from a previous push or manual
  # seed). If they are, `cachix push` will skip them and push only the
  # new irishbuoys path (1 path). If deps are NOT cached, we ABORT
  # to prevent pushing 30+ dependency packages.
  #
  # First-time setup: If this is the first push ever, manually seed
  # the cache once with: echo "$RESULT" | cachix push johngavin
  # Subsequent pushes via this script will then push only 1 path.
  #
  log_step "Step 4/4: Pushing ONLY $PKG_NAME to johngavin cachix..."

  # Pre-check: verify R package deps are already cached on johngavin, rstats-on-nix,
  # or cache.nixos.org. If a dep is on any of these, cachix push will skip it.
  log_info "Pre-check: verifying dependencies are already cached..."
  UNCACHED_DEPS=0
  UNCACHED_LIST=""
  for path in $(nix-store -qR "$RESULT" | grep -E "/nix/store/[a-z0-9]+-r-" | grep -v "r-${PKG_NAME}"); do
    HASH=$(basename "$path" | cut -c1-32)
    JG_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 5 "https://johngavin.cachix.org/${HASH}.narinfo" 2>/dev/null || echo "000")
    RON_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 5 "https://rstats-on-nix.cachix.org/${HASH}.narinfo" 2>/dev/null || echo "000")
    NIX_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      --max-time 5 "https://cache.nixos.org/${HASH}.narinfo" 2>/dev/null || echo "000")
    if [ "$JG_CODE" != "200" ] && [ "$RON_CODE" != "200" ] && [ "$NIX_CODE" != "200" ]; then
      UNCACHED_DEPS=$((UNCACHED_DEPS + 1))
      UNCACHED_LIST="${UNCACHED_LIST}  ${path}\n"
    fi
  done

  if [ "$UNCACHED_DEPS" -gt 0 ]; then
    log_error "ABORT: $UNCACHED_DEPS R package dependencies are NOT in johngavin cache."
    log_error "Pushing would upload these dependencies (forbidden)."
    echo -e "$UNCACHED_LIST" | head -10
    echo ""
    log_error "Fix: seed the cache once with the full closure:"
    log_info "  echo '$RESULT' | cachix push johngavin"
    log_info "Then re-run ./push_to_cachix.sh (subsequent pushes will be 1 path only)."
    exit 4
  fi

  DEP_COUNT=$(nix-store -qR "$RESULT" | grep -E "/nix/store/[a-z0-9]+-r-" | grep -cv "r-${PKG_NAME}" || echo 0)
  log_success "All $DEP_COUNT R package deps already cached"
  log_info "Pushing (only new paths will be uploaded)..."

  PUSH_LOG="/tmp/cachix-push-${PKG_NAME}.log"

  if ! retry_command 3 5 "echo '$RESULT' | cachix push johngavin > '$PUSH_LOG' 2>&1"; then
    log_error "Failed to push to cachix after 3 attempts"
    log_info "Check network: https://status.cachix.org/"
    log_info "Push log: $PUSH_LOG"
    exit 4
  fi

  # Post-check: verify push count
  # Count R package paths pushed (pattern: /nix/store/...-r-<name>)
  # System library deps (fontconfig, curl, etc.) are harmless — they're small
  # and get pushed when nixpkgs updates introduce new derivation hashes.
  PUSHED_TOTAL=$(grep -c "^Pushing /nix/store/" "$PUSH_LOG" 2>/dev/null || echo 0)
  PUSHED_RPKGS=$(grep "^Pushing /nix/store/" "$PUSH_LOG" 2>/dev/null | grep -c "/nix/store/[a-z0-9]*-r-" || echo 0)
  PUSHED_SYSLIBS=$((PUSHED_TOTAL - PUSHED_RPKGS))

  if [ "$PUSHED_RPKGS" -gt 1 ]; then
    log_error "ABORT: Pushed $PUSHED_RPKGS R package paths (strict limit is 1)!"
    log_error "The pre-check passed but cachix still pushed R dependencies."
    log_error "R package paths pushed:"
    grep "^Pushing /nix/store/" "$PUSH_LOG" | grep "/nix/store/[a-z0-9]*-r-"
    log_info "Push log preserved at: $PUSH_LOG"
    exit 4
  elif [ "$PUSHED_RPKGS" -eq 1 ]; then
    log_success "Pushed exactly 1 R package path (correct)"
  else
    log_info "R package already in cache (0 new R package paths pushed)"
  fi

  if [ "$PUSHED_SYSLIBS" -gt 0 ]; then
    log_warning "Also pushed $PUSHED_SYSLIBS system library paths (harmless, from nixpkgs updates):"
    grep "^Pushing /nix/store/" "$PUSH_LOG" | grep -v "/nix/store/[a-z0-9]*-r-"
  fi

  rm -f "$PUSH_LOG"
  echo ""

  # STEP 5: Pin package (only for release versions)
  log_step "Step 4/4: Pinning $PKG_NAME v$PKG_VERSION..."

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
