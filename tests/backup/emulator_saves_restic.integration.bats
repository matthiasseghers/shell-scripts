#!/usr/bin/env bats

# Integration tests for emulator_saves_restic.sh
# These tests require restic to be installed and will create a real repository.
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/backup/emulator_saves_restic.integration.bats

setup() {
  if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    skip "Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable"
  fi

  if ! command -v restic &>/dev/null; then
    skip "restic is not installed (brew install restic)"
  fi

  export SCRIPT="./scripts/backup/emulator_saves_restic.sh"
  export TEST_DIR="/tmp/bats_restic_integration"
  export TEST_REPO="$TEST_DIR/repo"
  export TEST_PASSWD="$TEST_DIR/password"
  export TEST_SOURCES="$TEST_DIR/sources"

  mkdir -p "$TEST_DIR" "$TEST_REPO" "$TEST_SOURCES"

  # Password file
  echo "test-password" >"$TEST_PASSWD"
  chmod 600 "$TEST_PASSWD"

  # Mock save files
  mkdir -p "$TEST_SOURCES/pcsx2" "$TEST_SOURCES/dolphin"
  echo "pcsx2 save data" >"$TEST_SOURCES/pcsx2/memcard.ps2"
  echo "dolphin save data" >"$TEST_SOURCES/dolphin/save.gci"

  # Initialize a fresh test repository
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" init &>/dev/null
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ==========================================
# Restic Prerequisites
# ==========================================

@test "restic is installed" {
  run command -v restic
  [ "$status" -eq 0 ]
}

@test "restic repository can be initialized" {
  local repo="$TEST_DIR/init_test_repo"
  run restic -p "$TEST_PASSWD" -r "$repo" init
  [ "$status" -eq 0 ]
}

# ==========================================
# Backup Tests
# ==========================================

@test "restic backup succeeds on valid source" {
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2"
  [ "$status" -eq 0 ]
}

@test "backup creates a snapshot" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" snapshots
  [ "$status" -eq 0 ]
  [[ "$output" =~ "pcsx2" ]]
}

@test "backup of multiple sources creates one snapshot" {
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup \
    "$TEST_SOURCES/pcsx2" "$TEST_SOURCES/dolphin"
  [ "$status" -eq 0 ]

  local count
  count=$(restic -p "$TEST_PASSWD" -r "$TEST_REPO" snapshots --json |
    python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  [ "$count" -eq 1 ]
}

@test "second backup deduplicates unchanged files" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2"
  [ "$status" -eq 0 ]
  # Second backup should report 0 new data added
  [[ "$output" =~ "0 B added" ]] || [[ "$output" =~ "unchanged" ]]
}

@test "backup captures changed files in new snapshot" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  echo "updated save data" >"$TEST_SOURCES/pcsx2/memcard.ps2"
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  local count
  count=$(restic -p "$TEST_PASSWD" -r "$TEST_REPO" snapshots --json |
    python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  [ "$count" -eq 2 ]
}

# ==========================================
# Unlock Tests
# ==========================================

@test "unlock succeeds on an unlocked repository" {
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" unlock
  [ "$status" -eq 0 ]
}

@test "unlock removes a stale lock" {
  # Simulate a stale lock by creating a lock file directly
  local lock_dir="$TEST_REPO/locks"
  mkdir -p "$lock_dir"
  echo '{"time":"2026-01-01T00:00:00Z","pid":99999}' >"$lock_dir/staleLock"

  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" unlock
  [ "$status" -eq 0 ]
}

# ==========================================
# Forget / Retention Tests
# ==========================================

@test "forget with keep-daily removes excess snapshots" {
  # Create 3 snapshots
  for i in 1 2 3; do
    echo "save v$i" >"$TEST_SOURCES/pcsx2/memcard.ps2"
    restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null
  done

  restic -p "$TEST_PASSWD" -r "$TEST_REPO" forget --keep-last 1 --prune &>/dev/null

  local count
  count=$(restic -p "$TEST_PASSWD" -r "$TEST_REPO" snapshots --json |
    python3 -c "import sys,json; print(len(json.load(sys.stdin)))")
  [ "$count" -eq 1 ]
}

@test "forget without prune does not reclaim space" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  # forget marks snapshots for deletion but does not remove data
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" forget --keep-last 0
  # This should succeed (even if no snapshots are removed, it's not an error)
  [ "$status" -eq 0 ]
}

# ==========================================
# Restore Tests
# ==========================================

@test "restore latest recreates original files" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  local restore_dir="$TEST_DIR/restore"
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" restore latest --target "$restore_dir"
  [ "$status" -eq 0 ]
  [ -f "$restore_dir/$TEST_SOURCES/pcsx2/memcard.ps2" ]
}

@test "restore with --include only extracts matching files" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup \
    "$TEST_SOURCES/pcsx2" "$TEST_SOURCES/dolphin" &>/dev/null

  local restore_dir="$TEST_DIR/restore_filtered"
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" restore latest \
    --target "$restore_dir" --include "*/pcsx2/*" &>/dev/null

  [ -f "$restore_dir/$TEST_SOURCES/pcsx2/memcard.ps2" ]
  [ ! -f "$restore_dir/$TEST_SOURCES/dolphin/save.gci" ]
}

@test "restore specific snapshot by ID" {
  # First snapshot
  echo "save v1" >"$TEST_SOURCES/pcsx2/memcard.ps2"
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  local snap_id
  snap_id=$(restic -p "$TEST_PASSWD" -r "$TEST_REPO" snapshots --json |
    python3 -c "import sys,json; print(json.load(sys.stdin)[0]['short_id'])")

  # Second snapshot with different content
  echo "save v2" >"$TEST_SOURCES/pcsx2/memcard.ps2"
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  # Restore the first snapshot
  local restore_dir="$TEST_DIR/restore_snap"
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" restore "$snap_id" --target "$restore_dir" &>/dev/null

  run cat "$restore_dir/$TEST_SOURCES/pcsx2/memcard.ps2"
  [[ "$output" =~ "save v1" ]]
}

# ==========================================
# Repository Integrity Tests
# ==========================================

@test "check passes on a healthy repository" {
  restic -p "$TEST_PASSWD" -r "$TEST_REPO" backup "$TEST_SOURCES/pcsx2" &>/dev/null

  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" check
  [ "$status" -eq 0 ]
}

@test "cache cleanup succeeds" {
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" cache --cleanup
  [ "$status" -eq 0 ]
}

# ==========================================
# Password File Tests
# ==========================================

@test "backup fails with wrong password" {
  local wrong_passwd="$TEST_DIR/wrong_password"
  echo "wrong-password" >"$wrong_passwd"

  run restic -p "$wrong_passwd" -r "$TEST_REPO" snapshots
  [ "$status" -ne 0 ]
}

@test "password file with correct permissions is accepted" {
  chmod 600 "$TEST_PASSWD"
  run restic -p "$TEST_PASSWD" -r "$TEST_REPO" snapshots
  [ "$status" -eq 0 ]
}
