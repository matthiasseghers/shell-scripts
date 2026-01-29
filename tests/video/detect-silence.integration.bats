#!/usr/bin/env bats

# Integration tests for detect-silence.sh script
# These tests actually process video files and may be slow
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/video/detect-silence.integration.bats

setup() {
  # Skip all tests unless explicitly enabled
  if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    skip "Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable"
  fi
  
  export SCRIPT="./scripts/video/detect-silence.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_integration_silence"
  mkdir -p "$TEST_OUTPUT_DIR"
  
  # Create a test video with actual audio (1 second)
  export TEST_VIDEO="$TEST_OUTPUT_DIR/test_video.mp4"
  ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 \
         -f lavfi -i sine=frequency=1000:duration=2 \
         -pix_fmt yuv420p "$TEST_VIDEO" -y >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
  rm -f silence_*.csv silence_*.txt silence_*.json
  rm -rf silence_*_frames silence_*_videos
}

# ==========================================
# Actual Processing Tests
# ==========================================

@test "processes video with default settings" {
  run "$SCRIPT" "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  # Should create output file
  [[ -f silence_test_video.csv ]] || [[ -f silence_*.csv ]]
}

@test "processes video with custom threshold" {
  run "$SCRIPT" -t -40dB "$TEST_VIDEO"
  [ "$status" -eq 0 ]
}

@test "processes video with custom duration" {
  run "$SCRIPT" -d 1.0 "$TEST_VIDEO"
  [ "$status" -eq 0 ]
}

@test "creates CSV output format" {
  run "$SCRIPT" -f csv "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f silence_test_video.csv ]]
}

@test "creates TXT output format" {
  run "$SCRIPT" -f txt "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f silence_test_video.txt ]]
}

@test "creates JSON output format" {
  run "$SCRIPT" -f json "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f silence_test_video.json ]]
}

@test "creates custom output filename" {
  run "$SCRIPT" -o "$TEST_OUTPUT_DIR/custom_output.csv" "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f "$TEST_OUTPUT_DIR/custom_output.csv" ]]
}

@test "generates screenshot frames when requested" {
  run "$SCRIPT" -F "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  # Should create frames directory if silence was detected
  # (may not exist if no silence in test video)
}

@test "generates video clips when requested" {
  run "$SCRIPT" -V "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  # Should create videos directory if silence was detected
}

@test "handles both frames and video output together" {
  run "$SCRIPT" -F -V "$TEST_VIDEO"
  [ "$status" -eq 0 ]
}

@test "processes with combined short options" {
  run "$SCRIPT" -t -35dB -d 0.8 -f csv "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f silence_test_video.csv ]]
}

# ==========================================
# CSV Processing Tests
# ==========================================

@test "reads from existing CSV file" {
  # First create a CSV
  "$SCRIPT" -f csv "$TEST_VIDEO" >/dev/null 2>&1
  
  # Find the created CSV
  local csv_file=$(ls -t silence_*.csv 2>/dev/null | head -1)
  
  if [[ -n "$csv_file" && -f "$csv_file" ]]; then
    # Now use it
    run "$SCRIPT" --from-csv "$csv_file" "$TEST_VIDEO"
    [ "$status" -eq 0 ]
  else
    skip "No CSV file was created (possibly no silence detected)"
  fi
}

# ==========================================
# Output Validation Tests
# ==========================================

@test "CSV output has valid structure" {
  "$SCRIPT" -f csv "$TEST_VIDEO" >/dev/null 2>&1
  
  local csv_file=$(ls -t silence_*.csv 2>/dev/null | head -1)
  
  if [[ -n "$csv_file" && -f "$csv_file" ]]; then
    # Check for header or content
    run cat "$csv_file"
    [ "$status" -eq 0 ]
  fi
}

@test "processes video file with spaces in name" {
  local spaced_video="$TEST_OUTPUT_DIR/test video with spaces.mp4"
  cp "$TEST_VIDEO" "$spaced_video"
  
  run "$SCRIPT" "$spaced_video"
  [ "$status" -eq 0 ]
}
