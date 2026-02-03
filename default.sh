#!/usr/bin/env bash

# Fast Nix Shell with Persistent GC Root for irishbuoys package
# This script creates a persistent GC root to prevent garbage collection
# and provides fast subsequent shell entries

set -e  # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔄 Checking Nix environment for irishbuoys package...${NC}"

# Check if default.nix exists
if [ ! -f "default.nix" ]; then
    echo -e "${YELLOW}⚠️  default.nix not found. Generating from DESCRIPTION...${NC}"
    if [ -f "default.R" ]; then
        Rscript default.R
    else
        echo -e "${RED}❌ default.R not found. Cannot generate default.nix${NC}"
        exit 1
    fi
fi

# Check if GC root exists
if [ ! -e "nix-shell-root" ]; then
    echo -e "${YELLOW}🔨 Building Nix environment (first time - this may take a while)...${NC}"

    # Build the environment and create GC root
    nix-build shell.nix --out-link nix-shell-root 2>/dev/null || \
    nix-build default.nix --out-link nix-shell-root 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Could not build as derivation, trying nix-shell...${NC}"
        # If default.nix is not a derivation, use nix-instantiate
        nix-instantiate shell.nix --indirect --add-root nix-shell-root 2>/dev/null || \
        nix-instantiate default.nix --indirect --add-root nix-shell-root 2>/dev/null || {
            echo -e "${RED}❌ Failed to create GC root${NC}"
            echo -e "${YELLOW}Falling back to regular nix-shell (slower)...${NC}"
            exec nix-shell
        }
    }

    echo -e "${GREEN}✅ GC root created at ./nix-shell-root${NC}"
    echo -e "${GREEN}📌 Packages are now protected from garbage collection${NC}"
else
    echo -e "${GREEN}✅ Using cached Nix environment (fast!)${NC}"
fi

# Enter the Nix shell
echo -e "${GREEN}🚀 Entering Nix shell for irishbuoys...${NC}"
echo -e "${YELLOW}💡 Tip: To rebuild, run: rm nix-shell-root && ./default.sh${NC}"

# CRITICAL: Pure mode enforcement for reproducibility and security
echo ""
echo -e "${GREEN}🔒 SECURITY: Running in --pure mode${NC}"
echo -e "${GREEN}   ✓ Only Nix-provided tools available in PATH${NC}"
echo -e "${GREEN}   ✓ System tools blocked (reproducibility guaranteed)${NC}"
echo -e "${GREEN}   ✓ Verify with: echo \$IN_NIX_SHELL  # Should show 'pure'${NC}"
echo ""

# Pass required environment variables explicitly through pure mode
# HOME: Required for R library paths and config files
# USER: Required for git commits
# GITHUB_TOKEN/GH_TOKEN: Required for gh CLI authentication
# CACHIX_AUTH_TOKEN: Required for Nix binary cache
# LANG/LC_ALL: Required for proper locale handling
exec nix-shell --pure \
  --keep HOME \
  --keep USER \
  --keep GITHUB_TOKEN \
  --keep GH_TOKEN \
  --keep CACHIX_AUTH_TOKEN \
  --keep LANG \
  --keep LC_ALL \
  default.nix