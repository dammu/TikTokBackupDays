#!/usr/bin/env bash

set -euo pipefail

readonly LABEL="com.tiktokbackupdays.ttstore"
readonly REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly SCRIPT_PATH="$REPO_DIR/scripts/tiktok_ttstore_backup.sh"
readonly TEMPLATE_PATH="$REPO_DIR/launchd/${LABEL}.plist.template"
readonly PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"
readonly LOG_DIR="$HOME/Library/Logs/TikTokBackupDays"

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"
chmod +x "$SCRIPT_PATH"

sed \
  -e "s#__SCRIPT_PATH__#$SCRIPT_PATH#g" \
  -e "s#__HOME__#$HOME#g" \
  "$TEMPLATE_PATH" > "$PLIST_PATH"

chmod 644 "$PLIST_PATH"

if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
  launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
fi

launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$LABEL"
launchctl kickstart -k "gui/$(id -u)/$LABEL"

printf 'Installed %s\n' "$LABEL"
printf 'Plist: %s\n' "$PLIST_PATH"
printf 'Logs: %s\n' "$LOG_DIR"
