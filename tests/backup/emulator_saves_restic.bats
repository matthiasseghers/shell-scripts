#!/usr/bin/env bats

# Test suite for emulator_saves_restic.sh script
# Run with: bats tests/backup/emulator_saves_restic.bats

setup() {
  export SCRIPT="./scripts/backup/emulator_saves_restic.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_restic_emulator_test"
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
  
  run grep -q "BACKUP_SOURCES" "$SCRIPT"
  [ "$status" -eq 0 ]
  
  run grep -q "BACKUP_REPO" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains keep options for retention policy" {
  run grep -q "KEEP_OPTIONS" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Backup Sources Tests
# ==========================================

@test "backup sources is defined as an array" {
  run grep "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "(" ]]
}

@test "backup sources includes PCSX2 saves" {
  run grep -A 5 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "PCSX2" ]]
}

@test "backup sources includes DuckStation saves" {
  run grep -A 5 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "DuckStation" ]]
}

@test "backup sources includes 3DS Checkpoint saves" {
  run grep -A 5 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "Checkpoint" ]]
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

@test "backup command uses array expansion for sources" {
  run grep "backup" "$SCRIPT"
  [[ "$output" =~ "BACKUP_SOURCES[@]" ]] || [[ "$output" =~ 'BACKUP_SOURCES\[@\]' ]]
}

# ==========================================
# Repository Configuration Tests
# ==========================================

@test "repository is in HOME directory" {
  run grep "BACKUP_REPO=" "$SCRIPT"
  [[ "$output" =~ "HOME" ]] || [[ "$output" =~ "\$HOME" ]]
}

@test "password file is in HOME directory" {
  run grep "RESTIC_PASSWD=" "$SCRIPT"
  [[ "$output" =~ "HOME" ]] || [[ "$output" =~ "\$HOME" ]]
}

@test "repository path includes restic in name" {
  run grep "BACKUP_REPO=" "$SCRIPT"
  [[ "$output" =~ "restic" ]]
}

# ==========================================
# Retention Policy Tests
# ==========================================

@test "retention policy includes hourly backups" {
  run grep "KEEP_OPTIONS" "$SCRIPT"
  [[ "$output" =~ "keep-hourly" ]]
}

@test "retention policy includes daily backups" {
  run grep "KEEP_OPTIONS" "$SCRIPT"
  [[ "$output" =~ "keep-daily" ]]
}

@test "retention policy includes weekly backups" {
  run grep "KEEP_OPTIONS" "$SCRIPT"
  [[ "$output" =~ "keep-weekly" ]]
}

@test "retention policy includes monthly backups" {
  run grep "KEEP_OPTIONS" "$SCRIPT"
  [[ "$output" =~ "keep-monthly" ]]
}

# ==========================================
# Command Options Tests
# ==========================================

@test "forget command includes prune option" {
  run grep -q "forget.*--prune" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "forget command includes cleanup-cache option" {
  run grep -q "forget.*--cleanup-cache" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "commands use password file authentication" {
  run grep -c "\-p.*RESTIC_PASSWD" "$SCRIPT"
  [ "$status" -eq 0 ]
  # Should appear in unlock, backup, and forget commands (3 times)
}

@test "commands specify repository location" {
  run grep -c "\-r.*BACKUP_REPO" "$SCRIPT"
  [ "$status" -eq 0 ]
  # Should appear in unlock, backup, and forget commands (3 times)
}

# ==========================================
# Best Practices Tests
# ==========================================

@test "script has shebang" {
  run head -n 1 "$SCRIPT"
  [[ "$output" =~ "#!/bin/bash" ]]
}

@test "script defines variables before using them" {
  # Check that variable definitions come before restic commands
  local vars_line=$(grep -n "RESTIC_PASSWD=" "$SCRIPT" | cut -d: -f1)
  local first_cmd=$(grep -n "restic.*unlock" "$SCRIPT" | cut -d: -f1)
  [ "$vars_line" -lt "$first_cmd" ]
}

@test "backup sources use absolute paths" {
  run grep -A 5 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "HOME" ]] || [[ "$output" =~ "/" ]]
}

# ==========================================
# Emulator-Specific Tests
# ==========================================

@test "includes save paths for multiple emulators" {
  run grep -A 5 "BACKUP_SOURCES=" "$SCRIPT"
  # Should have Application Support path
  [[ "$output" =~ "Application Support" ]]
}

@test "uses Application Support directory for macOS emulators" {
  run grep -A 5 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "Application Support" ]]
}
