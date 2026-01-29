#!/bin/bash

# =========================================
# Integration Test Runner Script
# Runs slow integration tests that process actual files
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
echo -e "${BLUE}🔬 Running Integration Tests${NC}"
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

# Check if ffmpeg is installed (needed for video tests)
if ! command -v ffmpeg >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Warning: ffmpeg not found. Video integration tests will fail.${NC}"
  echo ""
fi

# Check if tesseract is installed (needed for OCR tests)
if ! command -v tesseract >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠️  Warning: tesseract not found. OCR integration tests will fail.${NC}"
  echo ""
fi

echo -e "${YELLOW}⚠️  Integration tests may take several minutes to complete.${NC}"
echo -e "${YELLOW}   They process actual video files and perform real OCR.${NC}"
echo ""

# Enable integration tests
export RUN_INTEGRATION_TESTS=1

# Run integration tests
echo -e "${BLUE}Running integration tests...${NC}"
echo ""

if bats --timing --show-output-of-passing-tests tests/**/*.integration.bats "$@"; then
  echo ""
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${GREEN}✅ All integration tests passed!${NC}"
  echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 0
else
  echo ""
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo -e "${RED}❌ Some integration tests failed${NC}"
  echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
  echo ""
  exit 1
fi
