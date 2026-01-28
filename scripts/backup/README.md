# Backup Scripts

This directory contains scripts for backing up data using various methods.

## Overview

Three backup scripts are available:
- **automated_backup_restic.sh** - Generic automated Restic backup template
- **emulator_saves_manual.sh** - Manual emulator save backup/restore with ZIP archives
- **emulator_saves_restic.sh** - Automated emulator save backup using Restic

---

## automated_backup_restic.sh

A template script for automated Restic backups with unlock, backup, and retention management.

### Features

- **Automated Unlocking**: Unlocks repository before backup
- **Flexible Source**: Configurable backup source directory
- **Retention Policy**: Automatic pruning based on time-based rules
- **Cache Cleanup**: Cleans up Restic cache after operations

### Prerequisites

```bash
# Install Restic
brew install restic

# Or on Linux
apt install restic  # Debian/Ubuntu
```

### Configuration

Edit the script to set these variables:

```bash
RESTIC_PASSWD="/home/<USERNAME>/restic_password"
BACKUP_SOURCE="/<LOCATION_TO_BACKUP>"
BACKUP_REPO="<PATH_TO_STORE_BACKUP>/<BACKUP_NAME>"
KEEP_OPTIONS="--keep-hourly 2 --keep-daily 6 --keep-weekly 3 --keep-monthly 1"
```

**Variables explained:**
- `RESTIC_PASSWD`: Path to file containing Restic repository password
- `BACKUP_SOURCE`: Directory to backup
- `BACKUP_REPO`: Path to Restic repository
- `KEEP_OPTIONS`: Retention policy for old backups

### Retention Policy

Default retention (customize as needed):
- Keep 2 hourly backups
- Keep 6 daily backups
- Keep 3 weekly backups
- Keep 1 monthly backup

### Usage

```bash
# After configuring the script
./automated_backup_restic.sh
```

### Setup Steps

1. **Create password file**:
   ```bash
   echo "your-strong-password" > ~/restic_password
   chmod 600 ~/restic_password
   ```

2. **Initialize Restic repository** (first time only):
   ```bash
   restic -p ~/restic_password -r /path/to/repo init
   ```

3. **Configure script variables** (see Configuration section)

4. **Run backup**:
   ```bash
   ./automated_backup_restic.sh
   ```

5. **Automate with cron** (optional):
   ```bash
   # Edit crontab
   crontab -e
   
   # Add line for daily backup at 2 AM
   0 2 * * * /path/to/automated_backup_restic.sh
   ```

### What It Does

1. **Unlock**: Removes stale locks from repository
2. **Backup**: Creates new snapshot of source directory
3. **Forget**: Removes old snapshots based on retention policy
4. **Prune**: Reclaims space from deleted snapshots
5. **Cleanup**: Cleans Restic cache

---

## emulator_saves_manual.sh

Manual backup and restore script for emulator save files and memory cards with ZIP archive support.

### Features

- **Multiple Emulator Support**: PCSX2, Dolphin, PPSSPP, DuckStation
- **Archive Creation**: Creates timestamped ZIP archives
- **Archive Verification**: Verifies ZIP integrity after creation
- **Restore Capability**: Restore from any previous backup
- **List Backups**: View all available backups for an emulator
- **Interactive Prompts**: Asks before creating missing directories

### Supported Emulators

| Emulator | Save Location (macOS) |
|----------|----------------------|
| PCSX2 | `~/Library/Application Support/PCSX2/memcards` |
| Dolphin | `~/Library/Application Support/Dolphin/GC` |
| PPSSPP | `~/Library/Application Support/PPSSPP/memstick/PSP/SAVEDATA` |
| DuckStation | `~/Library/Application Support/DuckStation/memcards` |

### Usage

```bash
# Create backup
./emulator_saves_manual.sh <emulator> --archive
./emulator_saves_manual.sh <emulator> -a

# List backups
./emulator_saves_manual.sh <emulator> --list

# Restore backup
./emulator_saves_manual.sh <emulator> --restore <backup_name>
```

### Examples

**Backup PCSX2 memory cards**:
```bash
./emulator_saves_manual.sh pcsx2 --archive
# Creates: ~/Emulator_MemoryCard_Backups/pcsx2/memcards_backup_2026-01-28_14-30-45.zip
```

**List all PPSSPP backups**:
```bash
./emulator_saves_manual.sh ppsspp --list
```

**Restore a specific backup**:
```bash
./emulator_saves_manual.sh dolphin --restore memcards_backup_2026-01-28_14-30-45.zip
```

**Backup all emulators**:
```bash
for emu in pcsx2 dolphin ppsspp duckstation; do
    ./emulator_saves_manual.sh $emu --archive
done
```

### Backup Location

Backups are stored in: `~/Emulator_MemoryCard_Backups/<emulator>/`

### Archive Format

Archives are named: `memcards_backup_YYYY-MM-DD_HH-MM-SS.zip`

Example: `memcards_backup_2026-01-28_14-30-45.zip`

### Tips

1. **Regular backups before gaming sessions**:
   ```bash
   ./emulator_saves_manual.sh pcsx2 -a
   ```

2. **Backup before major updates**: Create backup before updating emulators

3. **Clean old backups**: Periodically remove old backups to save space:
   ```bash
   # List backups
   ./emulator_saves_manual.sh pcsx2 --list
   
   # Manually delete old ones
   rm ~/Emulator_MemoryCard_Backups/pcsx2/memcards_backup_<old_date>.zip
   ```

4. **Test restores**: Occasionally test restoring to verify backups work

---

## emulator_saves_restic.sh

Automated Restic-based backup for emulator save files with retention management.

### Features

- **Multiple Sources**: Backs up saves from multiple emulators in one operation
- **Network Shares**: Supports backing up from network-mounted volumes
- **Automated Retention**: Keeps time-based snapshots automatically
- **Deduplication**: Restic efficiently handles duplicate data
- **Encryption**: Backups are encrypted at rest
- **Fast Incremental**: Only backs up changed files

### Backed Up Locations

By default, backs up:
- PCSX2 memory cards
- DuckStation saves
- 3DS Checkpoint saves (from network share)

### Prerequisites

```bash
# Install Restic
brew install restic
```

### Configuration

Edit the script to customize:

```bash
RESTIC_PASSWD="$HOME/restic_password"
BACKUP_SOURCES=(
    "$HOME/Library/Application Support/PCSX2/memcards/"
    "$HOME/Library/Application Support/DuckStation/"
    "/Volumes/192.168.1.38/3ds/Checkpoint"
)
BACKUP_REPO="$HOME/restic_save_games"
KEEP_OPTIONS="--keep-hourly 2 --keep-daily 6 --keep-weekly 3 --keep-monthly 1"
```

### Retention Policy

Default retention:
- Keep 2 hourly snapshots
- Keep 6 daily snapshots
- Keep 3 weekly snapshots  
- Keep 1 monthly snapshot

### Usage

```bash
./emulator_saves_restic.sh
```

### Setup Steps

1. **Create password file**:
   ```bash
   echo "your-strong-password" > ~/restic_password
   chmod 600 ~/restic_password
   ```

2. **Initialize repository** (first time only):
   ```bash
   restic -p ~/restic_password -r ~/restic_save_games init
   ```

3. **Mount network shares** (if using network locations):
   ```bash
   # Mount your network share
   mount -t nfs 192.168.1.38:/3ds /Volumes/192.168.1.38/3ds
   ```

4. **Run first backup**:
   ```bash
   ./emulator_saves_restic.sh
   ```

5. **Automate with cron** (optional):
   ```bash
   # Edit crontab
   crontab -e
   
   # Backup hourly
   0 * * * * /path/to/emulator_saves_restic.sh
   
   # Or backup daily at 3 AM
   0 3 * * * /path/to/emulator_saves_restic.sh
   ```

### What It Does

1. **Unlock**: Removes stale repository locks
2. **Backup**: Creates encrypted snapshot of all save locations
3. **Forget**: Removes old snapshots per retention policy
4. **Prune**: Reclaims disk space from deleted snapshots
5. **Cleanup**: Cleans Restic cache

### Adding More Emulators

To backup additional emulators, add their paths to `BACKUP_SOURCES`:

```bash
BACKUP_SOURCES=(
    "$HOME/Library/Application Support/PCSX2/memcards/"
    "$HOME/Library/Application Support/DuckStation/"
    "$HOME/Library/Application Support/RetroArch/saves/"  # Add this
    "/Volumes/192.168.1.38/3ds/Checkpoint"
)
```

### Useful Restic Commands

**List all snapshots**:
```bash
restic -p ~/restic_password -r ~/restic_save_games snapshots
```

**Restore latest snapshot**:
```bash
restic -p ~/restic_password -r ~/restic_save_games restore latest --target /tmp/restore
```

**Restore specific file**:
```bash
restic -p ~/restic_password -r ~/restic_save_games restore latest \
    --target /tmp/restore \
    --include "*/PCSX2/memcards/*"
```

**Check repository integrity**:
```bash
restic -p ~/restic_password -r ~/restic_save_games check
```

**View repository stats**:
```bash
restic -p ~/restic_password -r ~/restic_save_games stats
```

---

## Comparison: Manual vs Restic

| Feature | emulator_saves_manual.sh | emulator_saves_restic.sh |
|---------|--------------------------|--------------------------|
| **Compression** | ZIP | Deduplicated + Encrypted |
| **Encryption** | No | Yes |
| **Speed** | Fast for small saves | Fast incremental |
| **Storage** | Full copy each time | Efficient deduplication |
| **Restore** | Simple unzip | Restic restore command |
| **Retention** | Manual deletion | Automatic |
| **Network Support** | No | Yes |
| **Best For** | Quick manual backups | Automated scheduled backups |

### When to Use Each

**Use emulator_saves_manual.sh when:**
- You want simple, manual backups before gaming
- You prefer ZIP files you can easily browse
- You want quick restore without special tools
- You backup infrequently

**Use emulator_saves_restic.sh when:**
- You want automated scheduled backups
- You need encrypted backups
- You backup frequently (deduplication saves space)
- You backup from network shares
- You want flexible restore options

## General Tips

1. **Test your backups**: Regularly verify you can restore from backups

2. **Multiple backup strategies**: Consider using both manual and automated backups:
   - Automated daily backups with Restic
   - Manual backups before important gaming sessions

3. **Off-site backups**: Consider backing up to external drives or cloud storage

4. **Monitor backup size**: Keep an eye on backup repository size

5. **Document your setup**: Keep notes on your backup configuration

6. **Verify before restoring**: List backups first to confirm you're restoring the right one

## Troubleshooting

**Restic "repository is locked" error**:
```bash
restic -p ~/restic_password -r ~/restic_save_games unlock
```

**Network share not accessible**:
- Verify network connection
- Check mount point exists
- Ensure share is mounted before running backup

**Permission denied errors**:
- Check file permissions on source directories
- Ensure script has execute permissions: `chmod +x script.sh`

**Backup taking too long**:
- Check for large files in backup sources
- Consider excluding unnecessary files
- For Restic, verify repository isn't on slow storage

**Missing directories**:
- Manual script will prompt to create directories
- For Restic, ensure all source paths exist or remove non-existent paths
