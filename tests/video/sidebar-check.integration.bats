#!/usr/bin/env bats

# Integration tests for sidebar-check.sh
# These tests process real video and image files and may be slow
# Run with: RUN_INTEGRATION_TESTS=1 bats tests/video/sidebar-check.integration.bats

setup() {
  if [[ "${RUN_INTEGRATION_TESTS:-0}" != "1" ]]; then
    skip "Integration tests disabled. Set RUN_INTEGRATION_TESTS=1 to enable"
  fi

  export SCRIPT="./scripts/video/sidebar-check.sh"
  export TEST_DIR="/tmp/bats_sidebar_check_integration"
  mkdir -p "$TEST_DIR"

  # 3456x1944 — smaller than 4K (real-world example)
  export VIDEO_SMALL="$TEST_DIR/small.mp4"
  ffmpeg -y -f lavfi -i color=black:size=3456x1944:rate=1 \
    -t 0.5 -an "$VIDEO_SMALL" >/dev/null 2>&1

  # 3840x2160 — exact match to default 4K canvas
  export VIDEO_EXACT="$TEST_DIR/exact.mp4"
  ffmpeg -y -f lavfi -i color=black:size=3840x2160:rate=1 \
    -t 0.5 -an "$VIDEO_EXACT" >/dev/null 2>&1

  # 4000x2200 — larger than default canvas
  export VIDEO_LARGE="$TEST_DIR/large.mp4"
  ffmpeg -y -f lavfi -i color=black:size=4000x2200:rate=1 \
    -t 0.5 -an "$VIDEO_LARGE" >/dev/null 2>&1

  # 1280x720 — for custom canvas tests
  export VIDEO_720="$TEST_DIR/720p.mp4"
  ffmpeg -y -f lavfi -i color=black:size=1280x720:rate=1 \
    -t 0.5 -an "$VIDEO_720" >/dev/null 2>&1

  # Video with spaces in filename
  export VIDEO_SPACES="$TEST_DIR/my video file.mp4"
  cp "$VIDEO_SMALL" "$VIDEO_SPACES"

  # Pillarboxed: white 2160x1944 content centred in 3456x1944 → 648px bars each side
  # cropdetect should find: 2160x1944 at offset 648,0
  export VIDEO_PILLARBOX="$TEST_DIR/pillarbox.mp4"
  ffmpeg -y -f lavfi \
    -i "color=white:size=2160x1944:rate=1,pad=3456:1944:648:0:black" \
    -t 0.5 -an "$VIDEO_PILLARBOX" >/dev/null 2>&1

  # Letterboxed: white 3456x1296 content centred in 3456x1944 → 324px bars top/bottom
  # cropdetect should find: 3456x1296 at offset 0,324
  export VIDEO_LETTERBOX="$TEST_DIR/letterbox.mp4"
  ffmpeg -y -f lavfi \
    -i "color=white:size=3456x1296:rate=1,pad=3456:1944:0:324:black" \
    -t 0.5 -an "$VIDEO_LETTERBOX" >/dev/null 2>&1

  # Images
  export IMAGE_PERFECT="$TEST_DIR/perfect.png"
  magick -size 384x2160 xc:white "$IMAGE_PERFECT" >/dev/null 2>&1

  export IMAGE_TOO_WIDE="$TEST_DIR/too_wide.png"
  magick -size 605x1080 xc:white "$IMAGE_TOO_WIDE" >/dev/null 2>&1

  export IMAGE_TOO_TALL="$TEST_DIR/too_tall.png"
  magick -size 200x2500 xc:white "$IMAGE_TOO_TALL" >/dev/null 2>&1

  export IMAGE_TOO_LARGE="$TEST_DIR/too_large.png"
  magick -size 500x2500 xc:white "$IMAGE_TOO_LARGE" >/dev/null 2>&1

  export IMAGE_WITH_SLACK="$TEST_DIR/slack.png"
  magick -size 200x1080 xc:white "$IMAGE_WITH_SLACK" >/dev/null 2>&1

  export IMAGE_SPACES="$TEST_DIR/my sidebar image.png"
  cp "$IMAGE_PERFECT" "$IMAGE_SPACES"
}

teardown() {
  rm -rf "$TEST_DIR"
}

# ==========================================
# Full Output Structure Tests
# ==========================================

@test "output contains video section with emoji header" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "🎬" ]]
  [[ "$output" =~ "Container size" ]]
  [[ "$output" =~ "Editor canvas" ]]
}

@test "output contains layout options section" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "📐" ]]
  [[ "$output" =~ "Layout" ]]
}

@test "output contains image section when image is provided" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "🖼" ]]
  [[ "$output" =~ "Sidebar space" ]]
}

@test "table divider lines start and end with +" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  local dividers
  dividers=$(echo "$output" | grep "^+--")
  while IFS= read -r line; do
    [[ "$line" == +* ]] && [[ "$line" == *+ ]]
  done <<<"$dividers"
}

@test "all table rows are properly pipe-delimited" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  local rows
  rows=$(echo "$output" | grep "^| ")
  while IFS= read -r line; do
    [[ "$line" == \|* ]] && [[ "$line" == *\| ]]
  done <<<"$rows"
}

# ==========================================
# Filename Handling Tests
# ==========================================

@test "handles video filename with spaces" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SPACES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "my video file.mp4" ]]
}

@test "handles image filename with spaces" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_SPACES"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "my sidebar image.png" ]]
}

# ==========================================
# --editor Flag Tests
# ==========================================

@test "uses default 4K canvas when --editor is omitted" {
  run "$SCRIPT" "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3840x2160" ]]
}

@test "uses 1080p canvas when specified with --editor" {
  run "$SCRIPT" --editor 1920x1080 "$VIDEO_720"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1920x1080" ]]
  [[ "$output" =~ "640x1080px" ]] # 1920-1280=640 sidebar
}

@test "uses 1440p canvas when specified with --editor" {
  run "$SCRIPT" --editor 2560x1440 "$VIDEO_720"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "2560x1440" ]]
  [[ "$output" =~ "1280x1440px" ]] # 2560-1280=1280 sidebar
}

# ==========================================
# Arithmetic Correctness Tests
# ==========================================

@test "sidebar area equals diff_w multiplied by canvas height" {
  # DIFF_W=384, EDITOR_H=2160 → area=829440
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "829440" ]]
}

@test "split sidebar is exactly half of single sidebar width" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "384x2160px" ]]
  [[ "$output" =~ "192x2160px each" ]]
}

@test "letterbox strip is exactly half of unused vertical space" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3840x108px each" ]]
}

@test "width overflow value is arithmetically correct" {
  # IMAGE_TOO_WIDE=605px, sidebar=384px → overflow=221px
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_WIDE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "221px" ]]
  [[ "$output" =~ "image: 605px" ]]
  [[ "$output" =~ "sidebar: 384px" ]]
}

@test "height overflow value is arithmetically correct" {
  # IMAGE_TOO_TALL=2500px, canvas=2160px → overflow=340px
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_TALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "340px" ]]
  [[ "$output" =~ "image: 2500px" ]]
  [[ "$output" =~ "sidebar: 2160px" ]]
}

@test "width slack value is arithmetically correct" {
  # IMAGE_WITH_SLACK=200px wide, sidebar=384px → slack=184px
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_WITH_SLACK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "184px" ]]
  [[ "$output" =~ "image: 200px" ]]
  [[ "$output" =~ "sidebar: 384px" ]]
}

# ==========================================
# Combined Overflow and Slack Tests
# ==========================================

@test "width overflow and height slack both shown when only width overflows" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_WIDE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Width overflow" ]]
  [[ ! "$output" =~ "Height overflow" ]]
  [[ "$output" =~ "Height slack" ]]
}

@test "height overflow and width slack both shown when only height overflows" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_TALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Height overflow" ]]
  [[ ! "$output" =~ "Width overflow" ]]
  [[ "$output" =~ "Width slack" ]]
}

@test "both overflow rows shown when image is too large in both dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_TOO_LARGE"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Width overflow" ]]
  [[ "$output" =~ "Height overflow" ]]
  [[ ! "$output" =~ "slack" ]]
}

@test "both slack rows shown when image fits with room in both dimensions" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_WITH_SLACK"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Width slack" ]]
  [[ "$output" =~ "Height slack" ]]
  [[ ! "$output" =~ "overflow" ]]
}

@test "no overflow or slack rows when image fits perfectly" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "overflow" ]]
  [[ ! "$output" =~ "slack" ]]
}

# ==========================================
# --scale fit Tests
# ==========================================

@test "--scale fit shows editor scale section with emoji header" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "🖥" ]]
  [[ "$output" =~ "Editor Scale" ]]
}

@test "--scale fit shows scale factor for 3456 to 3840" {
  # 3840 / 3456 * 1000 = 1111 → 1.111x
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1.111x" ]]
}

@test "--scale fit shows correct scaled dimensions for 16:9 source on 16:9 canvas" {
  # 3456x1944 scaled to fit 3840x2160 (both 16:9) → fills canvas exactly: 3840x2160
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "3840x2160px" ]]
}

@test "--scale fit reports zero remaining space when aspect ratios match" {
  # 3456x1944 (16:9) fit to 3840x2160 (16:9) → 0px remaining on both axes
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "0px wide" ]]
}

@test "--scale fit layout table shows content fills canvas when aspect ratios match" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Content fills the editor canvas exactly" ]]
}

@test "--scale fit with non-matching aspect ratio shows sidebar space" {
  # 1280x720 (16:9) fit to 1920x1080 (16:9) → fills exactly too
  # Use a non-16:9 canvas to get actual sidebar space
  run "$SCRIPT" --editor 1920x1080 --scale fit "$VIDEO_720"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "based on scaled" ]]
}

@test "--scale fit image comparison uses scaled sidebar not container sidebar" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "scaled (fit)" ]]
}

# ==========================================
# --cropdetect Tests — No Bars
# ==========================================

@test "--cropdetect reports no bars when content fills the container" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "No baked-in bars detected" ]]
}

@test "--cropdetect does not show crop layout table when no bars found" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ ! "$output" =~ "based on crop" ]]
}

@test "--cropdetect still shows container layout when no bars found" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "based on container" ]]
}

# ==========================================
# --cropdetect Tests — Pillarbox
# ==========================================

@test "--cropdetect detects baked-in pillarbox bars" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Content Crop" ]]
  [[ "$output" =~ "Baked-in bars" ]]
}

@test "--cropdetect shows correct horizontal bar amount for pillarboxed video" {
  # Container 3456 - content 2160 = 1296px horizontal bars
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1296px horizontal" ]]
}

@test "--cropdetect shows both container and crop layout sections for pillarboxed video" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "based on container: 3456x1944" ]]
  [[ "$output" =~ "based on crop" ]]
}

@test "--cropdetect crop layout uses crop dimensions not container" {
  # Crop is 2160x1944, canvas is 3840x2160 → sidebar = 3840-2160 = 1680px
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "1680x2160px" ]]
}

# ==========================================
# --cropdetect Tests — Letterbox
# ==========================================

@test "--cropdetect detects baked-in letterbox bars" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_LETTERBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Baked-in bars" ]]
}

@test "--cropdetect shows correct vertical bar amount for letterboxed video" {
  # Container 1944 - content 1296 = 648px vertical bars
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_LETTERBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "648px vertical" ]]
}

# ==========================================
# --cropdetect + --scale fit Combined Tests
# ==========================================

@test "--cropdetect and --scale fit can be used together" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Editor Scale" ]]
}

@test "--scale fit uses crop as source when cropdetect finds bars" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect --scale fit "$VIDEO_PILLARBOX"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "crop" ]]
  [[ "$output" =~ "inside container" ]]
}

@test "image comparison uses scaled sidebar when both --scale and --cropdetect are set" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect --scale fit "$VIDEO_PILLARBOX" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "scaled (fit)" ]]
}

@test "image compared against crop sidebar when --cropdetect set but not --scale" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_PILLARBOX" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
  [[ "$output" =~ "crop" ]]
}

# ==========================================
# Exit Code Tests
# ==========================================

@test "exits 0 for normal run without image" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
}

@test "exits 0 for normal run with image" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$IMAGE_PERFECT"
  [ "$status" -eq 0 ]
}

@test "exits 0 when video fills canvas exactly" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_EXACT"
  [ "$status" -eq 0 ]
}

@test "exits 0 with --scale fit flag" {
  run "$SCRIPT" --editor 3840x2160 --scale fit "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
}

@test "exits 0 with --cropdetect flag" {
  run "$SCRIPT" --editor 3840x2160 --cropdetect "$VIDEO_SMALL"
  [ "$status" -eq 0 ]
}

@test "exits 1 when video is larger than canvas" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_LARGE"
  [ "$status" -eq 1 ]
}

@test "exits 1 when video file is missing" {
  run "$SCRIPT" --editor 3840x2160 "$TEST_DIR/nonexistent.mp4"
  [ "$status" -eq 1 ]
}

@test "exits 1 when image file is missing" {
  run "$SCRIPT" --editor 3840x2160 "$VIDEO_SMALL" "$TEST_DIR/nonexistent.png"
  [ "$status" -eq 1 ]
}

@test "exits 1 with unknown flag" {
  run "$SCRIPT" --unknown "$VIDEO_SMALL"
  [ "$status" -eq 1 ]
}
