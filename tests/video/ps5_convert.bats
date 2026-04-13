#!/usr/bin/env bats

# Test suite for ps5_convert.sh
# Run with: bats tests/video/ps5_convert.bats

setup() {
  export SCRIPT="./scripts/video/ps5_convert.sh"
  export TEST_DIR="/tmp/bats_ps5_convert"
  mkdir -p "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ==========================================
# Help and Usage Tests
# ==========================================

@test "shows usage when no arguments provided" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "--mode" ]]
  [[ "$output" =~ "--overwrite" ]]
  [[ "$output" =~ "--skip" ]]
}

@test "shows usage mentioning sdr and hdr modes" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "sdr" ]]
  [[ "$output" =~ "hdr" ]]
}

# ==========================================
# Directory Validation Tests
# ==========================================

@test "errors when directory does not exist" {
  run "$SCRIPT" /nonexistent/path/that/does/not/exist
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Directory not found" ]]
}

@test "exits cleanly when directory has no webm files" {
  run "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No .webm files found" ]]
}

# ==========================================
# --mode Flag Tests
# ==========================================

@test "errors on unknown --mode value" {
  run "$SCRIPT" "$TEST_DIR" --mode invalid
  [ "$status" -eq 1 ]
  [[ "$output" =~ "sdr" ]]
  [[ "$output" =~ "hdr" ]]
}

@test "errors on --mode with missing value" {
  run "$SCRIPT" "$TEST_DIR" --mode
  [ "$status" -eq 1 ]
}

@test "errors on unknown flag" {
  run "$SCRIPT" "$TEST_DIR" --unknown
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown argument" ]]
}

@test "accepts --overwrite flag" {
  run "$SCRIPT" "$TEST_DIR" --overwrite
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No .webm files found" ]]
}

@test "accepts --skip flag" {
  run "$SCRIPT" "$TEST_DIR" --skip
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No .webm files found" ]]
}

@test "errors when --overwrite and --skip are combined" {
  run "$SCRIPT" "$TEST_DIR" --overwrite --skip
  [ "$status" -eq 1 ]
  [[ "$output" =~ "mutually exclusive" ]]
}

@test "errors when --skip and --overwrite are combined" {
  run "$SCRIPT" "$TEST_DIR" --skip --overwrite
  [ "$status" -eq 1 ]
  [[ "$output" =~ "mutually exclusive" ]]
}

@test "accepts --mode sdr" {
  # No webm files → exits 0 after mode validation passes
  run "$SCRIPT" "$TEST_DIR" --mode sdr
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No .webm files found" ]]
}

@test "accepts --mode hdr" {
  run "$SCRIPT" "$TEST_DIR" --mode hdr
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No .webm files found" ]]
}

# ==========================================
# Conflict Resolution Tests
# ==========================================

@test "skips file when mp4 already exists and user declines overwrite prompt" {
  touch "$TEST_DIR/clip.webm"
  touch "$TEST_DIR/clip.mp4"

  # Supply "n" as stdin to decline the overwrite prompt
  run bash -c "echo n | '$SCRIPT' '$TEST_DIR'"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Skipped" ]]
}

@test "skips file with --skip when mp4 already exists" {
  touch "$TEST_DIR/clip.webm"
  touch "$TEST_DIR/clip.mp4"

  run "$SCRIPT" "$TEST_DIR" --skip
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Skipped" ]]
}

# ==========================================
# ffmpeg Dependency Tests
# ==========================================

@test "errors when ffmpeg is not found" {
  # Temporarily shadow ffmpeg with a missing command via PATH
  local fake_bin="$TEST_DIR/bin"
  mkdir -p "$fake_bin"
  # Override PATH so ffmpeg is not found
  run env PATH="$fake_bin" "$SCRIPT" "$TEST_DIR"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "ffmpeg not found" ]]
}
