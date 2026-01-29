#!/usr/bin/env bats

# Test suite for extract_markers.sh script
# Run with: bats tests/video/fcp/extract_markers.bats

setup() {
  export SCRIPT="./scripts/video/fcp/extract_markers.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_fcp_test_output"
  mkdir -p "$TEST_OUTPUT_DIR"
  
  # Create a minimal test FCPXML file
  export TEST_FCPXML="$TEST_OUTPUT_DIR/test.fcpxml"
  cat > "$TEST_FCPXML" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.9">
  <resources>
    <format id="r1" name="FFVideoFormat1080p60"/>
  </resources>
  <library>
    <event name="Test Event">
      <project name="Test Project">
        <sequence format="r1">
          <spine>
            <asset-clip name="Clip 1" offset="0s" duration="100/60s">
              <marker start="10/60s" duration="1/60s" value="Test Marker"/>
              <chapter-marker start="50/60s" duration="1/60s" value="Chapter 1"/>
            </asset-clip>
          </spine>
        </sequence>
      </project>
    </event>
  </library>
</fcpxml>
EOF
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
  rm -f markers_*.csv markers_*.json markers_*.txt
}

# ==========================================
# File Validation Tests
# ==========================================

@test "shows error when no file specified" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "shows error when file does not exist" {
  run "$SCRIPT" /nonexistent/file.fcpxml
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

@test "accepts valid FCPXML file" {
  run "$SCRIPT" "$TEST_FCPXML"
  [ "$status" -eq 0 ]
}

# ==========================================
# Output Format Tests
# ==========================================

@test "accepts csv format (default)" {
  run "$SCRIPT" "$TEST_FCPXML"
  [ "$status" -eq 0 ]
}

@test "accepts csv format explicitly" {
  run "$SCRIPT" "$TEST_FCPXML" csv
  [ "$status" -eq 0 ]
}

@test "accepts json format" {
  run "$SCRIPT" "$TEST_FCPXML" json
  [ "$status" -eq 0 ]
}

@test "accepts text format" {
  run "$SCRIPT" "$TEST_FCPXML" text
  [ "$status" -eq 0 ]
}

# ==========================================
# Marker Type Tests
# ==========================================

@test "accepts all marker types (default)" {
  run "$SCRIPT" "$TEST_FCPXML" csv
  [ "$status" -eq 0 ]
}

@test "accepts all marker types explicitly" {
  run "$SCRIPT" "$TEST_FCPXML" csv all
  [ "$status" -eq 0 ]
}

@test "accepts marker type filter" {
  run "$SCRIPT" "$TEST_FCPXML" csv marker
  [ "$status" -eq 0 ]
}

@test "accepts chapter-marker type filter" {
  run "$SCRIPT" "$TEST_FCPXML" csv chapter-marker
  [ "$status" -eq 0 ]
}

@test "rejects invalid marker type" {
  run "$SCRIPT" "$TEST_FCPXML" csv invalid
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Invalid marker type" ]]
}

# ==========================================
# Marker Extraction Tests
# ==========================================

@test "extracts markers from FCPXML" {
  run "$SCRIPT" "$TEST_FCPXML" csv all
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test Marker" ]]
}

@test "extracts chapter markers from FCPXML" {
  run "$SCRIPT" "$TEST_FCPXML" csv all
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Chapter 1" ]]
}

@test "filters only regular markers" {
  run "$SCRIPT" "$TEST_FCPXML" csv marker
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test Marker" ]]
  ! [[ "$output" =~ "Chapter 1" ]]
}

@test "filters only chapter markers" {
  run "$SCRIPT" "$TEST_FCPXML" csv chapter-marker
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Chapter 1" ]]
  ! [[ "$output" =~ "Test Marker" ]]
}

# ==========================================
# Output Format Validation Tests
# ==========================================

@test "CSV output contains header" {
  run "$SCRIPT" "$TEST_FCPXML" csv
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Type" ]] || [[ "$output" =~ "Marker" ]]
}

@test "JSON output is valid JSON format" {
  run "$SCRIPT" "$TEST_FCPXML" json
  [ "$status" -eq 0 ]
  [[ "$output" =~ "{" ]] && [[ "$output" =~ "}" ]]
}

@test "text output is readable" {
  run "$SCRIPT" "$TEST_FCPXML" text
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Test Marker" ]]
}

# ==========================================
# Edge Cases
# ==========================================

@test "handles FCPXML with no markers" {
  cat > "$TEST_OUTPUT_DIR/empty.fcpxml" <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE fcpxml>
<fcpxml version="1.9">
  <library>
    <event name="Test Event">
      <project name="Test Project">
        <sequence>
          <spine>
            <asset-clip name="Clip 1" offset="0s" duration="100/60s"/>
          </spine>
        </sequence>
      </project>
    </event>
  </library>
</fcpxml>
EOF
  run "$SCRIPT" "$TEST_OUTPUT_DIR/empty.fcpxml"
  [ "$status" -eq 0 ]
}

@test "handles empty FCPXML file" {
  echo '<?xml version="1.0" encoding="UTF-8"?>' > "$TEST_OUTPUT_DIR/minimal.fcpxml"
  run "$SCRIPT" "$TEST_OUTPUT_DIR/minimal.fcpxml"
  [ "$status" -eq 0 ]
}
