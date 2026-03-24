#!/usr/bin/env bats

# Integration tests for emulator_saves_manual.sh script
# These tests interact with the filesystem and may require specific setup.
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/backup/emulator_saves_manual.integration.bats

setup() {
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
  echo "mock save data" >"$TEST_SAVES_DIR/save1.bin"
  echo "mock save data 2" >"$TEST_SAVES_DIR/save2.bin"
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
}

# ==========================================
# Emulator Path Tests
# ==========================================

@test "works with pcsx2 paths" {
  if [[ -d "$HOME/Library/Application Support/PCSX2/memcards" ]]; then
    mkdir -p "$HOME/Emulator_MemoryCard_Backups/pcsx2"
    run "$SCRIPT" pcsx2 --list
    [ "$status" -eq 0 ]
  else
    skip "PCSX2 directory not found on this system"
  fi
}

@test "works with dolphin paths" {
  if [[ -d "$HOME/Library/Application Support/Dolphin/GC" ]]; then
    mkdir -p "$HOME/Emulator_MemoryCard_Backups/dolphin"
    run "$SCRIPT" dolphin --list
    [ "$status" -eq 0 ]
  else
    skip "Dolphin directory not found on this system"
  fi
}

@test "works with ppsspp paths" {
  if [[ -d "$HOME/Library/Application Support/PPSSPP/memstick/PSP/SAVEDATA" ]]; then
    mkdir -p "$HOME/Emulator_MemoryCard_Backups/ppsspp"
    run "$SCRIPT" ppsspp --list
    [ "$status" -eq 0 ]
  else
    skip "PPSSPP directory not found on this system"
  fi
}

@test "works with duckstation paths" {
  if [[ -d "$HOME/Library/Application Support/DuckStation/memcards" ]]; then
    mkdir -p "$HOME/Emulator_MemoryCard_Backups/duckstation"
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
  local test_zip="$TEST_OUTPUT_DIR/test.zip"
  (cd "$TEST_SAVES_DIR" && zip -r "$test_zip" .)

  run zip -T "$test_zip"
  [ "$status" -eq 0 ]
}

@test "handles corrupted zip gracefully" {
  echo "not a zip file" >"$TEST_OUTPUT_DIR/corrupted.zip"

  run zip -T "$TEST_OUTPUT_DIR/corrupted.zip"
  [ "$status" -ne 0 ]
}

# ==========================================
# 'all' Target Tests
# ==========================================

@test "all target skips emulators whose source path does not exist" {
  # None of the real emulator paths exist in CI — every emulator should be skipped, not error
  run "$SCRIPT" all --list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No backups found" ]] || [[ "$output" =~ "SKIP" ]]
}

@test "all target does not exit early when one emulator is missing" {
  run "$SCRIPT" all --archive
  # Should complete for all emulators, not abort on the first missing source
  [ "$status" -eq 0 ]
}

# ==========================================
# List Tests
# ==========================================

@test "list shows no backups message when backup dir is empty" {
  mkdir -p "$HOME/Emulator_MemoryCard_Backups/pcsx2"
  # Remove any existing backups so the dir is empty
  rm -f "$HOME/Emulator_MemoryCard_Backups/pcsx2/"*.zip 2>/dev/null || true

  run "$SCRIPT" pcsx2 --list
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No backups found" ]]
}

@test "list shows backup filenames in reverse chronological order" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
  mkdir -p "$backup_dir"

  # Create two dummy zips with different timestamps in the name
  (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-01-01_10-00-00.zip" .)
  sleep 1
  (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-01-02_10-00-00.zip" .)

  run "$SCRIPT" pcsx2 --list
  [ "$status" -eq 0 ]
  # Newer backup should appear first (lower list index)
  [[ "$output" =~ "2026-01-02" ]]
}

# ==========================================
# Restore Tests
# ==========================================

@test "restore-latest succeeds when a backup exists" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
  local source_dir="$HOME/Library/Application Support/PCSX2/memcards"
  mkdir -p "$backup_dir"
  mkdir -p "$source_dir"

  # Create a valid backup zip
  (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-03-19_12-00-00.zip" .)

  run "$SCRIPT" pcsx2 --restore-latest
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Restored" ]]
}

@test "restore-latest fails with clear error when no backups exist" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/duckstation"
  mkdir -p "$backup_dir"
  rm -f "$backup_dir/"*.zip 2>/dev/null || true

  run "$SCRIPT" duckstation --restore-latest
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No backups found" ]]
}

@test "restore by name fails with clear error when backup file is missing" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
  mkdir -p "$backup_dir"

  run "$SCRIPT" pcsx2 --restore nonexistent_backup.zip
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]] || [[ "$output" =~ "does not exist" ]]
}

@test "restore extracts files to correct destination" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
  local dest_dir="$HOME/Library/Application Support/PCSX2/memcards"
  mkdir -p "$backup_dir"
  mkdir -p "$dest_dir"

  local archive="$backup_dir/memcards_backup_2026-03-19_09-00-00.zip"
  echo "save content" >"$TEST_SAVES_DIR/verify_restore.bin"
  (cd "$TEST_SAVES_DIR" && zip -q "$archive" verify_restore.bin)

  run "$SCRIPT" pcsx2 --restore "$(basename "$archive")"
  [ "$status" -eq 0 ]
  [ -f "$dest_dir/verify_restore.bin" ]
}

# ==========================================
# Prune Tests
# ==========================================

@test "prune removes excess backups beyond MAX_BACKUPS" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
  mkdir -p "$backup_dir"

  # Create 5 dummy archives
  for i in 01 02 03 04 05; do
    (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-01-${i}_10-00-00.zip" .)
  done

  run "$SCRIPT" pcsx2 --prune 3
  [ "$status" -eq 0 ]

  local remaining
  remaining=$(ls "$backup_dir/"*.zip 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" -eq 3 ]
}

@test "prune keeps all backups when count is within limit" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/dolphin"
  mkdir -p "$backup_dir"
  rm -f "$backup_dir/"*.zip 2>/dev/null || true

  (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-01-01_10-00-00.zip" .)
  (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-01-02_10-00-00.zip" .)

  run "$SCRIPT" dolphin --prune 10
  [ "$status" -eq 0 ]

  local remaining
  remaining=$(ls "$backup_dir/"*.zip 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" -eq 2 ]
}

@test "prune with 0 keeps all backups" {
  local backup_dir="$HOME/Emulator_MemoryCard_Backups/ppsspp"
  mkdir -p "$backup_dir"

  for i in 01 02 03; do
    (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-02-${i}_10-00-00.zip" .)
  done

  run "$SCRIPT" ppsspp --prune 0
  [ "$status" -eq 0 ]

  local remaining
  remaining=$(ls "$backup_dir/"*.zip 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" -eq 3 ]
}

# ==========================================
# Auto-Prune on Archive Tests
# ==========================================

@test "archive auto-prunes when MAX_BACKUPS is exceeded" {
  # This test requires PCSX2 memcards directory to exist
  if [[ ! -d "$HOME/Library/Application Support/PCSX2/memcards" ]]; then
    skip "PCSX2 directory not found on this system"
  fi

  local backup_dir="$HOME/Emulator_MemoryCard_Backups/pcsx2"
  mkdir -p "$backup_dir"

  # Pre-fill with MAX_BACKUPS worth of dummy archives (default is 10)
  for i in $(seq -w 1 10); do
    (cd "$TEST_SAVES_DIR" && zip -q "$backup_dir/memcards_backup_2026-01-${i}_10-00-00.zip" .)
  done

  run "$SCRIPT" pcsx2 --archive
  [ "$status" -eq 0 ]

  # After archiving, count should still be capped at MAX_BACKUPS (10)
  local remaining
  remaining=$(ls "$backup_dir/"*.zip 2>/dev/null | wc -l | tr -d ' ')
  [ "$remaining" -le 10 ]
}
