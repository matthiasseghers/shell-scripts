#!/bin/bash

# ─────────────────────────────────────────────
# Emulator Save Backup — Restic
# ─────────────────────────────────────────────

RESTIC_PASSWD="$HOME/restic_password"
BACKUP_REPO="$HOME/restic_emulator_saves"

BACKUP_SOURCES=(
  "$HOME/Library/Application Support/PCSX2/memcards"
  "$HOME/Library/Application Support/DuckStation/memcards"
  "$HOME/Library/Application Support/Dolphin/GC"
  "$HOME/Library/Application Support/PPSSPP/memstick/PSP/SAVEDATA"
)

KEEP_OPTIONS="--keep-daily 7 --keep-weekly 4 --keep-monthly 2"

# ─────────────────────────────────────────────

restic -p "$RESTIC_PASSWD" -r "$BACKUP_REPO" unlock
restic -p "$RESTIC_PASSWD" -r "$BACKUP_REPO" backup "${BACKUP_SOURCES[@]}"
restic -p "$RESTIC_PASSWD" -r "$BACKUP_REPO" forget $KEEP_OPTIONS --prune
restic -p "$RESTIC_PASSWD" -r "$BACKUP_REPO" cache --cleanup
