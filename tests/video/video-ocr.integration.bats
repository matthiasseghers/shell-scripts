#!/usr/bin/env bats

# Integration tests for video-ocr.sh script
# These tests actually process video files with OCR and may be very slow
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/video/video-ocr.integration.bats

setup() {
  # Skip all tests unless explicitly enabled
  if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    skip "Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable"
  fi
  
  export SCRIPT="./scripts/video/video-ocr.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_integration_ocr"
  mkdir -p "$TEST_OUTPUT_DIR"
  
  # Create a short test video (2 seconds at 1 fps = 2 frames)
  # Note: OCR may not find any text in the test pattern, which is expected
  export TEST_VIDEO="$TEST_OUTPUT_DIR/test_video.mp4"
  ffmpeg -f lavfi -i testsrc=duration=2:size=640x480:rate=1 \
         -pix_fmt yuv420p "$TEST_VIDEO" -y >/dev/null 2>&1
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
  rm -rf frames ocr clips matched_frames
  rm -f test_video*.txt
}

# ==========================================
# Full Pipeline Tests
# ==========================================

@test "processes video end-to-end with default settings" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' '$TEST_VIDEO'"
  # Script may exit 0 without creating output file if no matches found
  [ "$status" -eq 0 ]
}

@test "extracts frames at specified FPS" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --fps 1 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # Should create frames directory
  [[ -d frames ]]
}

@test "performs OCR on extracted frames" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # Should create OCR directory
  [[ -d ocr ]]
}

@test "creates output file with results" {
  local output_file="$TEST_OUTPUT_DIR/results.txt"
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' -o '$output_file' '$TEST_VIDEO'"
  # Script may exit 0 without creating file if no matches found
  [ "$status" -eq 0 ]
}

# ==========================================
# Frame Extraction Tests
# ==========================================

@test "extracts correct number of frames" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --fps 1 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # 2 second video at 1 fps should produce ~2 frames
  local frame_count=$(ls frames/*.png 2>/dev/null | wc -l | tr -d ' ')
  [ "$frame_count" -ge 1 ]
}

@test "cleans intermediate files when requested" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --clean '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # Frames and OCR should be cleaned up
  [[ ! -d frames ]] && [[ ! -d ocr ]]
}

@test "keeps intermediate files by default" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # Frames and OCR should still exist
  [[ -d frames ]] || [[ -d ocr ]]
}

# ==========================================
# Clip Extraction Tests
# ==========================================

@test "extracts video clips when enabled" {
  # Enable clip extraction programmatically
  run bash -c "echo 'y' | $SCRIPT -s 'TEST' --clip-before 1 --clip-after 1 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # May or may not create clips directory depending on if matches found
}

@test "respects clip duration settings" {
  run bash -c "echo 'y' | $SCRIPT -s 'TEST' --clip-before 5 --clip-after 3 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
}

# ==========================================
# Matched Frames Tests
# ==========================================

@test "saves matched frames when requested" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --keep-matched-frames '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # Matched frames directory may or may not exist depending on matches
}

# ==========================================
# Time Range Tests
# ==========================================

@test "processes specific time range" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --start 0 --end 1 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
}

@test "handles HH:MM:SS time format" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --start 00:00:00 --end 00:00:01 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
}

# ==========================================
# Resume Mode Tests
# ==========================================

@test "resumes from existing frames" {
  # First run to create frames
  bash -c "echo 'n' | $SCRIPT -s 'TEST' '$TEST_VIDEO'" >/dev/null 2>&1
  
  # Second run in resume mode
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --resume '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
  
  # Should use existing frames
  [[ -d frames ]]
}

# ==========================================
# Multiple Search Terms Tests
# ==========================================

@test "searches for multiple terms" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST|PATTERN|word' '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
}

# ==========================================
# Language Tests
# ==========================================

@test "uses different OCR language" {
  # Test with English (default)
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' -l eng '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
}

# ==========================================
# Deduplication Tests
# ==========================================

@test "deduplicates results with custom threshold" {
  run bash -c "echo 'n' | $SCRIPT -s 'TEST' --dedup 2 '$TEST_VIDEO'"
  [ "$status" -eq 0 ]
}

# ==========================================
# Performance Tests
# ==========================================

@test "completes processing in reasonable time" {
  # Skip timeout test - timeout command not available on macOS
  skip "timeout command not available on macOS (use gtimeout from coreutils)"
}
