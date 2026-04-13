#!/usr/bin/env bash
# extract_markers.sh — Extract markers from an FCP FCPXML/FCPXMLD file.
# Outputs a YouTube-format chapter timestamp file to the same directory as the input.
#
# Usage:
#   ./extract_markers.sh <path-to-fcpxml-or-fcpxmld>

set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

ok() { echo -e "${GREEN}✓${NC}  $*"; }
err() { echo -e "${RED}✗${NC}  $*"; }

# ─────────────────────────────────────────────
# Argument check
# ─────────────────────────────────────────────

if [[ -z "${1:-}" ]]; then
  echo ""
  echo "Usage: $(basename "$0") <path-to-fcpxml-or-fcpxmld>"
  echo ""
  echo "Example:"
  echo "  $(basename "$0") ~/Desktop/MyVideo.fcpxmld"
  echo ""
  exit 1
fi

FCPXML_PATH="$1"

if [[ ! -e "$FCPXML_PATH" ]]; then
  err "File not found: $FCPXML_PATH"
  exit 1
fi

# ─────────────────────────────────────────────
# Dependency check
# ─────────────────────────────────────────────

if ! command -v markers-extractor &>/dev/null; then
  echo "markers-extractor not found — installing..."
  echo ""
  brew tap TheAcharya/homebrew-tap
  brew install TheAcharya/homebrew-tap/markers-extractor
  echo ""
fi

# ─────────────────────────────────────────────
# Run
# ─────────────────────────────────────────────

OUTPUT_DIR="$(dirname "$FCPXML_PATH")"

echo ""
echo "Input:  $FCPXML_PATH"
echo "Output: $OUTPUT_DIR"
echo ""

markers-extractor "$FCPXML_PATH" "$OUTPUT_DIR" --export-format youtube

echo ""
ok "Done. YouTube chapters written to: $OUTPUT_DIR"
echo ""
