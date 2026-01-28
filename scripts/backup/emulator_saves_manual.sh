#!/bin/bash

# Define base paths for different emulators
APPLICATION_SUPPORT_PATH="$HOME/Library/Application Support"

# Define indexed arrays for emulator names and paths
EMULATOR_NAMES=("pcsx2" "dolphin" "ppsspp" "duckstation")
EMULATOR_PATHS=(
  "$APPLICATION_SUPPORT_PATH/PCSX2/memcards"
  "$APPLICATION_SUPPORT_PATH/Dolphin/GC"
  "$APPLICATION_SUPPORT_PATH/PPSSPP/memstick/PSP/SAVEDATA"
  "$APPLICATION_SUPPORT_PATH/DuckStation/memcards"
)

# Define the backup base directory
BACKUP_BASE_DIR="$HOME/Emulator_MemoryCard_Backups"

# Function to check if a directory exists, and create it if necessary
check_and_create_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    echo "Directory '$dir' does not exist."
    read -p "Would you like to create it? (y/n): " response
    case "$response" in
      [Yy]*)
        mkdir -p "$dir"
        echo "Directory '$dir' created."
        ;;
      *)
        echo "Directory '$dir' is required. Exiting."
        exit 1
        ;;
    esac
  fi
}

# Function to list backups for a given emulator
list_backups() {
  local emulator="$1"
  local backup_dir="$BACKUP_BASE_DIR/$emulator"
  check_and_create_directory "$backup_dir"
  echo "Backups for $emulator:"
  ls -1 "$backup_dir/"
}

# Function to restore a backup
restore_backup() {
  local emulator="$1"
  local backup="$2"
  local backup_dir="$BACKUP_BASE_DIR/$emulator"
  local destination_dir="${EMULATOR_PATHS[$(index_of "$emulator")]}"

  check_and_create_directory "$destination_dir"

  # Verify if the backup exists
  if [[ ! -f "$backup_dir/$backup" ]]; then
    echo "Error: Backup '$backup' does not exist for emulator '$emulator'."
    exit 1
  fi

  # Restore the backup (unzip or copy)
  if [[ "$backup" == *.zip ]]; then
    # Restore from zip
    unzip -o "$backup_dir/$backup" -d "$destination_dir"
  else
    # Restore from directory
    cp -r "$backup_dir/$backup" "$destination_dir"
  fi

  echo "Backup '$backup' restored for $emulator."
}

# Function to find the index of an emulator
index_of() {
  local emulator="$1"
  for i in "${!EMULATOR_NAMES[@]}"; do
    if [[ "${EMULATOR_NAMES[i]}" == "$emulator" ]]; then
      echo "$i"
      return
    fi
  done
  echo "-1" # Not found
}

# Check if an action was provided
if [[ -z "$1" ]]; then
  echo "Usage: $0 <emulator> [--archive|-a | --list | --restore <backup_name>]"
  echo "Supported emulators: ${EMULATOR_NAMES[*]}"
  exit 1
fi

# Get the emulator name
EMULATOR="$1"
MEMCARD_PATH=""

# Check for the action argument
ACTION="$2"
if [[ -z "$ACTION" ]]; then
  echo "Error: Missing action."
  echo "Usage: $0 <emulator> [--archive|-a | --list | --restore <backup_name>]"
  exit 1
fi

# Find the memory card path corresponding to the emulator
for i in "${!EMULATOR_NAMES[@]}"; do
  if [[ "${EMULATOR_NAMES[i]}" == "$EMULATOR" ]]; then
    MEMCARD_PATH="${EMULATOR_PATHS[i]}"
    break
  fi
done

# Verify the emulator is supported
if [[ -z "$MEMCARD_PATH" ]]; then
  echo "Error: Unsupported emulator '$EMULATOR'. Supported emulators: ${EMULATOR_NAMES[*]}"
  exit 1
fi

# Handle actions
case "$ACTION" in
  --archive | -a)
    # Create a timestamp for the backup
    TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
    ARCHIVE_NAME="$BACKUP_BASE_DIR/$EMULATOR/memcards_backup_$TIMESTAMP.zip"

    check_and_create_directory "$BACKUP_BASE_DIR/$EMULATOR"

    # Change to the memory card directory and create the zip archive
    (cd "$MEMCARD_PATH" && zip -r "$ARCHIVE_NAME" .)

    # Verify the zip archive
    if zip -T "$ARCHIVE_NAME"; then
      echo "Archive created and verified for $EMULATOR: $ARCHIVE_NAME"
    else
      echo "Error: Archive verification failed for $ARCHIVE_NAME"
      exit 1
    fi
    ;;

  --list)
    list_backups "$EMULATOR"
    ;;

  --restore)
    if [[ -z "$3" ]]; then
      echo "Usage: $0 <emulator> --restore <backup_name>"
      exit 1
    fi
    BACKUP_NAME="$3"
    restore_backup "$EMULATOR" "$BACKUP_NAME"
    ;;

  *)
    echo "Error: Unsupported action '$ACTION'."
    echo "Usage: $0 <emulator> [--archive|-a | --list | --restore <backup_name>]"
    exit 1
    ;;
esac
