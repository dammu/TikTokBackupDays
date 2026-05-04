#!/usr/bin/env bash

set -euo pipefail

readonly LABEL="com.tiktokbackupdays.ttstore"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_PATH="$REPO_DIR/scripts/tiktok_ttstore_backup.sh"
readonly PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
readonly LOG_DIR="$HOME/Library/Logs/TikTokBackupDays"
SCHEDULE_TIME="05:00"

usage() {
  cat <<'USAGE'
Usage:
  install_launch_agent.sh [--time HH:MM]

Options:
  --time HH:MM    Daily backup time in the Mac's local display time. Default: 05:00.
  -h, --help      Show this help.
USAGE
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

case "$SCHEDULE_TIME" in
  [0-2][0-9]:[0-5][0-9])
    ;;
  *)
    printf 'Invalid --time value: %s. Expected HH:MM, for example 05:00.\n' "$SCHEDULE_TIME" >&2
    exit 1
    ;;
esac

SCHEDULE_HOUR="${SCHEDULE_TIME%:*}"
SCHEDULE_MINUTE="${SCHEDULE_TIME#*:}"
SCHEDULE_HOUR="$((10#$SCHEDULE_HOUR))"
SCHEDULE_MINUTE="$((10#$SCHEDULE_MINUTE))"

if [ "$SCHEDULE_HOUR" -gt 23 ]; then
  printf 'Invalid --time hour: %s. Expected 00-23.\n' "$SCHEDULE_TIME" >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
chmod +x "$SCRIPT_PATH"

SCRIPT_PATH="$SCRIPT_PATH" LOG_DIR="$LOG_DIR" PLIST_PATH="$PLIST_PATH" SCHEDULE_HOUR="$SCHEDULE_HOUR" SCHEDULE_MINUTE="$SCHEDULE_MINUTE" python3 <<'PY'
import os
import plistlib

plist = {
    "Label": "com.tiktokbackupdays.ttstore",
    "ProgramArguments": [os.environ["SCRIPT_PATH"]],
    "StartCalendarInterval": {"Hour": int(os.environ["SCHEDULE_HOUR"]), "Minute": int(os.environ["SCHEDULE_MINUTE"])},
    "RunAtLoad": True,
    "StandardOutPath": os.path.join(os.environ["LOG_DIR"], "launchd.out.log"),
    "StandardErrorPath": os.path.join(os.environ["LOG_DIR"], "launchd.err.log"),
}

with open(os.environ["PLIST_PATH"], "wb") as f:
    plistlib.dump(plist, f, sort_keys=False)
PY

chmod 644 "$PLIST_PATH"

launchctl bootout "gui/$(id -u)/$LABEL" >/dev/null 2>&1 || true
launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true

launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

printf 'Installed %s\n' "$LABEL"
printf 'Schedule: %02d:%02d local time\n' "$SCHEDULE_HOUR" "$SCHEDULE_MINUTE"
printf 'Plist: %s\n' "$PLIST_PATH"
printf 'Logs: %s\n' "$LOG_DIR"
