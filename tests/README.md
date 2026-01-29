# Test Suite

This directory contains automated tests for all shell scripts in the repository.

## Structure

The test directory structure **mirrors the scripts directory** for easy navigation:

```
tests/
├── README.md
├── backup/
│   ├── automated_backup_restic.bats
│   ├── emulator_saves_manual.bats
│   └── emulator_saves_restic.bats
└── video/
    ├── detect-silence.bats
    ├── video-ocr.bats
    └── fcp/
        └── extract_markers.bats
```

This 1:1 mapping makes it easy to find the test file for any script:
- `scripts/video/video-ocr.sh` → `tests/video/video-ocr.bats`
- `scripts/backup/emulator_saves_manual.sh` → `tests/backup/emulator_saves_manual.bats`
- `scripts/video/fcp/extract_markers.sh` → `tests/video/fcp/extract_markers.bats`

## Requirements

- [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core)
- ffmpeg (for creating test videos)
- tesseract (for OCR functionality)

## Installation

### macOS
```bash
brew install bats-core
```

### Linux (Ubuntu/Debian)
```bash
sudo apt-get install bats
```

### Manual Installation
```bash
git clone https://github.com/bats-core/bats-core.git
cd bats-core
./install.sh /usr/local
```

## Running Tests

### Run all tests
```bash
bats tests/
```

### Run unit tests only (fast)
```bash
./run-tests.sh
```

### Run integration tests only (slow)
```bash
./run-integration-tests.sh
```

### Run all tests (unit + integration)
```bash
./run-all-tests.sh
```

### Run specific test file
```bash
bats tests/video/video-ocr.bats
```

### Run with verbose output
```bash
bats tests/ --verbose
```

### Run specific test by name
```bash
bats tests/video/video-ocr.bats --filter "rejects negative FPS"
```

## Test Types

### Unit Tests (`.bats` files)
Fast tests that validate logic, parameters, and error handling without processing actual files.
- **Runtime**: < 10 seconds
- **Run on**: Every commit, PR
- **Example**: Parameter validation, help text, error messages

### Integration Tests (`.integration.bats` files)
Slow tests that process actual video files, perform real OCR, and test end-to-end workflows.
- **Runtime**: Several minutes
- **Run on**: Manual trigger, nightly schedule
- **Enabled by**: `RUN_INTEGRATION_TESTS=1`
- **Example**: Video processing, frame extraction, OCR accuracy

Integration tests are **disabled by default** to keep development fast. Enable them with:
```bash
RUN_INTEGRATION_TESTS=1 bats tests/**/*.integration.bats
# Or use the runner script:
./run-integration-tests.sh
```

## Test Structure

- `video-ocr.bats` - Tests for the video OCR pipeline script
  - Help and usage tests
  - Parameter validation tests
  - Interactive prompt tests
  - Dependency checks
  - Configuration display tests
  
- `detect-silence.bats` - Tests for the video silence detection script
  - Help and usage validation
  - Parameter validation (threshold, duration, format)
  - Output format validation
  - File existence checks
  
- `fcp/extract_markers.bats` - Tests for the Final Cut Pro marker extraction script
  - FCPXML file validation
  - Marker extraction logic
  - Output format validation
  - Marker type filtering
  
- `backup/automated_backup_restic.bats` - Tests for the generic Restic backup template
  - Script structure validation
  - Restic command validation
  - Configuration checks
  - Template placeholder verification
  
- `backup/emulator_saves_manual.bats` - Tests for the manual emulator saves backup
  - Usage and help validation
  - Emulator support checks
  - Archive/restore/list commands
  - Directory and ZIP validation
  
- `backup/emulator_saves_restic.bats` - Tests for the Restic emulator saves backup
  - Backup sources configuration
  - Restic commands validation
  - Retention policy checks
  - Repository configuration

## Writing New Tests

When adding a new script, create a corresponding test file in the same relative path:

1. **Create test file**: If you add `scripts/foo/bar.sh`, create `tests/foo/bar.bats`
2. **Follow naming convention**: Test file name should match script name with `.bats` extension
3. **Use descriptive test names**: Each `@test` should clearly describe what is being tested
4. **Group related tests**: Use comment headers to organize tests by category

### Test Template

```bash
#!/usr/bin/env bats

# Test suite for your-script.sh
# Run with: bats tests/path/to/your-script.bats

setup() {
  export SCRIPT="./scripts/path/to/your-script.sh"
  export TEST_OUTPUT_DIR="/tmp/bats_test_output"
  mkdir -p "$TEST_OUTPUT_DIR"
}

teardown() {
  rm -rf "$TEST_OUTPUT_DIR"
}

@test "shows help when --help flag is provided" {
  run "$SCRIPT" --help
  [ "$status" -eq 0 ]
  [[ "$output" =~ "Usage:" ]]
}

@test "rejects invalid input" {
  run "$SCRIPT" --invalid-option
  [ "$status" -eq 1 ]
  [[ "$output" =~ "Error:" ]]
}
```

Each test follows this structure:

```bash
@test "description of what is being tested" {
  run command_to_test
  [ "$status" -eq 0 ]  # Assert exit code
  [[ "$output" =~ "expected text" ]]  # Assert output contains text
}
```

### Common Assertions

- `[ "$status" -eq 0 ]` - Command succeeded
- `[ "$status" -eq 1 ]` - Command failed
- `[[ "$output" =~ "text" ]]` - Output contains text
- `! [[ "$output" =~ "text" ]]` - Output does NOT contain text

## CI/CD Integration

### Unit Tests
Tests run automatically on GitHub Actions when you push changes. See `.github/workflows/test.yml` for configuration.

- **Triggered by**: Push to main/develop, Pull Requests
- **Runtime**: < 1 minute
- **Runs on**: Ubuntu and macOS

### Integration Tests
Slow integration tests run on a schedule or manual trigger. See `.github/workflows/integration-test.yml` for configuration.

- **Triggered by**: Manual workflow dispatch, Weekly schedule (Sunday 2 AM UTC)
- **Runtime**: Up to 30 minutes
- **Runs on**: Ubuntu and macOS

To manually trigger integration tests:
1. Go to the Actions tab on GitHub
2. Select "Integration Tests" workflow
3. Click "Run workflow"
