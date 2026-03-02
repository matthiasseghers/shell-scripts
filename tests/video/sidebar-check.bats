#!/usr/bin/env bats

# Test suite for sidebar-check.sh
# Run with: bats tests/video/sidebar-check.bats

setup() {
  export SCRIPT="./scripts/video/sidebar-check.sh"
  export TEST_DIR="/tmp/bats_sidebar_check"
  mkdir -p "$TEST_DIR"

  # 3456x1944 — smaller than 4K output (real-world example)
  export VIDEO_SMALL="$TEST_DIR/small.mp4"
  if [[ ! -f "$VIDEO_SMALL" ]]; then
    ffmpeg -y -f lavfi -i color=black:size=3456x1944:rate=1 \
      -t 0.1 -an "$VIDEO_SMALL" >/dev/null 2>&1
  fi

  # 3840x2160 — exact match to default 4K canvas
  export VIDEO_EXACT="$TEST_DIR/exact.mp4"
  if [[ ! -f "$VIDEO_EXACT" ]]; then
    ffmpeg -y -f lavfi -i color=black:size=3840x2160:rate=1 \
      -t 0.1 -an "$VIDEO_EXACT" >/dev/null 2>&1
  fi

  # 4000x2200 — larger than default canvas
  export VIDEO_LARGE="$TEST_DIR/large.mp4"
  if [[ ! -f "$VIDEO_LARGE" ]]; then
    ffmpeg -y -f lavfi -i color=black:size=4000x2200:rate=1 \
      -t 0.1 -an "$VIDEO_LARGE" >/dev/null 2>&1
  fi

  # 1280x720 — for custom resolution tests
  export VIDEO_720="$TEST_DIR/720p.mp4"
  if [[ ! -f "$VIDEO_720" ]]; then
    ffmpeg -y -f lavfi -i color=black:size=1280x720:rate=1 \
      -t 0.1 -an "$VIDEO_720" >/dev/null 2>&1
  fi

  # Pillarboxed: white 2160x1944 content centred in 3456x1944 container
  export VIDEO_PILLARBOX="$TEST_DIR/pillarbox.mp4"
  if [[ ! -f "$VIDEO_PILLARBOX" ]]; then
    ffmpeg -y -f lavfi \
      -i "color=white:size=2160x1944:rate=1,pad=3456:1944:648:0:black" \
      -t 0.1 -an "$VIDEO_PILLARBOX" >/dev/null 2>&1
  fi

  # Image: perfect fit for 4K sidebar (384x2160)
  export IMAGE_PERFECT="$TEST_DIR/perfect.png"
  if [[ ! -f "$IMAGE_PERFECT" ]]; then
    magick -size 384x2160 xc:white "$IMAGE_PERFECT" >/dev/null 2>&1
  fi

  # Image: too wide only (605x1080 — real-world example)
  export IMAGE_TOO_WIDE="$TEST_DIR/too_wide.png"
  if [[ ! -f "$IMAGE_TOO_WIDE" ]]; then
    magick -size 605x1080 xc:white "$IMAGE_TOO_WIDE" >/dev/null 2>&1
  fi

  # Image: too tall only (200x2500)
  export IMAGE_TOO_TALL="$TEST_DIR/too_tall.png"
  if [[ ! -f "$IMAGE_TOO_TALL" ]]; then
    magick -size 200x2500 xc:white "$IMAGE_TOO_TALL" >/dev/null 2>&1
  fi

  # Image: too large in both dimensions (500x2500)
  export IMAGE_TOO_LARGE="$TEST_DIR/too_large.png"
  if [[ ! -f "$IMAGE_TOO_LARGE" ]]; then
    magick -size 500x2500 xc:white "$IMAGE_TOO_LARGE" >/dev/null 2>&1
  fi

  # Image: fits with slack in both dimensions (200x1080)
  export IMAGE_WITH_SLACK="$TEST_DIR/slack.png"
  if [[ ! -f "$IMAGE_WITH_SLACK" ]]; then
    magick -size 200x1080 xc:white "$IMAGE_WITH_SLACK" >/dev/null 2>&1
  fi
}

teardown() {
  # Fixtures are cached in /tmp and reused across runs for speed.
  # Uncomment to force a clean rebuild on each run:
  # rm -rf "$TEST_DIR"
  :
}

# ==========================================
# Argument Validation Tests
# ==========================================

@test "shows usage when called with no arguments" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "usage message mentions --editor flag" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--editor" ]]
}

@test "usage message mentions --scale flag" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--scale" ]]
}

@test "usage message mentions --cropdetect flag" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--cropdetect" ]]
}

@test "fails with clear message when video file does not exist" {
  run "$SCRIPT" /nonexistent/video.mp4
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Video file not found" ]]
}

@test "fails with clear message when image file does not exist" {
  run "$SCRIPT" "$VIDEO_SMALL" /nonexistent/image.png
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Image file not found" ]]
}

@test "rejects unknown flags" {
  run "$SCRIPT" --unknown-flag "$VIDEO_SMALL"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown option" ]]
}

@test "rejects invalid --scale value" {
  run "$SCRIPT" --scale stretch "$VIDEO_SMALL"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Unknown --scale mode" ]]
}

@test "rejects --editor value without WxH format" {
  run "$SCRIPT" --editor 3840 "$VIDEO_SMALL"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "--editor requires a WxH value" ]]
}

@test "--help flag exits cleanly and shows usage" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "-h flag exits cleanly and shows usage" {
  run "$SCRIPT" -h
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

# ==========================================
# Dependency Check Tests
# ==========================================

@test "ffprobe is available" {
  run bash -c "command -v ffprobe >/dev/null 2>&1"
  [ "$status" -eq 0 ]
}

@test "ffmpeg is available" {
  run bash -c "command -v ffmpeg >/dev/null 2>&1"
  [ "$status" -eq 0 ]
}

@test "imagemagick is available" {
  run bash -c "command -v magick >/dev/null 2>&1 || command -v identify >/dev/null 2>&1"
  [ "$status" -eq 0 ]
}

# ==========================================
# Video Info Table Tests
# ==========================================

@test "detects video container size correctly" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3456x1944" ]]
}

@test "video table uses Container size label" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Container size" ]]
}

@test "video table uses Editor canvas label" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Editor canvas" ]]
}

@test "video table shows correct editor canvas from --editor flag" {
  run "$SCRIPT" --editor 1920x1080 "$VIDEO_720"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1920x1080" ]]
}

@test "video table shows scale mode row when --scale is set" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Scale mode" ]]
  [[ "$output" =~ "fit" ]]
}

@test "video table shows crop detect row when --cropdetect is set" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Crop detect" ]]
  [[ "$output" =~ "enabled" ]]
}

@test "video table does not show scale mode row when --scale is not set" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Scale mode" ]]
}

@test "shows video file path in output" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "$VIDEO_SMALL" ]]
}

# ==========================================
# Edge Case Tests
# ==========================================

@test "exits cleanly when video fills the editor canvas exactly" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_EXACT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "fills the editor canvas exactly" ]]
}

@test "exits cleanly when video fills a custom canvas exactly" {
  run "$SCRIPT" --editor 1280x720 "$VIDEO_720"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "fills the editor canvas exactly" ]]
}

@test "fails when video container is larger than editor canvas" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_LARGE"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "larger than the editor canvas" ]]
}

# ==========================================
# Layout Options Table Tests
# ==========================================

@test "layout table header references container and canvas dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "container: 3456x1944 on 3840x2160 canvas" ]]
}

@test "layout table contains all three layout rows" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Single sidebar" ]]
  [[ "$output" =~ "Split sidebars" ]]
  [[ "$output" =~ "Letterbox strips" ]]
}

@test "calculates correct single sidebar dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "384x2160px" ]]
}

@test "calculates correct split sidebar dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "192x2160px each" ]]
}

@test "calculates correct letterbox strip dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3840x108px each" ]]
}

@test "layout table renders ASCII borders" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "+--" ]]
  [[ "$output" =~ "| Single sidebar" ]]
}

# ==========================================
# --scale fit Tests
# ==========================================

@test "--scale fit shows editor scale section" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Editor Scale" ]]
}

@test "--scale fit shows scale factor" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Scale factor" ]]
}

@test "--scale fit shows scaled dimensions" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Scaled to" ]]
}

@test "--scale fit shows a layout options table based on scaled dimensions" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "based on scaled" ]]
}

# ==========================================
# --cropdetect Tests
# ==========================================

@test "--cropdetect reports no bars when video has none" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No baked-in bars detected" ]]
}

@test "--cropdetect detects baked-in pillarbox bars" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Content Crop" ]]
  [[ "$output" =~ "Baked-in bars" ]]
}

@test "--cropdetect shows both container and crop layout sections when bars found" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "based on container" ]]
  [[ "$output" =~ "based on crop" ]]
}

# ==========================================
# Image Fit Detection Tests
# ==========================================

@test "detects image that fits the sidebar perfectly" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Fits perfectly" ]]
}

@test "detects image that is too wide" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_WIDE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Too large" ]]
  [[ "$output" =~ "Width overflow" ]]
  [[ ! "$output" =~ "Height overflow" ]]
}

@test "detects image that is too tall" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_TALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Too large" ]]
  [[ "$output" =~ "Height overflow" ]]
  [[ ! "$output" =~ "Width overflow" ]]
}

@test "detects image too large in both dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_LARGE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Width overflow" ]]
  [[ "$output" =~ "Height overflow" ]]
}

@test "detects image that fits with slack" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_WITH_SLACK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Fits with slack" ]]
  [[ "$output" =~ "Width slack" ]]
  [[ "$output" =~ "Height slack" ]]
}

@test "reports image resolution in output" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_WIDE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "605x1080" ]]
}

# ==========================================
# Image Panel Visibility Tests
# ==========================================

@test "image panel is shown when image is provided" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Sidebar space" ]]
}

@test "image panel is not shown when no image is provided" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "Sidebar space" ]]
}

@test "image compared against scaled sidebar when --scale is set" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "scaled (fit)" ]]
}

@test "image compared against container sidebar when no flags set" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "container" ]]
}
