# Shell Scripts

[![Code Quality](https://github.com/matthiasseghers/shell-scripts/actions/workflows/code-quality.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/code-quality.yaml)
[![Security](https://github.com/matthiasseghers/shell-scripts/actions/workflows/security.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/security.yaml)
[![Documentation](https://github.com/matthiasseghers/shell-scripts/actions/workflows/documentation.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/documentation.yaml)
[![Tests](https://github.com/matthiasseghers/shell-scripts/actions/workflows/test.yml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/test.yml)
[![Integration Tests](https://github.com/matthiasseghers/shell-scripts/actions/workflows/integration-test.yml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/integration-test.yml)

A collection of shell scripts for various automation tasks, organized by category for easy discovery and use.

## Overview

This repository provides shell scripts for common automation needs including backups, video processing, and video editing workflows. Each script is designed to be standalone and well-documented.

> **Platform**: macOS. Scripts target macOS and assume Homebrew is available.

## Directory Structure

```
scripts/
├── backup/          # Backup automation scripts
│   ├── emulator_saves_manual.sh
│   ├── emulator_saves_restic.sh
│   ├── deps.brew
│   └── README.md
├── data/            # Data processing scripts
│   ├── pdf_to_csv.sh
│   └── README.md
└── video/           # Video processing scripts
    ├── video-ocr.sh
    ├── fcp/         # Final Cut Pro scripts
    │   ├── extract_markers.sh
    │   ├── deps.brew
    │   └── README.md
    └── README.md
```

## Quick Start

### Install dependencies

Each script category declares its dependencies in a `deps.brew` file. To install everything at once:

```bash
./install-deps.sh
```

To check what's missing without installing:

```bash
./install-deps.sh --check
```

Each directory contains its own detailed README with usage instructions.

### Backup Scripts
📁 **[scripts/backup/](scripts/backup/README.md)**

- **emulator_saves_manual.sh** - Manual emulator save backup/restore with ZIP archives
- **emulator_saves_restic.sh** - Automated emulator save backup with Restic

See [scripts/backup/README.md](scripts/backup/README.md) for detailed documentation.

### Video Scripts
📁 **[scripts/video/](scripts/video/README.md)**

- **video-ocr.sh** - OCR pipeline for extracting and searching text in videos
- **sidebar-check.sh** - Calculate sidebar/letterbox layout and test image fit

See [scripts/video/README.md](scripts/video/README.md) for detailed documentation.

### Data Scripts
📁 **[scripts/data/](scripts/data/README.md)**

- **pdf_to_csv.sh** - Convert a bank statement PDF to CSV

See [scripts/data/README.md](scripts/data/README.md) for detailed documentation.

### Final Cut Pro Scripts
📁 **[scripts/video/fcp/](scripts/video/fcp/README.md)**

- **extract_markers.sh** - Extract markers from an FCPXML/FCPXMLD and output YouTube chapter timestamps

See [scripts/video/fcp/README.md](scripts/video/fcp/README.md) for detailed documentation.

## Usage Examples

### Backup an emulator's saves
```bash
./scripts/backup/emulator_saves_manual.sh pcsx2 --archive
```

### Restore the latest backup
```bash
./scripts/backup/emulator_saves_manual.sh pcsx2 --restore-latest
```

### Search for text in a video
```bash
./scripts/video/video-ocr.sh video.mp4 -s "error|warning"
```

### Extract YouTube chapter timestamps from a Final Cut Pro project
```bash
./scripts/video/fcp/extract_markers.sh ~/Desktop/MyVideo.fcpxmld
```

### Convert a PDF statement to CSV
```bash
./scripts/data/pdf_to_csv.sh statement.pdf
```

## Dependencies

Dependencies are declared in `deps.brew` files colocated with each script category.
Run `./install-deps.sh` to install everything, or `./install-deps.sh --check` to see what's missing.

| Category | Dependencies |
|----------|-------------|
| Backup | `restic` |
| Video | `ffmpeg`, `tesseract`, `imagemagick` |
| FCP | `markers-extractor` (via `TheAcharya/homebrew-tap`) |
| Data | `pdftotext` |

## Security — Preventing Secret Leaks

This repository uses multiple layers to prevent committing sensitive data.

### 1. Pre-commit Hook (Local)

A git pre-commit hook scans for secrets before they reach your local repository.

**Setup** (one-time after cloning):
```bash
# Point Git to use the versioned hooks directory
git config core.hooksPath .hooks

# Install security and formatting tools (optional but recommended)
brew install git-secrets gitleaks shfmt
git secrets --install -f && git secrets --register-aws
```

The pre-commit hook will automatically:
- **Scan for secrets**: AWS keys, private keys, passwords, API tokens
- **Check formatting**: Ensures consistent shell script formatting

### 2. GitHub Actions (CI/CD)

Multiple checks run automatically on every push and pull request:
- **TruffleHog**: Secret scanning safety net
- **Shellcheck**: Shell script linting and best practices
- **shfmt**: Code formatting consistency
- **Markdown Link Check**: Validates documentation links

### Bypass Pre-commit Check (Not Recommended)
```bash
git commit --no-verify
```

**Scan for secrets manually**:
```bash
# Using gitleaks
gitleaks detect --verbose

# Using git-secrets
git secrets --scan
```

**Format shell scripts**:
```bash
# Check formatting (what CI does)
shfmt -d -i 2 -ci scripts/

# Auto-fix formatting
shfmt -w -i 2 -ci scripts/
```

**Check markdown links**:
```bash
npm install -g markdown-link-check
find . -name "*.md" -exec markdown-link-check {} \;
```

## Testing

This repository includes automated tests using [BATS (Bash Automated Testing System)](https://github.com/bats-core/bats-core).

### Running Tests Locally

```bash
# Install BATS
brew install bats-core

# Run unit tests only (fast, < 10 seconds)
./run-tests.sh

# Run integration tests (slow, several minutes)
./run-integration-tests.sh

# Run all tests (unit + integration)
./run-all-tests.sh

# Run a specific test file
bats tests/video/video-ocr.bats
```

### Test Types

- **Unit Tests** (`.bats`): Fast structural validation, run on every commit
- **Integration Tests** (`.integration.bats`): End-to-end tests with actual file processing, require `RUN_INTEGRATION_TESTS=1`

### CI/CD Testing

Tests run automatically on GitHub Actions:
- **Unit tests**: Run on every push and PR (< 1 minute)
- **Integration tests**: Manual trigger or nightly schedule (up to 30 minutes)
- **Platform**: macOS

See [tests/README.md](tests/README.md) for more details on writing and running tests.

## Contributing

Contributions are welcome! Please ensure scripts:
- Are well-documented with usage examples
- Include error handling
- Pass shellcheck validation
- Pass all tests (`./run-tests.sh`)
- Follow existing code style
- Declare dependencies in a `deps.brew` file in the script's directory

## License

See LICENSE file for details.