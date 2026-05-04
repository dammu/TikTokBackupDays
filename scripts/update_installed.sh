#!/usr/bin/env bash

set -euo pipefail

readonly INSTALL_URL="https://raw.githubusercontent.com/dammu/TikTokBackupDays/master/scripts/install_from_github.sh"
readonly LABEL="com.tiktokbackupdays.ttstore"
readonly PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
SCHEDULE_TIME="05:00"

usage() {
  cat <<'USAGE'
Usage:
  update_installed.sh [--time HH:MM]

Options:
  --time HH:MM    Override the daily backup time while updating.
  -h, --help      Show this help.

Without --time, this script preserves the currently installed LaunchAgent schedule when possible.
USAGE
}

read_current_schedule() {
  [ -f "$PLIST_PATH" ] || return 1
  python3 - "$PLIST_PATH" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as f:
    plist = plistlib.load(f)

schedule = plist.get("StartCalendarInterval", {})
hour = schedule.get("Hour")
minute = schedule.get("Minute")
if hour is None or minute is None:
    sys.exit(1)

print(f"{int(hour):02d}:{int(minute):02d}")
PY
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --time)
      shift
      [ "$#" -gt 0 ] || {
        printf '%s\n' '--time requires HH:MM' >&2
        exit 1
      }
      SCHEDULE_TIME="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      printf 'Unknown argument: %s\n' "$1" >&2
      exit 1
      ;;
  esac
  shift
done

if [ "$SCHEDULE_TIME" = "05:00" ]; then
  SCHEDULE_TIME="$(read_current_schedule || printf '05:00')"
fi

printf 'Updating installed TikTokBackupDays with schedule %s local time.\n' "$SCHEDULE_TIME"
curl -fsSL "$INSTALL_URL" | bash -s -- --time "$SCHEDULE_TIME"
