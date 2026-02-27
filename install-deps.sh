#!/usr/bin/env bash
# install-deps.sh — install all dependencies required by shell scripts and their tests.
# Called by CI workflows and can be run locally to get set up from scratch.
#
# Usage:
#   ./install-deps.sh           # install all deps
#   ./install-deps.sh --check   # check what's missing without installing

set -e

# ===========================================================================
# Dependency manifest — add new tools here only
# ===========================================================================

# apt package name       brew package name      binary to check
DEPS=(
  "ffmpeg                ffmpeg                 ffprobe"
  "imagemagick           imagemagick            magick"
  "tesseract-ocr         tesseract              tesseract"
)

# ===========================================================================
# Helpers
# ===========================================================================

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC}  $*"; }
warn() { echo -e "${YELLOW}⚠${NC}  $*"; }
err()  { echo -e "${RED}✗${NC}  $*"; }

detect_os() {
  if [[ "$RUNNER_OS" == "Linux" ]] || [[ "$(uname -s)" == "Linux" ]]; then
    echo "linux"
  elif [[ "$RUNNER_OS" == "macOS" ]] || [[ "$(uname -s)" == "Darwin" ]]; then
    echo "macos"
  else
    echo "unknown"
  fi
}

check_only=false
[[ "${1:-}" == "--check" ]] && check_only=true

OS=$(detect_os)
missing_apt=()
missing_brew=()
all_present=true

# ===========================================================================
# Check what's installed
# ===========================================================================

echo ""
echo "Checking dependencies..."
echo ""

for dep in "${DEPS[@]}"; do
  read -r apt_pkg brew_pkg binary <<< "$dep"
  if command -v "$binary" &>/dev/null; then
    ok "$binary  ($(command -v "$binary"))"
  else
    err "$binary  not found"
    all_present=false
    missing_apt+=("$apt_pkg")
    missing_brew+=("$brew_pkg")
  fi
done

echo ""

# ===========================================================================
# Install if needed
# ===========================================================================

if $all_present; then
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

if [[ "$OS" == "linux" ]]; then
  sudo apt-get update -qq
  sudo apt-get install -y "${missing_apt[@]}"
elif [[ "$OS" == "macos" ]]; then
  brew install "${missing_brew[@]}"
else
  err "Unknown OS — please install dependencies manually:"
  for dep in "${DEPS[@]}"; do
    read -r apt_pkg brew_pkg binary <<< "$dep"
    if ! command -v "$binary" &>/dev/null; then
      echo "   $binary  (apt: $apt_pkg / brew: $brew_pkg)"
    fi
  done
  exit 1
fi

echo ""
ok "All dependencies installed."
echo ""