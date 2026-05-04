#!/usr/bin/env bash

set -euo pipefail

readonly OWNER="dammu"
readonly REPO="TikTokBackupDays"
readonly BRANCH="master"
readonly INSTALL_DIR="$HOME/.local/share/TikTokBackupDays"
readonly ZIP_URL="https://api.github.com/repos/${OWNER}/${REPO}/zipball/${BRANCH}"

if [ -z "${GITHUB_TOKEN:-}" ]; then
  cat >&2 <<'ERR'
GITHUB_TOKEN is required because this repository is private.

Create a fine-grained GitHub token with read-only Contents access to this repo,
then run this installer with:

  GITHUB_TOKEN='YOUR_TOKEN_HERE' bash -c 'curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github.raw" "https://api.github.com/repos/dammu/TikTokBackupDays/contents/scripts/bootstrap_private_github.sh?ref=master" | bash'
ERR
  exit 1
fi

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf "$tmp_dir"
}
trap cleanup EXIT INT TERM

archive="$tmp_dir/repo.zip"
extract_dir="$tmp_dir/extract"
mkdir -p "$extract_dir" "$(dirname "$INSTALL_DIR")"

curl -fsSL \
  -H "Authorization: Bearer ${GITHUB_TOKEN}" \
  -H "Accept: application/vnd.github+json" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "$ZIP_URL" \
  -o "$archive"

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

"$INSTALL_DIR/scripts/install_launch_agent.sh"

printf 'Installed repository files to %s\n' "$INSTALL_DIR"
