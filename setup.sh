#!/usr/bin/env bash
# setup.sh — One-time repo setup: install dev tooling and git hooks.
# Run this once after cloning.
#
# Usage: ./setup.sh

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err() { echo -e "${RED}✗${NC}  $*"; }

echo ""
echo "Setting up repository..."
echo ""

# ── Install pre-commit ────────────────────────────────────────────────────────
if ! command -v pre-commit &>/dev/null; then
  echo "Installing pre-commit..."
  brew install pre-commit
fi
ok "pre-commit  ($(command -v pre-commit))"

# ── Install git hooks via pre-commit ─────────────────────────────────────────
echo ""
echo "Installing git hooks..."
pre-commit install
echo ""
ok "Git hooks installed."

# ── Install script dependencies ───────────────────────────────────────────────
echo ""
echo "Installing script dependencies..."
./install-deps.sh

echo ""
ok "Setup complete. You're ready to go."
echo ""
