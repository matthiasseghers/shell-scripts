#!/usr/bin/env bats

# Unit tests for emulator_saves_restic.sh
# These tests validate script structure only — no restic or filesystem required.
# Run with: bats tests/backup/emulator_saves_restic.bats

setup() {
  export SCRIPT="./scripts/backup/emulator_saves_restic.sh"
}

# ==========================================
# Script Basics
# ==========================================

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script has bash shebang" {
  run head -n 1 "$SCRIPT"
  [[ "$output" =~ "#!/bin/bash" ]]
}

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

# ==========================================
# Configuration Variables
# ==========================================

@test "script defines RESTIC_PASSWD" {
  run grep -q "RESTIC_PASSWD=" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script defines BACKUP_REPO" {
  run grep -q "BACKUP_REPO=" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script defines BACKUP_SOURCES array" {
  run grep -q "BACKUP_SOURCES=" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script defines KEEP_OPTIONS" {
  run grep -q "KEEP_OPTIONS=" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "RESTIC_PASSWD references HOME" {
  run grep "RESTIC_PASSWD=" "$SCRIPT"
  [[ "$output" =~ "HOME" ]]
}

@test "BACKUP_REPO references HOME" {
  run grep "BACKUP_REPO=" "$SCRIPT"
  [[ "$output" =~ "HOME" ]]
}

# ==========================================
# Emulator Coverage
# ==========================================

@test "BACKUP_SOURCES includes PCSX2" {
  run grep -A20 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "PCSX2" ]]
}

@test "BACKUP_SOURCES includes DuckStation" {
  run grep -A20 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "DuckStation" ]]
}

@test "BACKUP_SOURCES includes Dolphin" {
  run grep -A20 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "Dolphin" ]]
}

@test "BACKUP_SOURCES includes PPSSPP" {
  run grep -A20 "BACKUP_SOURCES=" "$SCRIPT"
  [[ "$output" =~ "PPSSPP" ]]
}

# ==========================================
# Restic Command Sequence
# ==========================================

@test "script runs restic unlock" {
  run grep -q "restic.*unlock" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script runs restic backup" {
  run grep -q "restic.*backup" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script runs restic forget" {
  run grep -q "restic.*forget" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script runs restic prune or forget --prune" {
  run grep -q "prune" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script runs restic cache cleanup" {
  run grep -q "restic.*cache" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restic forget uses KEEP_OPTIONS" {
  run grep "restic.*forget" "$SCRIPT"
  [[ "$output" =~ "KEEP_OPTIONS" ]]
}

@test "restic commands use RESTIC_PASSWD" {
  # Every restic invocation should reference the password variable
  local restic_lines
  restic_lines=$(grep "^restic" "$SCRIPT" | grep -v "RESTIC_PASSWD")
  [ -z "$restic_lines" ]
}

@test "restic commands use BACKUP_REPO" {
  local restic_lines
  restic_lines=$(grep "^restic" "$SCRIPT" | grep -v "BACKUP_REPO")
  [ -z "$restic_lines" ]
}

# ==========================================
# Retention Policy
# ==========================================

@test "KEEP_OPTIONS includes --keep-daily" {
  run grep "KEEP_OPTIONS=" "$SCRIPT"
  [[ "$output" =~ "--keep-daily" ]]
}

@test "KEEP_OPTIONS includes --keep-weekly" {
  run grep "KEEP_OPTIONS=" "$SCRIPT"
  [[ "$output" =~ "--keep-weekly" ]]
}

@test "KEEP_OPTIONS includes --keep-monthly" {
  run grep "KEEP_OPTIONS=" "$SCRIPT"
  [[ "$output" =~ "--keep-monthly" ]]
}
