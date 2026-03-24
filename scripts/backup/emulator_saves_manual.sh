#!/bin/bash

# ─────────────────────────────────────────────
# Emulator Memory Card Backup & Restore Script
# ─────────────────────────────────────────────

APPLICATION_SUPPORT_PATH="$HOME/Library/Application Support"

EMULATOR_NAMES=("pcsx2" "dolphin" "ppsspp" "duckstation")
EMULATOR_PATHS=(
  "$APPLICATION_SUPPORT_PATH/PCSX2/memcards"
  "$APPLICATION_SUPPORT_PATH/Dolphin/GC"
  "$APPLICATION_SUPPORT_PATH/PPSSPP/memstick/PSP/SAVEDATA"
  "$APPLICATION_SUPPORT_PATH/DuckStation/memcards"
)

BACKUP_BASE_DIR="$HOME/Emulator_MemoryCard_Backups"

# How many backups to keep per emulator (0 = keep all)
MAX_BACKUPS=10

# ─────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────

check_and_create_directory() {
  local dir="$1"
  if [[ ! -d "$dir" ]]; then
    mkdir -p "$dir"
    echo "Created directory: $dir"
  fi
}

index_of() {
  local emulator="$1"
  for i in "${!EMULATOR_NAMES[@]}"; do
    [[ "${EMULATOR_NAMES[i]}" == "$emulator" ]] && echo "$i" && return
  done
  echo "-1"
}

get_emulator_path() {
  local idx
  idx=$(index_of "$1")
  [[ "$idx" == "-1" ]] && echo "" || echo "${EMULATOR_PATHS[$idx]}"
}

print_usage() {
  echo ""
  echo "Usage: $0 <emulator|all> [action] [options]"
  echo ""
  echo "  Emulators : ${EMULATOR_NAMES[*]} | all"
  echo ""
  echo "  Actions:"
  echo "    --archive  | -a              Create a timestamped zip backup"
  echo "    --list     | -l              List available backups"
  echo "    --restore  | -r [name]       Restore a specific backup (interactive if name omitted)"
  echo "    --restore-latest             Restore the most recent backup"
  echo "    --prune    [N]               Keep only the N most recent backups (default: $MAX_BACKUPS)"
  echo ""
  echo "Examples:"
  echo "  $0 all --archive               # Backup all emulators"
  echo "  $0 pcsx2 --restore-latest      # Restore newest pcsx2 backup"
  echo "  $0 dolphin --restore           # Interactive restore picker"
  echo "  $0 all --prune 5               # Keep only 5 backups per emulator"
  echo ""
}

# ─────────────────────────────────────────────
# Core Actions
# ─────────────────────────────────────────────

do_archive() {
  local emulator="$1"
  local memcard_path
  memcard_path=$(get_emulator_path "$emulator")

  if [[ ! -d "$memcard_path" ]]; then
    echo "  [SKIP] $emulator — source path not found: $memcard_path"
    return
  fi

  local backup_dir="$BACKUP_BASE_DIR/$emulator"
  check_and_create_directory "$backup_dir"

  local timestamp
  timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
  local archive="$backup_dir/memcards_backup_$timestamp.zip"

  echo "  [BACKUP] $emulator → $(basename "$archive")"
  (cd "$memcard_path" && zip -rq "$archive" .)

  if zip -T "$archive" &>/dev/null; then
    echo "  [OK]     Verified: $archive"
  else
    echo "  [ERROR]  Verification failed: $archive"
    rm -f "$archive"
    return 1
  fi
}

do_list() {
  local emulator="$1"
  local backup_dir="$BACKUP_BASE_DIR/$emulator"

  if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
    echo "  No backups found for $emulator."
    return
  fi

  echo "  Backups for $emulator:"
  local i=1
  while IFS= read -r f; do
    printf "    %2d) %s\n" "$i" "$(basename "$f")"
    ((i++))
  done < <(ls -1t "$backup_dir/"*.zip 2>/dev/null)
}

do_restore() {
  local emulator="$1"
  local backup_name="$2" # optional; if empty, show picker
  local backup_dir="$BACKUP_BASE_DIR/$emulator"
  local dest
  dest=$(get_emulator_path "$emulator")

  if [[ -z "$dest" ]]; then
    echo "  [ERROR] Unknown emulator: $emulator"
    return 1
  fi

  # Build list of available backups
  local backups=()
  while IFS= read -r f; do
    backups+=("$f")
  done < <(ls -1t "$backup_dir/"*.zip 2>/dev/null)

  if [[ ${#backups[@]} -eq 0 ]]; then
    echo "  [ERROR] No backups found for $emulator."
    return 1
  fi

  local archive=""

  if [[ -n "$backup_name" ]]; then
    # Specific backup requested
    archive="$backup_dir/$backup_name"
    if [[ ! -f "$archive" ]]; then
      echo "  [ERROR] Backup not found: $archive"
      return 1
    fi
  else
    # Interactive picker
    echo ""
    echo "  Available backups for $emulator:"
    local i=1
    for f in "${backups[@]}"; do
      printf "    %2d) %s\n" "$i" "$(basename "$f")"
      ((i++))
    done
    echo ""
    read -rp "  Select backup number (1-${#backups[@]}): " choice
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || ((choice < 1 || choice > ${#backups[@]})); then
      echo "  [ERROR] Invalid selection."
      return 1
    fi
    archive="${backups[$((choice - 1))]}"
  fi

  check_and_create_directory "$dest"

  echo "  [RESTORE] $emulator ← $(basename "$archive")"
  unzip -oq "$archive" -d "$dest"
  echo "  [OK]      Restored to: $dest"
}

do_restore_latest() {
  local emulator="$1"
  local backup_dir="$BACKUP_BASE_DIR/$emulator"

  local latest
  latest=$(ls -1t "$backup_dir/"*.zip 2>/dev/null | head -n1)

  if [[ -z "$latest" ]]; then
    echo "  [ERROR] No backups found for $emulator."
    return 1
  fi

  do_restore "$emulator" "$(basename "$latest")"
}

do_prune() {
  local emulator="$1"
  local keep="${2:-$MAX_BACKUPS}"
  local backup_dir="$BACKUP_BASE_DIR/$emulator"

  if [[ "$keep" -le 0 ]]; then
    echo "  [SKIP] Prune disabled (keep=0)."
    return
  fi

  local all_backups=()
  while IFS= read -r f; do
    all_backups+=("$f")
  done < <(ls -1t "$backup_dir/"*.zip 2>/dev/null)

  local total=${#all_backups[@]}
  if ((total <= keep)); then
    echo "  [OK] $emulator — $total backup(s), nothing to prune (keeping $keep)."
    return
  fi

  local to_delete=$((total - keep))
  echo "  [PRUNE] $emulator — removing $to_delete old backup(s)..."
  for ((i = keep; i < total; i++)); do
    echo "    Deleting: $(basename "${all_backups[$i]}")"
    rm -f "${all_backups[$i]}"
  done
}

# ─────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────

if [[ -z "$1" || -z "$2" ]]; then
  print_usage
  exit 1
fi

TARGET="$1"
ACTION="$2"
EXTRA="$3"

# Expand "all" to every emulator
if [[ "$TARGET" == "all" ]]; then
  TARGETS=("${EMULATOR_NAMES[@]}")
else
  idx=$(index_of "$TARGET")
  if [[ "$idx" == "-1" ]]; then
    echo "Error: Unknown emulator '$TARGET'. Supported: ${EMULATOR_NAMES[*]} | all"
    exit 1
  fi
  TARGETS=("$TARGET")
fi

for emulator in "${TARGETS[@]}"; do
  case "$ACTION" in
    --archive | -a)
      do_archive "$emulator"
      [[ "$ACTION" == "--archive" || "$ACTION" == "-a" ]] &&
        [[ "$MAX_BACKUPS" -gt 0 ]] && do_prune "$emulator" "$MAX_BACKUPS"
      ;;
    --list | -l)
      do_list "$emulator"
      ;;
    --restore | -r)
      do_restore "$emulator" "$EXTRA"
      ;;
    --restore-latest)
      do_restore_latest "$emulator"
      ;;
    --prune)
      do_prune "$emulator" "$EXTRA"
      ;;
    *)
      echo "Error: Unknown action '$ACTION'."
      print_usage
      exit 1
      ;;
  esac
done
