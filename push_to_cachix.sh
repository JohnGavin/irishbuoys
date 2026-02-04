#!/usr/bin/env bash
set -euo pipefail

# Push irishbuoys package to Cachix
# This script follows the 9-step workflow (Step 5)

CACHE_NAME="johngavin"

echo "📦 Building and pushing irishbuoys environment to Cachix..."

# Check if in Nix shell or can access nix-shell
if ! command -v nix-shell &> /dev/null; then
    echo "❌ Error: nix-shell not found. Install Nix first."
    exit 1
fi

# Ensure cachix is available
if ! nix-shell -p cachix --run "cachix --version" &> /dev/null; then
    echo "❌ Error: cachix not available"
    exit 1
fi

echo "🔨 Building irishbuoys environment..."

# Get all store paths from the shell's buildInputs
PATHS=$(nix-shell ./default.nix --run 'echo $buildInputs' 2>/dev/null)

if [ -z "$PATHS" ]; then
    echo "❌ Error: Could not get buildInputs from default.nix"
    exit 1
fi

echo "📤 Pushing $(echo "$PATHS" | wc -w | tr -d ' ') packages to Cachix ($CACHE_NAME)..."

# Push all paths to cachix
nix-shell -p cachix --run "echo '$PATHS' | tr ' ' '\n' | cachix push $CACHE_NAME"

echo "✅ Successfully pushed to Cachix!"
echo "🎉 Cachix push complete!"
echo ""
echo "Others can now use this cache by adding to their nix config:"
echo "  nix-shell -p cachix --run 'cachix use $CACHE_NAME'"
