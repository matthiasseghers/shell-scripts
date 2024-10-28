# Shell Scripts
[![Shellcheck](https://github.com/matthiasseghers/shell-scripts/actions/workflows/shellcheck.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/shellcheck.yaml)
[![Secret Scanning](https://github.com/matthiasseghers/shell-scripts/actions/workflows/trufflehog.yaml/badge.svg)](https://github.com/matthiasseghers/shell-scripts/actions/workflows/trufflehog.yaml)

This repository contains various Bash scripts created for different use cases and utilities. The scripts are organized into categories to make them easy to find and use.

## Table of Contents
- [Overview](#overview)
- [Directory Structure](#directory-structure)
- [Usage](#usage)
  - [Emulator Saves Manual Backup Script](#emulator-saves-manual-backup-script)
  - [Automated Backup Script with Restic](#automated-backup-script-with-restic)
  - [Generalized Automated Backup Script](#generalized-automated-backup-script)
  - [FCPXML Marker Extraction Script](#fcpxml-marker-extraction-script)
- [Contributing](#contributing)
- [License](#license)

## Overview

This repository is intended to provide useful shell scripts for various tasks, including backups, network checks, and general utility functions. Each script is designed to simplify common tasks that can be performed via the command line.


## Directory Structure

The repository is organized into the following directories:

- **`scripts/`**: Contains all the Bash scripts, organized by category.
  - **`backup/`**: Scripts for backing up data.
  - **`media/`**: Scripts for media processing and video editing tasks.

## Usage

To use a script, navigate to the desired directory and run the script:

```bash
cd scripts/backup
./emulator_saves_manual.sh [emulator] [options]
```

## Emulator Saves Manual Backup Script

The `emulator_saves_manual.sh` script is designed to back up and restore memory cards for various emulators.

### Usage
```bash
./emulator_saves_manual.sh <emulator> [--archive|-a | --list | --restore <backup_name>]
```
### Parameters
* `<emulator>`: The name of the emulator for which you want to back up the memory cards. Supported emulators 
	* pcsx2
	* dolphin
	* ppsspp
	* duckstation
* `--archive | -a`: Create a zip archive of the memory card files for backup.
* `--list`: List all backups available for the specified emulator.
* `--restore <backup_name>`: Restore a specific backup by name. If no backup name is provided, the script will display usage instructions.

### Example Commands
**Create an archive**: 
```bash
./emulator_saves_manual.sh pcsx2 --archive
```

**List all available backups**:
```bash
./emulator_saves_manual.sh dolphin --list
```

**Restore the latest backup**:
```bash
./emulator_saves_manual.sh pcsx2 --restore
```

**Restore a specific backup**:
```bash
./emulator_saves_manual.sh pcsx2 --restore memcards_backup_2024-10-28_14-30-00.zip
```

## Automated Backup Script with Restic

The emulator_saves_restic.sh script automates the backup process for emulator save files using Restic. It leverages Restic for efficient deduplication, encryption, and pruning of backups.

### Usage

Run the script from the terminal:

```bash
./emulator_saves_restic.sh
```

### Features

1. **Automated Backup:**
	* Backups are performed for preconfigured save file directories:
		* `~/Library/Application Support/PCSX2/memcards/`
		* `~/Library/Application Support/DuckStation/`
	* Backups are stored in a Restic repository located at `~/restic_save_games`.
2. **Retention Policy:**
	* Snapshots are pruned automatically based on the following retention rules:
		* **Hourly**: Keep the last **2** backups.
		* **Daily**: Keep the last **6** backups.
		* **Weekly**: Keep the last **3** backups.
		* **Monthly**: Keep the last **1** backup.
	* Retention rules are defined in the `KEEP_OPTIONS` variable.
3.	**Repository Unlock:**
	* Ensures the Restic repository is unlocked before creating backups.
4.	**Pruning and Cache Cleanup:**
	* After backups, old snapshots are pruned, and Restic’s cache is cleaned to optimize storage.

### Prerequisites
1.	**Restic Installed:**
	* Make sure Restic is installed on your system. For macOS, you can install it via Homebrew:
	```bash
		brew install restic
	```
1. **Existing Restic Repository:**
	* The Restic repository at `~/restic_save_games` must already exist. You can create the repository with the following command:
	```bash
	restic -r ~/restic_save_games init
	```
	* Make sure the password stored in `~/restic_password` matches the repository password.
1. **Password File:**
	* The password for the repository should be stored in `~/restic_password`. For example:
	```bash
	echo "your-password" > ~/restic_password
chmod 600 ~/restic_password
```	

### Notes
* Update the `BACKUP_SOURCES` array to include additional save file directories.
* Adjust the `KEEP_OPTIONS` variable to customize the retention policy.

## Generalized Automated Backup Script
The `automated_backup_restic.sh` script is a flexible, generalized version of the Restic backup process. It allows users to specify custom directories and backup repositories.

### Usage
Run the script from the terminal:
```bash
./automated_backup_restic.sh
```

### Features
1. Customizable Backup Source and Destination:
	* Define the backup source directory (`BACKUP_SOURCE`) and the Restic repository (`BACKUP_REPO`).
2.	**Retention Policy:**
	* Retains snapshots based on customizable rules:
	* **Hourly**: Keep the last **2** backups.
	* **Daily**: Keep the last **6** backups.
	* **Weekly**: Keep the last **3** backups.
	* **Monthly**: Keep the last **1** backup.
3.	**Repository Unlock:**
	* Unlocks the Restic repository automatically.
4.	Pruning and Cache Cleanup:
	* Prunes old snapshots and clears the Restic cache.

### Example Script Configuration
Here’s how to configure the variables in the script:
```bash
RESTIC_PASSWD="/home/<USERNAME>/restic_password"
BACKUP_SOURCE="/<LOCATION_TO_BACKUP>"
BACKUP_REPO="<PATH_TO_STORE_BACKUP>/<BACKUP_NAME>"
KEEP_OPTIONS="--keep-hourly 2 --keep-daily 6 --keep-weekly 3 --keep-monthly 1"
```

### Prerequisites
1.	Restic Installed:
	* Install Restic using your package manager (e.g., Homebrew for macOS or apt for Linux).
2.	Existing Restic Repository:
	* Initialize the repository with:
	```bash
	restic -r <BACKUP_REPO> init
	```
3.	Password File:
	* Store the password in a secure location, such as `/home/<USERNAME>/restic_password`.

## FCPXML Marker Extraction Script

The `extract_markers.sh` script extracts markers and chapter markers from Final Cut Pro XML (FCPXML) files and exports them in various formats for analysis or documentation purposes.

### Usage
```bash
./extract_markers.sh <fcpxml_file> [output_format] [marker_type]
```

### Parameters
* `<fcpxml_file>`: Path to the FCPXML file to process (required).
* `[output_format]`: Output format for the extracted markers (optional, default: `csv`).
  * `csv`: Comma-separated values with headers
  * `json`: Structured JSON array
  * `text`: Human-readable list format
* `[marker_type]`: Type of markers to extract (optional, default: `all`).
  * `all`: Export both regular markers and chapter markers
  * `marker`: Export only regular `<marker>` elements
  * `chapter-marker`: Export only `<chapter-marker>` elements

### Features

1. **Multiple Marker Types:**
	* Extracts both standard markers and chapter markers from FCPXML files.
	* Filter by specific marker type or export all markers.
2. **Time Format Conversion:**
	* Converts FCPXML fraction format (e.g., `220889/60s`) to:
		* Decimal seconds
		* HH:MM:SS.mmm timecode format
3. **Flexible Output Formats:**
	* **CSV**: Structured data suitable for spreadsheets and data analysis.
	* **JSON**: Machine-readable format for integration with other tools.
	* **Text**: Clean, human-readable format for quick review.
4. **Marker Attributes:**
	* Extracts marker name/value, start time, duration, and posterOffset (for chapter markers).

### Example Commands

**Extract all markers as CSV (default)**:
```bash
./extract_markers.sh project.fcpxml
```

**Extract all markers in human-readable text format**:
```bash
./extract_markers.sh project.fcpxml text
```

**Extract only regular markers as JSON**:
```bash
./extract_markers.sh project.fcpxml json marker
```

**Extract only chapter markers as CSV**:
```bash
./extract_markers.sh project.fcpxml csv chapter-marker
```

**Save output to a file**:
```bash
./extract_markers.sh project.fcpxml csv > markers.csv
```

### Output Examples

**CSV Format:**
```csv
Type,Name,Start Time,Start (Seconds),Duration
marker,"Scene Start",00:05:23.450,323.450,100/6000s
chapter-marker,"Chapter 1",00:10:15.233,615.233,100/6000s
```

**JSON Format:**
```json
[
  {
    "type": "marker",
    "name": "Scene Start",
    "start": "10567/30s",
    "startSeconds": 352.233,
    "timecode": "00:05:52.233",
    "duration": "100/6000s"
  },
  {
    "type": "chapter-marker",
    "name": "Chapter 1",
    "start": "220889/60s",
    "startSeconds": 3681.483,
    "timecode": "01:01:21.483",
    "duration": "100/6000s",
    "posterOffset": "11/59s"
  }
]
```

**Text Format:**
```
=== Markers from: project.fcpxml ===

[MARKER] 00:05:52.233 - Scene Start
[CHAPTER] 01:01:21.483 - Chapter 1
```

### Prerequisites

The script uses standard Unix tools available on macOS and Linux:
* `xmllint` (preferred for XML parsing, falls back to `grep` if unavailable)
* `bc` (for mathematical calculations)
* Standard shell utilities (`grep`, `read`, etc.)

### Notes

* The script automatically validates input files and marker type parameters.
* If `xmllint` is not available, the script falls back to grep-based extraction.
* Time calculations use `bc` for precision in timecode conversion.

