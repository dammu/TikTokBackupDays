#!/usr/bin/env bash

set -euo pipefail

readonly OWNER="dammu"
readonly REPO="TikTokBackupDays"
readonly BRANCH="master"
readonly INSTALL_DIR="$HOME/.local/share/TikTokBackupDays"
readonly ZIP_URL="https://github.com/${OWNER}/${REPO}/archive/refs/heads/${BRANCH}.zip"

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

archive="$tmp_dir/repo.zip"
extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir" "$(dirname "$INSTALL_DIR")"

curl -fsSL "$ZIP_URL" -o "$archive"
unzip -q "$archive" -d "$extract_dir"

rm -rf "$INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

repo_root="$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
[ -n "$repo_root" ] || {
  printf 'Failed to locate extracted repository root.\n' >&2
  exit 1
}

cp -R "$repo_root/." "$INSTALL_DIR/"
chmod +x "$INSTALL_DIR/scripts/"*.sh

"$INSTALL_DIR/scripts/install_launch_agent.sh" "$@"

printf 'Installed repository files to %s\n' "$INSTALL_DIR"
