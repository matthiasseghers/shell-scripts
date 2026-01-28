#!/bin/bash

# Define variables
RESTIC_PASSWD="$HOME/restic_password"
BACKUP_SOURCES=(
  "$HOME/Library/Application Support/PCSX2/memcards/"
  "$HOME/Library/Application Support/DuckStation/"
  "/Volumes/192.168.1.38/3ds/Checkpoint"
)
BACKUP_REPO="$HOME/restic_save_games"
KEEP_OPTIONS="--keep-hourly 2 --keep-daily 6 --keep-weekly 3 --keep-monthly 1"

# Perform Restic unlock and capture output
restic -p $RESTIC_PASSWD -r $BACKUP_REPO unlock

# Perform Restic backup
restic -p $RESTIC_PASSWD -r $BACKUP_REPO backup "${BACKUP_SOURCES[@]}"

# Perform Restic forget
restic -p $RESTIC_PASSWD -r $BACKUP_REPO forget $KEEP_OPTIONS --prune --cleanup-cache
