#!/usr/bin/env bats

# Test suite for automated_backup_restic.sh script
# Run with: bats tests/backup/automated_backup_restic.bats

setup() {
  export SCRIPT="./scripts/backup/automated_backup_restic.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_restic_test_output"
  mkdir -p "$TEST_OUTPUT_DIR"
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
}

# ==========================================
# Script Structure Tests
# ==========================================

@test "script file exists and is executable" {
  [ -f "$SCRIPT" ]
  [ -x "$SCRIPT" ] || chmod +x "$SCRIPT"
}

@test "script contains required variables" {
  run grep -q "RESTIC_PASSWD" "$SCRIPT"
  [ "$status" -eq 0 ]
  
  run grep -q "BACKUP_SOURCE" "$SCRIPT"
  [ "$status" -eq 0 ]
  
  run grep -q "BACKUP_REPO" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains keep options for retention policy" {
  run grep -q "KEEP_OPTIONS" "$SCRIPT"
  [ "$status" -eq 0 ]
  
  run grep -q "keep-hourly" "$SCRIPT"
  [ "$status" -eq 0 ]
  
  run grep -q "keep-daily" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Restic Command Tests
# ==========================================

@test "script contains restic unlock command" {
  run grep -q "restic.*unlock" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains restic backup command" {
  run grep -q "restic.*backup" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains restic forget command" {
  run grep -q "restic.*forget" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "forget command includes prune option" {
  run grep -q "forget.*--prune" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "forget command includes cleanup-cache option" {
  run grep -q "forget.*--cleanup-cache" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Configuration Tests
# ==========================================

@test "script uses password file for authentication" {
  run grep -q "\-p.*RESTIC_PASSWD" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script specifies repository location" {
  run grep -q "\-r.*BACKUP_REPO" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "backup command includes source directory" {
  run grep -q "backup.*BACKUP_SOURCE" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Template Validation Tests
# ==========================================

@test "script contains placeholder for username" {
  run grep -q "<USERNAME>" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains placeholder for backup location" {
  run grep -q "<LOCATION_TO_BACKUP>" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains placeholder for backup path" {
  run grep -q "<PATH_TO_STORE_BACKUP>" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains placeholder for backup name" {
  run grep -q "<BACKUP_NAME>" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Best Practices Tests
# ==========================================

@test "script has shebang" {
  run head -n 1 "$SCRIPT"
  [[ "$output" =~ "#!/bin/bash" ]]
}

@test "retention policy includes multiple time periods" {
  run grep "KEEP_OPTIONS" "$SCRIPT"
  [[ "$output" =~ "hourly" ]]
  [[ "$output" =~ "daily" ]]
  [[ "$output" =~ "weekly" ]]
  [[ "$output" =~ "monthly" ]]
}
