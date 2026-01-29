#!/usr/bin/env bats

# Test suite for emulator_saves_manual.sh script
# Run with: bats tests/backup/emulator_saves_manual.bats

setup() {
  export SCRIPT="./scripts/backup/emulator_saves_manual.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_emulator_manual_test"
  mkdir -p "$TEST_OUTPUT_DIR"
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
}

# ==========================================
# Help and Usage Tests
# ==========================================

@test "shows usage when no arguments provided" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "Supported emulators:" ]]
}

@test "shows usage when only emulator provided" {
  run "$SCRIPT" pcsx2
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Missing action" ]]
}

@test "usage shows supported emulators" {
  run "$SCRIPT"
  [[ "$output" =~ "pcsx2" ]]
  [[ "$output" =~ "dolphin" ]]
  [[ "$output" =~ "ppsspp" ]]
  [[ "$output" =~ "duckstation" ]]
}

# ==========================================
# Emulator Validation Tests
# ==========================================

@test "rejects unsupported emulator" {
  run "$SCRIPT" unsupported --list
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unsupported emulator" ]]
}

@test "accepts pcsx2 emulator" {
  skip "Requires interactive input or directory setup"
  run "$SCRIPT" pcsx2 --list
  [ "$status" -eq 0 ]
}

@test "accepts dolphin emulator" {
  skip "Requires interactive input or directory setup"
  run "$SCRIPT" dolphin --list
  [ "$status" -eq 0 ]
}

@test "accepts ppsspp emulator" {
  skip "Requires interactive input or directory setup"
  run "$SCRIPT" ppsspp --list
  [ "$status" -eq 0 ]
}

@test "accepts duckstation emulator" {
  skip "Requires interactive input or directory setup"
  run "$SCRIPT" duckstation --list
  [ "$status" -eq 0 ]
}

# ==========================================
# Command Structure Tests
# ==========================================

@test "script contains archive action" {
  run grep -q "\-\-archive" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains list action" {
  run grep -q "\-\-list" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains restore action" {
  run grep -q "\-\-restore" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive action has short form -a" {
  run grep -q "\-a" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Backup Directory Tests
# ==========================================

@test "script defines backup base directory" {
  run grep -q "BACKUP_BASE_DIR" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script uses Application Support path" {
  run grep -q "Application Support" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script defines emulator paths" {
  run grep -q "EMULATOR_PATHS" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Archive Operation Tests
# ==========================================

@test "archive command uses zip format" {
  run grep -q "zip" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive includes timestamp in filename" {
  run grep -q "TIMESTAMP.*date" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive verification is performed" {
  run grep -q "zip -T" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Restore Operation Tests
# ==========================================

@test "restore requires backup name argument" {
  run "$SCRIPT" pcsx2 --restore
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]] || [[ "$output" =~ "backup_name" ]]
}

@test "restore checks if backup exists" {
  run grep -q "does not exist" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore handles zip files" {
  run grep -q "unzip" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Function Tests
# ==========================================

@test "script has check_and_create_directory function" {
  run grep -q "check_and_create_directory()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has list_backups function" {
  run grep -q "list_backups()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has restore_backup function" {
  run grep -q "restore_backup()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has index_of function for emulator lookup" {
  run grep -q "index_of()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Array Structure Tests
# ==========================================

@test "script defines emulator names array" {
  run grep -q "EMULATOR_NAMES=" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "emulator names array contains expected emulators" {
  run grep "EMULATOR_NAMES=" "$SCRIPT"
  [[ "$output" =~ "pcsx2" ]]
  [[ "$output" =~ "dolphin" ]]
  [[ "$output" =~ "ppsspp" ]]
  [[ "$output" =~ "duckstation" ]]
}

# ==========================================
# Best Practices Tests
# ==========================================

@test "script has shebang" {
  run head -n 1 "$SCRIPT"
  [[ "$output" =~ "#!/bin/bash" ]]
}

@test "script checks for required arguments" {
  run grep -q "if.*-z.*\$1" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script provides user-friendly error messages" {
  run "$SCRIPT" invalid --list
  [[ "$output" =~ "Error:" ]]
}
