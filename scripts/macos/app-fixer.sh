#!/bin/bash
# app-fixer.sh — Sign & remove quarantine attributes from a macOS app or file
# Usage: ./app-fixer.sh [/path/to/app]
# If no argument is given, prompts for a drag-and-drop path.

# ── Colors for output ────────────────────────────────────────────────────────
GREEN='\033[0;32m'
RED='\033[0;31m'
BOLD='\033[1m'
RESET='\033[0m'

# ── Resolve target ────────────────────────────────────────────────────────────
TARGET="$1"

if [ -z "$TARGET" ]; then
  echo "========================================="
  echo "  Mac App Fixer - Sign & DeQuarantine"
  echo "========================================="
  echo ""
  echo "Drag and drop your file or app here, then press Enter:"
  read -e TARGET
  TARGET=$(echo "$TARGET" | sed "s/^'//" | sed "s/'$//")
  if [ -z "$TARGET" ]; then
    echo "No file provided. Exiting."
    exit 1
  fi
fi

if [ ! -e "$TARGET" ]; then
  echo -e "${RED}Error: File not found: $TARGET${RESET}"
  exit 1
fi

echo ""
echo -e "${BOLD}Processing:${RESET} $TARGET"
echo ""

echo "Step 1: Running xattr -cr..."
sudo xattr -cr "$TARGET"

echo "Step 2: Running codesign..."
sudo codesign --force --deep --sign - "$TARGET"

echo ""
echo -e "${GREEN}✓ Done! All commands completed.${RESET}"
echo ""
echo "Press any key to close..."
read -rn 1
