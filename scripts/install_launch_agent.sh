#!/usr/bin/env bash

set -euo pipefail

readonly LABEL="com.tiktokbackupdays.ttstore"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_PATH="$REPO_DIR/scripts/tiktok_ttstore_backup.sh"
readonly PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
readonly LOG_DIR="$HOME/Library/Logs/TikTokBackupDays"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
chmod +x "$SCRIPT_PATH"

SCRIPT_PATH="$SCRIPT_PATH" LOG_DIR="$LOG_DIR" PLIST_PATH="$PLIST_PATH" python3 <<'PY'
import os
import plistlib

plist = {
    "Label": "com.tiktokbackupdays.ttstore",
    "ProgramArguments": [os.environ["SCRIPT_PATH"]],
    "StartCalendarInterval": {"Hour": 5, "Minute": 0},
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
printf 'Plist: %s\n' "$PLIST_PATH"
printf 'Logs: %s\n' "$LOG_DIR"
