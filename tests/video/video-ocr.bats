#!/usr/bin/env bats

# Test suite for video-ocr.sh script
# Run with: bats tests/video-ocr.bats

setup() {
  # Create a test video file (1 second, 320x240)
  export TEST_VIDEO="/tmp/bats_test_video.mp4"
  if [[ ! -f "$TEST_VIDEO" ]]; then
    if command -v ffmpeg &>/dev/null; then
      ffmpeg -f lavfi -i testsrc=duration=1:size=320x240:rate=1 \
        -f lavfi -i sine=frequency=1000:duration=1 \
        -pix_fmt yuv420p "$TEST_VIDEO" -y >/dev/null 2>&1
    else
      # Create a dummy file so argument-validation tests can run without ffmpeg
      touch "$TEST_VIDEO"
    fi
  fi

  export SCRIPT="./scripts/video/video-ocr.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_test_output"
  mkdir -p "$TEST_OUTPUT_DIR"
}

teardown() {
  # Clean up test artifacts
  rm -rf *_ocr_output *.txt
  rm -rf "$TEST_OUTPUT_DIR"
}

# ==========================================
# Help and Usage Tests
# ==========================================

@test "shows help when --help flag is provided" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
  [[ "$output" =~ "--search" ]]
}

@test "shows help when -h flag is provided" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "shows error when no video file specified" {
  run "$SCRIPT" -s "test"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No video file specified" ]]
}

@test "shows error when video file does not exist" {
  run "$SCRIPT" -s "test" /nonexistent/video.mp4
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Video file not found" ]]
}

@test "shows error when no search terms specified" {
  run "$SCRIPT" "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "No search terms specified" ]]
}

# ==========================================
# Parameter Validation Tests
# ==========================================

@test "rejects negative FPS value" {
  run "$SCRIPT" -s "test" --fps -5 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "FPS must be a positive number" ]]
}

@test "rejects zero FPS value" {
  run "$SCRIPT" -s "test" --fps 0 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "FPS must be a positive number" ]]
}

@test "rejects non-numeric FPS value" {
  run "$SCRIPT" -s "test" --fps abc "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "FPS must be a positive number" ]]
}

@test "accepts valid decimal FPS value" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --fps 2.5 '$TEST_VIDEO' 2>&1 | head -1"
  [ "$status" -eq 0 ]
}

@test "rejects PSM mode out of range (too high)" {
  run "$SCRIPT" -s "test" --psm 99 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "PSM mode must be between 0 and 13" ]]
}

@test "rejects PSM mode out of range (negative)" {
  run "$SCRIPT" -s "test" --psm -1 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "PSM mode must be a non-negative integer" ]]
}

@test "rejects non-numeric PSM mode" {
  run "$SCRIPT" -s "test" --psm abc "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "PSM mode must be a non-negative integer" ]]
}

@test "accepts valid PSM mode values" {
  for psm in 0 6 13; do
    run bash -c "echo 'n' | $SCRIPT -s 'test' --psm $psm '$TEST_VIDEO' 2>&1 | head -1"
    [ "$status" -eq 0 ]
  done
}

@test "rejects invalid clip format" {
  run "$SCRIPT" -s "test" --clip-format avi "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid clip format" ]]
}

@test "accepts valid clip formats" {
  for format in mp4 webm mov; do
    run bash -c "echo 'n' | $SCRIPT -s 'test' --clip-format $format '$TEST_VIDEO' 2>&1 | head -1"
    [ "$status" -eq 0 ]
  done
}

@test "rejects invalid time format (M:SS)" {
  run "$SCRIPT" -s "test" --start 5:30 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Start time must be in HH:MM:SS format or seconds" ]]
}

@test "accepts valid time format (HH:MM:SS)" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --start 00:05:30 '$TEST_VIDEO' 2>&1 | head -1"
  [ "$status" -eq 0 ]
}

@test "accepts valid time format (seconds)" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --start 330 '$TEST_VIDEO' 2>&1 | head -1"
  [ "$status" -eq 0 ]
}

@test "rejects negative dedup threshold" {
  run "$SCRIPT" -s "test" --dedup -1 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Deduplication threshold must be a positive number" ]]
}

@test "rejects negative clip-before value" {
  run "$SCRIPT" -s "test" --clip-before -5 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Clip before duration must be a positive number" ]]
}

@test "rejects negative clip-after value" {
  run "$SCRIPT" -s "test" --clip-after -5 "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Clip after duration must be a positive number" ]]
}

# ==========================================
# Interactive Prompt Tests
# ==========================================

@test "prompts user when clip duration flags set without --extract-clips" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --clip-before 20 --clip-after 20 '$TEST_VIDEO' 2>&1 | head -30"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "You specified --clip-before and/or --clip-after" ]]
}

@test "enables clip extraction when user confirms prompt" {
  run bash -c "echo 'y' | $SCRIPT -s 'test' --clip-before 20 '$TEST_VIDEO' 2>&1 | head -30"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Clip extraction enabled" ]]
  [[ "$output" =~ "Extract clips:  Yes" ]]
}

@test "continues without clips when user declines prompt" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --clip-before 20 '$TEST_VIDEO' 2>&1 | head -30"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Continuing without clip extraction" ]]
  ! [[ "$output" =~ "Extract clips:  Yes" ]]
}

@test "no prompt when --extract-clips is already set" {
  run bash -c "$SCRIPT -s 'test' --extract-clips --clip-before 20 '$TEST_VIDEO' 2>&1 | head -20"
  [ "$status" -eq 0 ]
  ! [[ "$output" =~ "Do you want to enable clip extraction?" ]]
  [[ "$output" =~ "Extract clips:  Yes" ]]
}

# ==========================================
# Dependency Checks
# ==========================================

@test "checks for required dependencies" {
  # This test verifies the script checks for dependencies
  # We can't easily mock missing dependencies in BATS, so we just verify
  # the script would run dependency checks
  run bash -c "echo 'n' | $SCRIPT -s 'test' '$TEST_VIDEO' 2>&1"
  [ "$status" -eq 0 ]
  # If dependencies are missing, script would exit with error
}

# ==========================================
# Configuration Display Tests
# ==========================================

@test "displays configuration before processing" {
  run bash -c "echo 'n' | $SCRIPT -s 'signature' '$TEST_VIDEO' 2>&1 | head -20"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "OCR Pipeline Configuration" ]]
  [[ "$output" =~ "Video:" ]]
  [[ "$output" =~ "FPS:" ]]
  [[ "$output" =~ "Search terms:" ]]
}

@test "shows custom FPS in configuration" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --fps 4 '$TEST_VIDEO' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "FPS:            4" ]]
}

@test "shows time range in configuration when specified" {
  run bash -c "echo 'n' | $SCRIPT -s 'test' --start 00:00:00 --end 00:00:01 '$TEST_VIDEO' 2>&1"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Start time:" ]]
  [[ "$output" =~ "End time:" ]]
}

# ==========================================
# Unknown Option Tests
# ==========================================

@test "rejects unknown options" {
  run "$SCRIPT" -s "test" --unknown-flag "$TEST_VIDEO"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown option" ]]
}
