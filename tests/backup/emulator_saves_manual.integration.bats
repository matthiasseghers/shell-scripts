#!/usr/bin/env bats

# Integration tests for emulator_saves_manual.sh script
# These tests interact with filesystem and may require specific setup
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/backup/emulator_saves_manual.integration.bats

setup() {
  # Skip all tests unless explicitly enabled
  if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    skip "Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable"
  fi
  
  export SCRIPT="./scripts/backup/emulator_saves_manual.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_integration_emulator"
  export TEST_BACKUP_DIR="$TEST_OUTPUT_DIR/backups"
  export TEST_SAVES_DIR="$TEST_OUTPUT_DIR/saves"
  
  mkdir -p "$TEST_OUTPUT_DIR"
  mkdir -p "$TEST_BACKUP_DIR"
  mkdir -p "$TEST_SAVES_DIR"
  
  # Create mock save files
  echo "mock save data" > "$TEST_SAVES_DIR/save1.bin"
  echo "mock save data 2" > "$TEST_SAVES_DIR/save2.bin"
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
}

# ==========================================
# Emulator Path Tests
# ==========================================

@test "works with pcsx2 paths" {
  if [[ -d "$HOME/Library/Application Support/PCSX2/memcards" ]]; then
    # Pre-create backup directory to avoid interactive prompt
    local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
    mkdir -p "$backup_dir"
    
    run "$SCRIPT" pcsx2 --list
    [ "$status" -eq 0 ]
  else
    skip "PCSX2 directory not found on this system"
  fi
}

@test "works with dolphin paths" {
  if [[ -d "$HOME/Library/Application Support/Dolphin/GC" ]]; then
    # Pre-create backup directory to avoid interactive prompt
    local backup_dir="$HOME/Emulator_MemoryCard_Backups/dolphin"
    mkdir -p "$backup_dir"
    
    run "$SCRIPT" dolphin --list
    [ "$status" -eq 0 ]
  else
    skip "Dolphin directory not found on this system"
  fi
}

@test "works with ppsspp paths" {
  if [[ -d "$HOME/Library/Application Support/PPSSPP/memstick/PSP/SAVEDATA" ]]; then
    # Pre-create backup directory to avoid interactive prompt
    local backup_dir="$HOME/Emulator_MemoryCard_Backups/ppsspp"
    mkdir -p "$backup_dir"
    
    run "$SCRIPT" ppsspp --list
    [ "$status" -eq 0 ]
  else
    skip "PPSSPP directory not found on this system"
  fi
}

@test "works with duckstation paths" {
  # Check if DuckStation memcard directory exists
  if [[ -d "$HOME/Library/Application Support/DuckStation/memcards" ]]; then
    # Also need backup directory to exist to avoid interactive prompt
    local backup_dir="$HOME/Emulator_MemoryCard_Backups/duckstation"
    mkdir -p "$backup_dir"
    
    run "$SCRIPT" duckstation --list
    [ "$status" -eq 0 ]
  else
    skip "DuckStation directory not found on this system"
  fi
}

# ==========================================
# Archive Verification Tests
# ==========================================

@test "created zip passes integrity check" {
  # Create test archive
  local test_zip="$TEST_OUTPUT_DIR/test.zip"
  (cd "$TEST_SAVES_DIR" && zip -r "$test_zip" .)
  
  run zip -T "$test_zip"
  [ "$status" -eq 0 ]
}

@test "handles corrupted zip gracefully" {
  # Create invalid zip
  echo "not a zip file" > "$TEST_OUTPUT_DIR/corrupted.zip"
  
  run zip -T "$TEST_OUTPUT_DIR/corrupted.zip"
  [ "$status" -ne 0 ]
}
