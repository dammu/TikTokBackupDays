#!/usr/bin/env bash

set -euo pipefail

readonly LABEL="com.tiktokbackupdays.ttstore"
readonly PLIST_PATH="$HOME/Library/LaunchAgents/${LABEL}.plist"

if [ -f "$PLIST_PATH" ]; then
  launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
  rm -f "$PLIST_PATH"
fi

printf 'Uninstalled %s\n' "$LABEL"
