#!/usr/bin/env bats

# Unit tests for extract_markers.sh
# Run with: bats tests/video/fcp/extract_markers.bats

setup() {
  export SCRIPT="./scripts/video/fcp/extract_markers.sh"
}

# ==========================================
# Script Basics
# ==========================================

@test "script exists" {
  [ -f "$SCRIPT" ]
}

@test "script has bash shebang" {
  run head -n 1 "$SCRIPT"
  [[ "$output" =~ "#!/usr/bin/env bash" ]]
}

@test "script is executable" {
  [ -x "$SCRIPT" ]
}

# ==========================================
# Argument Handling
# ==========================================

@test "shows usage when no arguments provided" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "usage shows expected argument" {
  run "$SCRIPT"
  [[ "$output" =~ "fcpxml" ]]
}

@test "usage includes an example" {
  run "$SCRIPT"
  [[ "$output" =~ "Example:" ]]
}

@test "fails with clear error when file does not exist" {
  run "$SCRIPT" /nonexistent/path/video.fcpxmld
  [ "$status" -eq 1 ]
  [[ "$output" =~ "not found" ]]
}

# ==========================================
# Dependency Check
# ==========================================

@test "script checks for markers-extractor" {
  run grep -q "markers-extractor" "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script installs via brew tap if missing" {
  run grep -q "brew tap TheAcharya/homebrew-tap" "$SCRIPT"
  [ "$status" -eq 0 ]
}

# ==========================================
# Output Directory Logic
# ==========================================

@test "script derives output dir from input path" {
  run grep -q 'dirname.*FCPXML_PATH\|OUTPUT_DIR.*dirname' "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "script uses youtube export format" {
  run grep -q "\-\-export-format youtube" "$SCRIPT"
  [ "$status" -eq 0 ]
}
