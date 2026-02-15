#!/usr/bin/env bats

# Test suite for pdf_to_csv.sh

setup() {
  SCRIPT="./scripts/data/pdf_to_csv.sh"
}

@test "shows usage when no arguments provided" {
  run "$SCRIPT"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "fails when input file does not exist" {
  run "$SCRIPT" "/tmp/does_not_exist_$$.pdf"
  [ "$status" -eq 1 ]
  [[ "$output" =~ "File not found" ]]
}
