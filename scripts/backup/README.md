# Backup Scripts

This directory contains scripts for backing up emulator save data.

## Overview

Two backup scripts are available:
- **emulator_saves_manual.sh** - Manual emulator save backup/restore with ZIP archives
- **emulator_saves_restic.sh** - Automated emulator save backup using Restic

A launchd plist is provided for automated scheduling on macOS:
- **com.user.emulator-saves-backup.plist** - Runs the Restic backup daily

---

## emulator_saves_manual.sh

Backup and restore script for emulator save files and memory cards with ZIP archive support,
automatic pruning, and interactive restore.

### Features

- **Multiple Emulator Support**: PCSX2, Dolphin, PPSSPP, DuckStation
- **Bulk Backup**: Back up all emulators at once with the `all` target
- **Archive Creation**: Creates timestamped ZIP archives
- **Archive Verification**: Verifies ZIP integrity after creation
- **Interactive Restore**: Numbered picker when no backup name is specified
- **Restore Latest**: One-command restore of the most recent backup
- **Auto-Prune**: Automatically removes old backups after archiving (configurable)
- **Manual Prune**: Trim backups for any emulator on demand
- **List Backups**: View all available backups for an emulator

### Supported Emulators

| Emulator | Save Location (macOS) |
|----------|----------------------|
| PCSX2 | `~/Library/Application Support/PCSX2/memcards` |
| Dolphin | `~/Library/Application Support/Dolphin/GC` |
| PPSSPP | `~/Library/Application Support/PPSSPP/memstick/PSP/SAVEDATA` |
| DuckStation | `~/Library/Application Support/DuckStation/memcards` |

### Configuration

At the top of the script, set `MAX_BACKUPS` to control how many backups are kept per emulator
after each archive operation. Set to `0` to disable auto-pruning.

```bash
MAX_BACKUPS=10  # Keep the 10 most recent backups per emulator (0 = keep all)
```

### Usage

```bash
./emulator_saves_manual.sh <emulator|all> [action] [options]
```

| Action | Short | Description |
|--------|-------|-------------|
| `--archive` | `-a` | Create a timestamped ZIP backup |
| `--list` | `-l` | List available backups |
| `--restore [name]` | `-r` | Restore a backup (interactive picker if name omitted) |
| `--restore-latest` | | Restore the most recent backup |
| `--prune [N]` | | Keep only the N most recent backups (default: `MAX_BACKUPS`) |

### Examples

**Backup all emulators at once**:
```bash
./emulator_saves_manual.sh all --archive
```

**Backup a single emulator**:
```bash
./emulator_saves_manual.sh pcsx2 --archive
# Creates: ~/Emulator_MemoryCard_Backups/pcsx2/memcards_backup_2026-01-28_14-30-45.zip
```

**List all PPSSPP backups**:
```bash
./emulator_saves_manual.sh ppsspp --list
```

**Restore interactively** (shows a numbered picker):
```bash
./emulator_saves_manual.sh dolphin --restore
#   Available backups for dolphin:
#    1) memcards_backup_2026-03-19_14-00-00.zip
#    2) memcards_backup_2026-03-18_14-00-00.zip
#   Select backup number (1-2):
```

**Restore the latest backup without prompts**:
```bash
./emulator_saves_manual.sh pcsx2 --restore-latest
```

**Restore a specific backup by name**:
```bash
./emulator_saves_manual.sh dolphin --restore memcards_backup_2026-01-28_14-30-45.zip
```

**Manually prune old backups** (keep 5 most recent):
```bash
./emulator_saves_manual.sh all --prune 5
```

### Backup Location

Backups are stored in: `~/Emulator_MemoryCard_Backups/<emulator>/`

### Archive Format

Archives are named: `memcards_backup_YYYY-MM-DD_HH-MM-SS.zip`

---

## emulator_saves_restic.sh

Thin wrapper script around Restic for automated emulator save backups. All backup, retention,
deduplication, and restore logic is handled by Restic — the script exists only to store
configuration and sequence the necessary Restic commands.

### Features

- **All Four Emulators**: PCSX2, Dolphin, PPSSPP, DuckStation backed up in one run
- **Deduplication**: Restic stores only changed data — frequent backups cost almost no extra space
- **Encryption**: Repository is encrypted at rest
- **Automatic Retention**: Old snapshots pruned based on a time-based policy
- **Low Maintenance**: No backup or restore logic to maintain — Restic handles it

### Configuration

Edit the variables at the top of the script:

```bash
RESTIC_PASSWD="$HOME/restic_password"       # Path to password file
BACKUP_REPO="$HOME/restic_emulator_saves"   # Where the repository lives
KEEP_OPTIONS="--keep-daily 7 --keep-weekly 4 --keep-monthly 2"
```

### Retention Policy

Default retention:
- Keep daily snapshots for 7 days
- Keep weekly snapshots for 4 weeks
- Keep monthly snapshots for 2 months

### Prerequisites

```bash
brew install restic
```

### Setup (one-time)

1. **Create a password file**:
   ```bash
   echo "your-strong-password" > ~/restic_password
   chmod 600 ~/restic_password
   ```

2. **Initialize the repository**:
   ```bash
   restic -p ~/restic_password -r ~/restic_emulator_saves init
   ```

3. **Run a first backup to verify**:
   ```bash
   ./emulator_saves_restic.sh
   ```

4. **Load the launchd plist** (see below) for automated daily runs.

### Usage

```bash
./emulator_saves_restic.sh
```

### Restoring

**List all snapshots**:
```bash
restic -p ~/restic_password -r ~/restic_emulator_saves snapshots
```

**Restore the latest snapshot**:
```bash
restic -p ~/restic_password -r ~/restic_emulator_saves restore latest --target /tmp/restore
```

**Restore only one emulator's saves**:
```bash
restic -p ~/restic_password -r ~/restic_emulator_saves restore latest \
  --target /tmp/restore --include "*/PCSX2/*"
```

**Check repository integrity**:
```bash
restic -p ~/restic_password -r ~/restic_emulator_saves check
```

---

## com.user.emulator-saves-backup.plist

Schedules `emulator_saves_restic.sh` to run daily via launchd.

### Why launchd instead of cron

launchd is the correct scheduler for macOS because it handles sleep gracefully: if the Mac
is asleep at the scheduled time, the job runs once when it next wakes. Cron skips missed
runs entirely, which means a sleeping Mac may never run the backup. Missing multiple scheduled
times does not cause multiple catch-up runs — launchd runs it exactly once on wake.

### Setup

1. **Edit the plist** — replace `YOUR_USERNAME` with your actual username and verify the
   script path.

2. **Place it in LaunchAgents**:
   ```bash
   cp com.user.emulator-saves-backup.plist ~/Library/LaunchAgents/
   ```

3. **Load it**:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.user.emulator-saves-backup.plist
   ```

4. **To unload or disable**:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.user.emulator-saves-backup.plist
   ```

Backup output is logged to `~/restic_emulator_saves/backup.log`.

---

## Comparison: Manual ZIP vs Restic

| Feature | emulator_saves_manual.sh | emulator_saves_restic.sh |
|---------|--------------------------|--------------------------|
| **Compression** | ZIP | Deduplicated + Encrypted |
| **Encryption** | No | Yes |
| **Storage** | Full copy each time | Efficient deduplication |
| **Restore** | Interactive picker / restore-latest | `restic restore` command |
| **Retention** | Auto-prune after archive | Automatic time-based |
| **Scheduling** | launchd plist | launchd plist |
| **Maintenance** | Own the logic | Restic owns the logic |
| **Dependencies** | None (bash + zip) | Restic |
| **Best For** | Quick manual backups | Automated scheduled backups |

### When to use each

**Use emulator_saves_manual.sh when:**
- You want a quick backup before a gaming session
- You prefer plain ZIP files you can browse or share without any tooling

**Use emulator_saves_restic.sh when:**
- You want fully automated backups you never have to think about
- You back up frequently and care about storage efficiency
- You want encryption at rest

---

## Troubleshooting

**Restic "repository is locked" error**:
```bash
restic -p ~/restic_password -r ~/restic_emulator_saves unlock
```

**Permission denied errors**:
- Check file permissions on source directories
- Ensure scripts have execute permissions: `chmod +x script.sh`

**Plist not running**:
- Verify `YOUR_USERNAME` was replaced in the plist
- Check the log file at `~/restic_emulator_saves/backup.log`
- Reload the plist: `launchctl unload` then `launchctl load`

**Missing save directories**:
- If an emulator path doesn't exist, restic will error on that path
- Remove unused paths from `BACKUP_SOURCES` in the script