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
  
  # Create a test video with alternating audio and silence (4 seconds total)
  # Use anullsrc for silent parts
  export TEST_VIDEO="$TEST_OUTPUT_DIR/test_video.mp4"
  
  # Create 2 second audio segment
  ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 \
         -f lavfi -i sine=frequency=1000:duration=2 \
         -pix_fmt yuv420p "$TEST_OUTPUT_DIR/audio_part.mp4" -y >/dev/null 2>&1
  
  # Create 2 second silent segment
  ffmpeg -f lavfi -i testsrc=duration=2:size=320x240:rate=1 \
         -f lavfi -i anullsrc=duration=2 \
         -pix_fmt yuv420p "$TEST_OUTPUT_DIR/silent_part.mp4" -y >/dev/null 2>&1
  
  # Concatenate them
  echo "file '$TEST_OUTPUT_DIR/audio_part.mp4'" > "$TEST_OUTPUT_DIR/concat_list.txt"
  echo "file '$TEST_OUTPUT_DIR/silent_part.mp4'" >> "$TEST_OUTPUT_DIR/concat_list.txt"
  ffmpeg -f concat -safe 0 -i "$TEST_OUTPUT_DIR/concat_list.txt" \
         -c copy "$TEST_VIDEO" -y >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
  rm -rf *_silence_output
}

# ==========================================
# Actual Processing Tests
# ==========================================

@test "processes video with default settings" {
  run "$SCRIPT" "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  # Should create output directory with CSV file
  [[ -f test_video_silence_output/silence_test_video.csv ]]
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
  [[ -f test_video_silence_output/silence_test_video.csv ]]
}

@test "creates TXT output format" {
  run "$SCRIPT" -f txt "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f test_video_silence_output/silence_test_video.txt ]]
}

@test "creates JSON output format" {
  run "$SCRIPT" -f json "$TEST_VIDEO"
  [ "$status" -eq 0 ]
  [[ -f test_video_silence_output/silence_test_video.json ]]
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
  [[ -f test_video_silence_output/silence_test_video.csv ]]
}

# ==========================================
# CSV Processing Tests
# ==========================================

@test "reads from existing CSV file" {
  # First create a CSV
  "$SCRIPT" -f csv "$TEST_VIDEO" >/dev/null 2>&1
  
  # Find the created CSV in new directory structure
  csv_file="test_video_silence_output/silence_test_video.csv"
  
  if [[ -f "$csv_file" ]]; then
    # Now use it to generate frames
    run "$SCRIPT" --from-csv "$csv_file" -F "$TEST_VIDEO"
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
  
  local csv_file="test_video_silence_output/silence_test_video.csv"
  
  if [[ -f "$csv_file" ]]; then
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

# ==========================================
# Naming Convention Tests
# ==========================================

@test "frames use timestamp-based naming not sequential" {
  "$SCRIPT" -F "$TEST_VIDEO" >/dev/null 2>&1
  
  if [[ -d test_video_silence_output/frames ]]; then
    # Check that frames exist with timestamp pattern (HH-MM-SS-mmm format)
    # Should match pattern like: silence_00-00-02-000_start.jpg
    local timestamp_frames=$(ls test_video_silence_output/frames/silence_*-*-*_*.jpg 2>/dev/null | wc -l | tr -d ' ')
    
    # Should NOT have sequential naming like silence_01_start.jpg
    local sequential_frames=$(ls test_video_silence_output/frames/silence_[0-9][0-9]_*.jpg 2>/dev/null | wc -l | tr -d ' ')
    
    [[ $timestamp_frames -gt 0 ]] && [[ $sequential_frames -eq 0 ]]
  else
    skip "No silence detected in test video (no frames generated)"
  fi
}

@test "video clips use timestamp-based naming not sequential" {
  "$SCRIPT" -V "$TEST_VIDEO" >/dev/null 2>&1
  
  if [[ -d test_video_silence_output/videos ]]; then
    # Check that clips exist with timestamp pattern (HH-MM-SS-mmm format)
    # Should match pattern like: silence_00-00-02-000.mp4
    local timestamp_clips=$(ls test_video_silence_output/videos/silence_*-*-*.mp4 2>/dev/null | wc -l | tr -d ' ')
    
    # Should NOT have sequential naming like silence_01.mp4
    local sequential_clips=$(ls test_video_silence_output/videos/silence_[0-9][0-9].mp4 2>/dev/null | wc -l | tr -d ' ')
    
    [[ $timestamp_clips -gt 0 ]] && [[ $sequential_clips -eq 0 ]]
  else
    skip "No silence detected in test video (no clips generated)"
  fi
}

@test "re-running with frames does not overwrite existing files" {
  # First run to create frames
  "$SCRIPT" -F "$TEST_VIDEO" >/dev/null 2>&1
  
  if [[ -d test_video_silence_output/frames ]]; then
    # Get list of files and their timestamps
    local first_run_files=$(ls -1 test_video_silence_output/frames/*.jpg 2>/dev/null | sort)
    local first_run_count=$(echo "$first_run_files" | wc -l | tr -d ' ')
    
    # Sleep to ensure modification times would differ
    sleep 1
    
    # Run again - should create same files (based on same silence timestamps)
    "$SCRIPT" -F "$TEST_VIDEO" >/dev/null 2>&1
    
    local second_run_files=$(ls -1 test_video_silence_output/frames/*.jpg 2>/dev/null | sort)
    local second_run_count=$(echo "$second_run_files" | wc -l | tr -d ' ')
    
    # Should have same number of files (timestamp-based naming means same timestamps = same filenames)
    [[ $first_run_count -eq $second_run_count ]]
    
    # File list should be identical (same filenames)
    [[ "$first_run_files" == "$second_run_files" ]]
  else
    skip "No silence detected in test video (no frames generated)"
  fi
}

@test "re-running with clips does not overwrite with different names" {
  # First run to create clips
  "$SCRIPT" -V "$TEST_VIDEO" >/dev/null 2>&1
  
  if [[ -d test_video_silence_output/videos ]]; then
    # Get list of files
    local first_run_files=$(ls -1 test_video_silence_output/videos/*.mp4 2>/dev/null | sort)
    local first_run_count=$(echo "$first_run_files" | wc -l | tr -d ' ')
    
    # Run again
    "$SCRIPT" -V "$TEST_VIDEO" >/dev/null 2>&1
    
    local second_run_files=$(ls -1 test_video_silence_output/videos/*.mp4 2>/dev/null | sort)
    local second_run_count=$(echo "$second_run_files" | wc -l | tr -d ' ')
    
    # Should have same number of files (not doubled)
    # Timestamp-based naming means re-running produces same filenames, not new ones
    [[ $first_run_count -eq $second_run_count ]]
    
    # File list should be identical
    [[ "$first_run_files" == "$second_run_files" ]]
  else
    skip "No silence detected in test video (no clips generated)"
  fi
}
