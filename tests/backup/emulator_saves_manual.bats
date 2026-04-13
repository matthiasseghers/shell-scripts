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
  [[ "$output" =~ "Supported emulators:" ]] || [[ "$output" =~ "Emulators" ]]
}

@test "shows usage when only emulator provided" {
  run "$SCRIPT" pcsx2
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "usage lists all supported emulators" {
  run "$SCRIPT"
  [[ "$output" =~ "pcsx2" ]]
  [[ "$output" =~ "dolphin" ]]
  [[ "$output" =~ "ppsspp" ]]
  [[ "$output" =~ "duckstation" ]]
}

@test "usage mentions all action" {
  run "$SCRIPT"
  [[ "$output" =~ "all" ]]
}

@test "usage mentions --restore-latest action" {
  run "$SCRIPT"
  [[ "$output" =~ "--restore-latest" ]]
}

@test "usage mentions --prune action" {
  run "$SCRIPT"
  [[ "$output" =~ "--prune" ]]
}

# ==========================================
# Emulator Validation Tests
# ==========================================

@test "rejects unsupported emulator" {
  run "$SCRIPT" unsupported --list
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown emulator" ]] || [[ "$output" =~ "Unsupported emulator" ]]
}

@test "rejects unknown action" {
  run "$SCRIPT" pcsx2 --nonexistent
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown action" ]] || [[ "$output" =~ "Unsupported action" ]]
}

# ==========================================
# 'all' Target Tests
# ==========================================

@test "script accepts 'all' as target" {
  run grep -q '"all"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script expands 'all' to every emulator" {
  run grep -q 'EMULATOR_NAMES\[@\]' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Command Structure Tests
# ==========================================

@test "script contains --archive action" {
  run grep -q "\-\-archive" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains --list action" {
  run grep -q "\-\-list" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains --restore action" {
  run grep -q "\-\-restore" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains --restore-latest action" {
  run grep -q "\-\-restore-latest" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script contains --prune action" {
  run grep -q "\-\-prune" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive action has short form -a" {
  run grep -q '"-a"' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "list action has short form -l" {
  run grep -q -- '-l)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore action has short form -r" {
  run grep -q -- '-r)' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Backup Directory Tests
# ==========================================

@test "script defines BACKUP_BASE_DIR" {
  run grep -q "BACKUP_BASE_DIR" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script uses Application Support path" {
  run grep -q "Application Support" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script defines EMULATOR_PATHS array" {
  run grep -q "EMULATOR_PATHS" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Archive Operation Tests
# ==========================================

@test "archive uses zip format" {
  run grep -q "zip" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive includes timestamp in filename" {
  run grep -q 'date.*+' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive verification is performed" {
  run grep -q "zip -T" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "failed archive is removed after bad verification" {
  run grep -q 'rm.*archive\|rm.*ARCHIVE' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Restore Operation Tests
# ==========================================

@test "restore accepts an optional backup name argument" {
  run grep -q 'do_restore.*EXTRA\|restore.*backup_name\|\$3' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore has interactive picker when no name given" {
  run grep -q 'Select backup number\|interactive\|picker' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore-latest picks most recent backup" {
  run grep -q 'head -n1\|head -n 1' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore checks backup exists before unpacking" {
  run grep -q 'not found\|does not exist' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "restore handles zip files with unzip" {
  run grep -q "unzip" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Prune Operation Tests
# ==========================================

@test "script defines MAX_BACKUPS variable" {
  run grep -q "MAX_BACKUPS" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "prune respects MAX_BACKUPS setting" {
  run grep -q 'keep.*MAX_BACKUPS\|MAX_BACKUPS.*keep\|keep\b' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "archive auto-prunes after backup" {
  run grep -A5 '\-\-archive' "$SCRIPT"
  [[ "$output" =~ (prune|PRUNE) ]]
}

@test "prune skips when MAX_BACKUPS is 0" {
  run grep -q 'keep.*0\|-le 0\|== 0' "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Function Tests
# ==========================================

@test "script has check_and_create_directory function" {
  run grep -q "check_and_create_directory()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has do_archive function" {
  run grep -q "do_archive()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has do_list function" {
  run grep -q "do_list()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has do_restore function" {
  run grep -q "do_restore()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has do_restore_latest function" {
  run grep -q "do_restore_latest()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has do_prune function" {
  run grep -q "do_prune()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has index_of helper function" {
  run grep -q "index_of()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script has get_emulator_path helper function" {
  run grep -q "get_emulator_path()" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Array Structure Tests
# ==========================================

@test "EMULATOR_NAMES array contains all four emulators" {
  run grep "EMULATOR_NAMES=" "$SCRIPT"
  [[ "$output" =~ "pcsx2" ]]
  [[ "$output" =~ "dolphin" ]]
  [[ "$output" =~ "ppsspp" ]]
  [[ "$output" =~ "duckstation" ]]
}

# ==========================================
# Best Practices Tests
# ==========================================

@test "script has bash shebang" {
  run head -n 1 "$SCRIPT"
  [[ "$output" =~ "#!/bin/bash" ]]
}

@test "script checks for required arguments" {
  run grep -q 'if.*-z.*\$1\|-z.*\$2' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script provides user-friendly error messages" {
  run "$SCRIPT" invalid --list
  [[ "$output" =~ "Error:" ]] || [[ "$output" =~ "Unknown" ]]
}
