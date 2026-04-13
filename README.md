# Shell Scripts

[![Code Quality](https://github.com/matthiasseghers/shell-scripts/actions/workflows/code-quality.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/code-quality.yaml)
[![Security](https://github.com/matthiasseghers/shell-scripts/actions/workflows/security.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/security.yaml)
[![Documentation](https://github.com/matthiasseghers/shell-scripts/actions/workflows/documentation.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/documentation.yaml)
[![Tests](https://github.com/matthiasseghers/shell-scripts/actions/workflows/test.yml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/test.yml)
[![Integration Tests](https://github.com/matthiasseghers/shell-scripts/actions/workflows/integration-test.yml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/integration-test.yml)

A collection of macOS shell scripts for automation tasks, organised by category. All scripts target macOS and assume Homebrew is available.

---

## Setup

Run once after cloning:

```bash
./setup.sh
```

This installs `pre-commit`, wires up the git hooks, and installs all script dependencies via Homebrew.

To install script dependencies only (no hook setup):

```bash
./install-deps.sh
```

---

## Root Scripts

| Script | Purpose |
|--------|---------|
| `setup.sh` | One-time repo setup — installs `pre-commit` and all deps |
| `install-deps.sh` | Installs Homebrew deps declared in each `deps.brew` file |
| `run-tests.sh` | Runs unit tests (`*.bats`) |
| `run-integration-tests.sh` | Runs integration tests (`*.integration.bats`) |
| `run-all-tests.sh` | Runs unit + integration tests |

---

## Scripts

### 📁 [scripts/video/](scripts/video/README.md)

Video processing and conversion scripts.

| Script | Description |
|--------|-------------|
| `ps5_convert.sh` | Batch-convert PS5 `.webm` recordings to `.mp4` — auto-detects SDR/HDR per file |
| `video-ocr.sh` | OCR pipeline for extracting and searching text in videos |
| `detect-silence.sh` | Detect silent segments in a video for easier editing |
| `sidebar-check.sh` | Calculate sidebar/letterbox space available on an editor timeline |
| `fcp/extract_markers.sh` | Extract Final Cut Pro markers as YouTube chapter timestamps |

### 📁 [scripts/backup/](scripts/backup/README.md)

Save and data backup scripts.

| Script | Description |
|--------|-------------|
| `emulator_saves_manual.sh` | Manual emulator save backup/restore using ZIP archives |
| `emulator_saves_restic.sh` | Automated emulator save backup using Restic |

### 📁 [scripts/data/](scripts/data/README.md)

Data processing utilities.

| Script | Description |
|--------|-------------|
| `pdf_to_csv.sh` | Convert a bank statement PDF to CSV |

---

## Testing

Tests use [BATS](https://github.com/bats-core/bats-core). The `tests/` directory mirrors `scripts/` — one `.bats` file per script.

```bash
brew install bats-core   # install BATS if needed

./run-tests.sh           # unit tests (fast)
./run-integration-tests.sh  # integration tests (slow)
./run-all-tests.sh       # both
```

See [tests/README.md](tests/README.md) for details.

---

## Pre-commit Hooks

Hooks are managed via [pre-commit](https://pre-commit.com/) and declared in `.pre-commit-config.yaml`. `./setup.sh` installs them automatically.

| Hook | What it checks |
|------|---------------|
| `gitleaks` | Secrets and credentials in staged files |
| `shfmt` | Shell script formatting |

Run manually:
```bash
pre-commit run --all-files
```

---

## Contributing

- Add a `deps.brew` file in the script's directory for any new Homebrew dependencies
- Include a test file in the matching `tests/` subdirectory
- Scripts must pass `shellcheck` and `shfmt`
- Document the script in its directory `README.md`
