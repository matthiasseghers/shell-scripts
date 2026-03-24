#!/usr/bin/env bash
# install-deps.sh — install all dependencies required by shell scripts and their tests.
# Dependencies are declared in deps.brew files colocated with each script category.
#
# Usage:
#   ./install-deps.sh              # install all deps
#   ./install-deps.sh --check      # check what's missing without installing
#   ./install-deps.sh --check <dir> # check only deps for a specific directory

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err() { echo -e "${RED}✗${NC}  $*"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

check_only=false
search_dir="$SCRIPT_DIR/scripts"

if [[ "${1:-}" == "--check" ]]; then
  check_only=true
  [[ -n "${2:-}" ]] && search_dir="$2"
fi

# Collect all packages from deps.brew files, deduplicated
mapfile -t PACKAGES < <(find "$search_dir" -name "deps.brew" -exec cat {} + | sort -u | grep -v '^#' | grep -v '^$')

if [[ ${#PACKAGES[@]} -eq 0 ]]; then
  warn "No deps.brew files found under $search_dir"
  exit 0
fi

echo ""
echo "Checking dependencies..."
echo ""

missing=()
for pkg in "${PACKAGES[@]}"; do
  if command -v "$pkg" &>/dev/null; then
    ok "$pkg  ($(command -v "$pkg"))"
  else
    err "$pkg  not found"
    missing+=("$pkg")
  fi
done

echo ""

if [[ ${#missing[@]} -eq 0 ]]; then
  ok "All dependencies already installed."
  echo ""
  exit 0
fi

if $check_only; then
  warn "Run ./install-deps.sh to install missing dependencies."
  echo ""
  exit 1
fi

echo "Installing missing dependencies..."
echo ""
brew install "${missing[@]}"

echo ""
ok "All dependencies installed."
echo ""
