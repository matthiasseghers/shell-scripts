#!/bin/bash

# =========================================
# Test Runner Script
# Runs all tests and provides formatted output
# =========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Running Shell Script Tests${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if bats is installed
if ! command -v bats >/dev/null 2>&1; then
  echo -e "${RED}❌ Error: bats is not installed${NC}"
  echo ""
  echo "Install with:"
  echo "  macOS:   brew install bats-core"
  echo "  Linux:   sudo apt-get install bats"
  echo ""
  exit 1
fi

# Check if ffmpeg is installed (needed for test video creation)
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Warning: ffmpeg not found. Some tests may fail.${NC}"
  echo ""
fi

# Run tests
echo -e "${BLUE}Running tests...${NC}"
echo ""

if bats tests/**/*.bats "$@"; then
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✅ All tests passed!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 0
else
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}❌ Some tests failed${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 1
fi
