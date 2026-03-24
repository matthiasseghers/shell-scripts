#!/usr/bin/env bats

# Integration tests for extract_markers.sh
# These tests require markers-extractor to be installed and a real fcpxmld file.
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/video/fcp/extract_markers.integration.bats

setup() {
  if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    skip "Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable"
  fi

  if ! command -v markers-extractor &>/dev/null; then
    skip "markers-extractor is not installed (brew install TheAcharya/homebrew-tap/markers-extractor)"
  fi

  export SCRIPT="./scripts/video/fcp/extract_markers.sh"
  export TEST_DIR="/tmp/bats_extract_markers_integration"
  mkdir -p "$TEST_DIR"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ==========================================
# Dependency Tests
# ==========================================

@test "markers-extractor is installed" {
  run command -v markers-extractor
  [ "$status" -eq 0 ]
}

@test "markers-extractor is callable" {
  run markers-extractor --version
  [ "$status" -eq 0 ]
}

# ==========================================
# Output Directory Tests
# ==========================================

@test "output is written to same directory as input" {
  if [[ -z "${TEST_FCPXMLD:-}" ]] || [[ ! -e "$TEST_FCPXMLD" ]]; then
    skip "No test fcpxmld provided. Set TEST_FCPXMLD=/path/to/file.fcpxmld to enable"
  fi

  local input_dir
  input_dir="$(dirname "$TEST_FCPXMLD")"

  run "$SCRIPT" "$TEST_FCPXMLD"
  [ "$status" -eq 0 ]

  # markers-extractor creates a timestamped subfolder — check one exists
  local output_folders
  output_folders=$(find "$input_dir" -maxdepth 1 -type d -newer "$TEST_FCPXMLD" | wc -l | tr -d ' ')
  [ "$output_folders" -ge 1 ]
}

@test "output directory contains a youtube chapters txt file" {
  if [[ -z "${TEST_FCPXMLD:-}" ]] || [[ ! -e "$TEST_FCPXMLD" ]]; then
    skip "No test fcpxmld provided. Set TEST_FCPXMLD=/path/to/file.fcpxmld to enable"
  fi

  local input_dir
  input_dir="$(dirname "$TEST_FCPXMLD")"

  "$SCRIPT" "$TEST_FCPXMLD"

  # Find the most recently created output folder
  local output_folder
  output_folder=$(find "$input_dir" -maxdepth 1 -type d -newer "$TEST_FCPXMLD" | head -n1)

  run find "$output_folder" -name "*.txt" -type f
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

@test "youtube chapters file contains timestamp format" {
  if [[ -z "${TEST_FCPXMLD:-}" ]] || [[ ! -e "$TEST_FCPXMLD" ]]; then
    skip "No test fcpxmld provided. Set TEST_FCPXMLD=/path/to/file.fcpxmld to enable"
  fi

  local input_dir
  input_dir="$(dirname "$TEST_FCPXMLD")"

  "$SCRIPT" "$TEST_FCPXMLD"

  local output_folder
  output_folder=$(find "$input_dir" -maxdepth 1 -type d -newer "$TEST_FCPXMLD" | head -n1)

  local txt_file
  txt_file=$(find "$output_folder" -name "*.txt" -type f | head -n1)

  # YouTube chapter format: 00:00 Chapter Name
  run grep -E "^[0-9]+:[0-9]+" "$txt_file"
  [ "$status" -eq 0 ]
  [[ -n "$output" ]]
}

# ==========================================
# Error Handling Tests
# ==========================================

@test "fails with non-existent input file" {
  run "$SCRIPT" /nonexistent/path/video.fcpxmld
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}
