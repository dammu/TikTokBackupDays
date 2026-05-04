#!/usr/bin/env bash

set -uo pipefail
IFS=$'\n\t'

readonly APP_NAME="tiktok-ttstore-backup"
readonly SOURCE_DIR="$HOME/Library/Application Support/TikTok Live Studio/TTStore"
readonly BACKUP_ROOT="$HOME/Documents/TikTokBackupDays/TTStoreBackups"
readonly LOG_DIR="$HOME/Library/Logs/TikTokBackupDays"
readonly LOG_FILE="$LOG_DIR/backup.log"
readonly LOCK_DIR="$BACKUP_ROOT/.lock"
readonly RETENTION_DAYS=90
readonly MAX_BACKUP_BYTES=$((50 * 1024 * 1024))
readonly MIN_BACKUP_BYTES=1

MODE="auto"
MANUAL_NOTE=""
RESTORE_MODE="select"
RESTORE_DATE=""
YES="false"

usage() {
  cat <<'USAGE'
Usage:
  tiktok_ttstore_backup.sh [backup|restore|list] [options]

Commands:
  backup                 Backup current TTStore state. Default command.
  restore                List backups and interactively choose one by number.
  restore latest         Restore the latest backup.
  restore specific NAME  Restore a specific backup directory name.
  list                   List available backups.

Options:
  --manual               Mark a backup as manual.
  --note TEXT            Add a sanitized note suffix to a manual backup.
  --date NAME            Restore a specific backup directory name.
  --yes                  Restore without interactive confirmation.
  -h, --help             Show this help.

Examples:
  ./scripts/tiktok_ttstore_backup.sh
  ./scripts/tiktok_ttstore_backup.sh backup --manual
  ./scripts/tiktok_ttstore_backup.sh backup --manual --note account_a
  ./scripts/tiktok_ttstore_backup.sh list
  ./scripts/tiktok_ttstore_backup.sh restore
  ./scripts/tiktok_ttstore_backup.sh restore latest --yes
  ./scripts/tiktok_ttstore_backup.sh restore specific 2026-05-04_153000_manual_account_a --yes
USAGE
}

timestamp() {
  date '+%Y-%m-%d %H:%M:%S'
}

log() {
  mkdir -p "$LOG_DIR"
  printf '[%s] [%s] %s\n' "$(timestamp)" "$APP_NAME" "$*" | tee -a "$LOG_FILE"
}

fail() {
  log "ERROR: $*"
  exit 1
}

release_lock() {
  [ -n "${LOCK_HELD:-}" ] && rmdir "$LOCK_DIR" 2>/dev/null || true
}

acquire_lock() {
  mkdir -p "$BACKUP_ROOT"
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    fail "another backup or restore is already running: $LOCK_DIR"
  fi
  LOCK_HELD="true"
  trap release_lock EXIT INT TERM
}

dir_size_bytes() {
  local dir="$1"
  du -sk "$dir" 2>/dev/null | awk '{print $1 * 1024}'
}

latest_backup() {
  [ -d "$BACKUP_ROOT" ] || return 1
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '????-??-??_??????_*' | sort | tail -n 1
}

all_backups_newest_first() {
  [ -d "$BACKUP_ROOT" ] || return 1
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '????-??-??_??????_*' | sort -r
}

validate_backup_size() {
  local backup_dir="$1"
  local size_bytes
  size_bytes="$(dir_size_bytes "$backup_dir")"

  [ -n "$size_bytes" ] || return 1
  if [ "$size_bytes" -lt "$MIN_BACKUP_BYTES" ]; then
    log "Backup size is suspiciously small: ${size_bytes} bytes"
    return 1
  fi

  if [ "$size_bytes" -gt "$MAX_BACKUP_BYTES" ]; then
    log "Backup size is suspiciously large: ${size_bytes} bytes; limit is ${MAX_BACKUP_BYTES} bytes"
    return 1
  fi

  log "Backup size validated: ${size_bytes} bytes"
  return 0
}

validate_backup_not_empty() {
  local backup_dir="$1"
  local size_bytes
  size_bytes="$(dir_size_bytes "$backup_dir")"

  [ -n "$size_bytes" ] || return 1
  if [ "$size_bytes" -lt "$MIN_BACKUP_BYTES" ]; then
    log "Backup size is suspiciously small: ${size_bytes} bytes"
    return 1
  fi

  log "Backup size validated for restore: ${size_bytes} bytes"
  return 0
}

validate_restore_name() {
  local name="$1"
  case "$name" in
    *[!/A-Za-z0-9_-]*|*/*|*..*)
      return 1
      ;;
  esac

  case "$name" in
    ????-??-??_??????_auto|????-??-??_??????_manual|????-??-??_??????_manual_*|????-??-??_??????_pre_restore)
      return 0
      ;;
  esac

  return 1
}

sanitize_note() {
  local raw="$1"
  local note
  note="$(printf '%s' "$raw" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]_-' '_')"
  note="${note##_}"
  note="${note%%_}"
  printf '%.40s' "$note"
}

prune_old_backups() {
  [ -d "$BACKUP_ROOT" ] || return 0
  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -mtime +"$RETENTION_DAYS" -print | while IFS= read -r old_backup; do
    log "Pruning old backup: $old_backup"
    rm -rf "$old_backup" || log "ERROR: failed to prune old backup: $old_backup"
  done
}

backup_now() {
  local label="$1"
  local stamp backup_dir temp_dir

  [ -d "$SOURCE_DIR" ] || fail "Source directory does not exist: $SOURCE_DIR"

  mkdir -p "$BACKUP_ROOT" "$LOG_DIR"
  acquire_lock

  stamp="$(date '+%Y-%m-%d_%H%M%S')"
  backup_dir="$BACKUP_ROOT/${stamp}_${label}"
  temp_dir="$BACKUP_ROOT/.${stamp}_${label}.tmp"

  [ ! -e "$backup_dir" ] || fail "backup destination already exists: $backup_dir"

  log "Starting ${label} backup"
  log "Source: $SOURCE_DIR"
  log "Destination: $backup_dir"

  rm -rf "$temp_dir"
  mkdir -p "$temp_dir"

  if ! rsync -a --delete -- "$SOURCE_DIR/" "$temp_dir/" >>"$LOG_FILE" 2>&1; then
    rm -rf "$temp_dir"
    fail "rsync backup failed"
  fi

  if ! validate_backup_size "$temp_dir"; then
    rm -rf "$temp_dir"
    fail "backup validation failed; temporary backup removed"
  fi

  mv "$temp_dir" "$backup_dir" || fail "failed to finalize backup"
  prune_old_backups
  log "Backup completed: $backup_dir"
}

manual_label() {
  local note

  if [ -z "$MANUAL_NOTE" ] && [ -t 0 ]; then
    printf 'Optional account note for this manual backup. Press Enter to skip: ' >&2
    read -r MANUAL_NOTE
  fi

  note="$(sanitize_note "$MANUAL_NOTE")"
  if [ -n "$note" ]; then
    printf 'manual_%s' "$note"
  else
    printf 'manual'
  fi
}

list_backups() {
  if [ ! -d "$BACKUP_ROOT" ]; then
    log "No backup directory exists yet: $BACKUP_ROOT"
    return 0
  fi

  find "$BACKUP_ROOT" -mindepth 1 -maxdepth 1 -type d -name '????-??-??_??????_*' | sort
}

choose_restore_backup() {
  local backups_file count choice selected

  if [ ! -t 0 ]; then
    fail "restore requires an interactive terminal; use 'restore latest' or 'restore specific NAME' instead"
  fi

  backups_file="$(mktemp)" || return 1
  all_backups_newest_first > "$backups_file"
  count="$(wc -l < "$backups_file" | tr -d ' ')"

  if [ "$count" = "0" ]; then
    rm -f "$backups_file"
    return 1
  fi

  printf 'Available backups, newest first:\n' >&2
  nl -w 2 -s '. ' "$backups_file" >&2
  printf 'Choose backup number to restore: ' >&2
  read -r choice

  case "$choice" in
    *[!0-9]*|'')
      rm -f "$backups_file"
      fail "Invalid backup selection: $choice"
      ;;
  esac

  if [ "$choice" -lt 1 ] || [ "$choice" -gt "$count" ]; then
    rm -f "$backups_file"
    fail "Backup selection out of range: $choice"
  fi

  selected="$(sed -n "${choice}p" "$backups_file")"
  rm -f "$backups_file"
  [ -n "$selected" ] || return 1
  printf '%s\n' "$selected"
}

restore_backup() {
  local selected backup_name restore_safety_dir stamp

  case "$RESTORE_MODE" in
    select)
      selected="$(choose_restore_backup || true)"
      ;;
    latest)
      selected="$(latest_backup || true)"
      ;;
    specific)
      [ -n "$RESTORE_DATE" ] || fail "restore specific requires a backup directory name"
      validate_restore_name "$RESTORE_DATE" || fail "Invalid backup name: $RESTORE_DATE"
      selected="$BACKUP_ROOT/$RESTORE_DATE"
      ;;
  esac

  [ -n "$selected" ] || fail "No backups found under: $BACKUP_ROOT"
  [ -d "$selected" ] || fail "Backup does not exist: $selected"
  backup_name="$(basename "$selected")"

  case "$backup_name" in
    *_pre_restore)
      validate_backup_not_empty "$selected" || fail "Selected backup failed size validation: $selected"
      ;;
    *)
      validate_backup_size "$selected" || fail "Selected backup failed size validation: $selected"
      ;;
  esac

  log "Preparing restore from: $backup_name"

  if [ "$YES" != "true" ]; then
    printf 'Restore backup "%s" to "%s"? This will replace current files. Type yes to continue: ' "$backup_name" "$SOURCE_DIR"
    read -r answer
    [ "$answer" = "yes" ] || fail "Restore cancelled"
  fi

  mkdir -p "$SOURCE_DIR" "$BACKUP_ROOT"
  acquire_lock
  stamp="$(date '+%Y-%m-%d_%H%M%S')"
  restore_safety_dir="$BACKUP_ROOT/${stamp}_pre_restore"
  [ ! -e "$restore_safety_dir" ] || fail "pre-restore safety backup already exists: $restore_safety_dir"

  if [ -d "$SOURCE_DIR" ] && [ "$(find "$SOURCE_DIR" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l | tr -d ' ')" != "0" ]; then
    log "Creating pre-restore safety backup: $restore_safety_dir"
    mkdir -p "$restore_safety_dir"
    if ! rsync -a --delete -- "$SOURCE_DIR/" "$restore_safety_dir/" >>"$LOG_FILE" 2>&1; then
      rm -rf "$restore_safety_dir"
      fail "failed to create pre-restore safety backup"
    fi
  fi

  log "Restoring backup into source directory"
  if ! rsync -a --delete -- "$selected/" "$SOURCE_DIR/" >>"$LOG_FILE" 2>&1; then
    fail "restore rsync failed"
  fi

  log "Restore completed from: $selected"
}

COMMAND="backup"
while [ "$#" -gt 0 ]; do
  case "$1" in
    backup|restore|list)
      COMMAND="$1"
      ;;
    latest)
      if [ "$COMMAND" = "restore" ]; then
        RESTORE_MODE="latest"
      else
        usage
        fail "Unexpected argument: $1"
      fi
      ;;
    specific)
      if [ "$COMMAND" = "restore" ]; then
        RESTORE_MODE="specific"
        shift
        [ "$#" -gt 0 ] || fail "restore specific requires a backup directory name"
        RESTORE_DATE="$1"
      else
        usage
        fail "Unexpected argument: $1"
      fi
      ;;
    --manual)
      MODE="manual"
      ;;
    --note)
      shift
      [ "$#" -gt 0 ] || fail "--note requires a value"
      MANUAL_NOTE="$1"
      MODE="manual"
      ;;
    --date)
      shift
      [ "$#" -gt 0 ] || fail "--date requires a backup directory name"
      RESTORE_DATE="$1"
      RESTORE_MODE="specific"
      ;;
    --yes)
      YES="true"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "Unknown argument: $1"
      ;;
  esac
  shift
done

case "$COMMAND" in
  backup)
    if [ "$MODE" = "manual" ]; then
      backup_now "$(manual_label)"
    else
      backup_now "$MODE"
    fi
    ;;
  restore)
    restore_backup
    ;;
  list)
    list_backups
    ;;
esac
