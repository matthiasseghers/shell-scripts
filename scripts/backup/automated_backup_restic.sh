#!/bin/bash

# Define variables
RESTIC_PASSWD="/home/<USERNAME>/restic_password"
BACKUP_SOURCE="/<LOCATION_TO_BACKUP>"
BACKUP_REPO="<PATH_TO_STORE_BACKUP>/<BACKUP_NAME>"
KEEP_OPTIONS="--keep-hourly 2 --keep-daily 6 --keep-weekly 3 --keep-monthly 1"

# Perform Restic unlock and capture output
restic -p $RESTIC_PASSWD -r $BACKUP_REPO unlock

# Perform Restic backup
restic -p $RESTIC_PASSWD -r $BACKUP_REPO backup $BACKUP_SOURCE

# Perform Restic forget
restic -p $RESTIC_PASSWD -r $BACKUP_REPO forget $KEEP_OPTIONS --prune --cleanup-cache
