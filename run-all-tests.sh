#!/bin/bash

# =========================================
# All Tests Runner Script
# Runs both unit tests and integration tests
# =========================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}🧪 Running All Tests (Unit + Integration)${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Run unit tests first
echo -e "${BLUE}Step 1/2: Running unit tests...${NC}"
echo ""

if ! ./run-tests.sh "$@"; then
  echo ""
  echo -e "${RED}❌ Unit tests failed. Skipping integration tests.${NC}"
  exit 1
fi

echo ""
echo -e "${BLUE}Step 2/2: Running integration tests...${NC}"
echo ""

if ! ./run-integration-tests.sh "$@"; then
  echo ""
  echo -e "${RED}❌ Integration tests failed.${NC}"
  exit 1
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ All tests passed (unit + integration)!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
