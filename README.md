# TikTok TTStore Backup Days

Daily macOS LaunchAgent backup for TikTok Live Studio `TTStore` files, including configuration and login-state files stored under `TTStore`.

## Quick Install

Run on macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/dammu/TikTokBackupDays/master/scripts/install_from_github.sh | bash
```

Default schedule is `05:00` in the Mac's local display time.

Custom schedule:

```bash
curl -fsSL https://raw.githubusercontent.com/dammu/TikTokBackupDays/master/scripts/install_from_github.sh | bash -s -- --time 06:30
```

The one-line installer downloads the public GitHub repo zip into:

```text
$HOME/.local/share/TikTokBackupDays
```

Then it runs:

```text
$HOME/.local/share/TikTokBackupDays/scripts/install_launch_agent.sh
```

## Paths

Source:

```text
$HOME/Library/Application Support/TikTok Live Studio/TTStore
```

Backups:

```text
$HOME/Documents/TikTokBackupDays/TTStoreBackups
```

Logs:

```text
$HOME/Library/Logs/TikTokBackupDays/backup.log
$HOME/Library/Logs/TikTokBackupDays/launchd.out.log
$HOME/Library/Logs/TikTokBackupDays/launchd.err.log
```

LaunchAgent plist:

```text
$HOME/Library/LaunchAgents/com.tiktokbackupdays.ttstore.plist
```

## Behavior

- Runs daily at the configured macOS local display time, default `05:00`.
- Runs once immediately after installation because `RunAtLoad` is enabled.
- Uses `$HOME`, so it works across Macs with different usernames.
- Keeps backups for `90` days.
- Rejects normal backups smaller than `1` byte or larger than `50 MB`.
- Uses a lock directory to prevent backup and restore from running at the same time.
- Writes detailed logs for backup, restore, validation, pruning, and errors.
- Before restore, creates a `*_pre_restore` safety backup of current files.

Backup directory names look like:

```text
2026-05-04_050000_auto
2026-05-04_153000_manual
2026-05-04_153000_manual_account_a
2026-05-04_160000_pre_restore
```

## Requirements

Run commands on macOS. The scripts expect standard macOS tools:

```text
bash, python3, rsync, curl, unzip, launchctl, plutil
```

macOS uses an older Bash by default; the scripts are written to avoid newer Bash-only behavior.

## Install From A Clone

If you already cloned the repo:

```bash
chmod +x scripts/*.sh
./scripts/install_launch_agent.sh
```

Custom schedule:

```bash
./scripts/install_launch_agent.sh --time 06:30
```

The `--time` format is `HH:MM`, with `00-23` hours and `00-59` minutes.

## Update Or Reinstall

Run the one-line install command again. It replaces files under:

```text
$HOME/.local/share/TikTokBackupDays
```

Then it regenerates and reloads the LaunchAgent plist.

Existing backups and logs are not deleted.

## Manual Backup

Automatic-style backup from the command line:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh
```

Manual backup with optional interactive account note:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh backup --manual
```

When prompted, press Enter to skip or type a short account note. The note is sanitized to lowercase letters, numbers, `_`, and `-`, then appended to the backup name.

Non-interactive manual backup with note:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh backup --manual --note account_a
```

## List Backups

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh list
```

## Restore

Restore latest backup with confirmation:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh restore
```

Restore latest backup without confirmation:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh restore --yes
```

Restore a specific backup:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/tiktok_ttstore_backup.sh restore --date 2026-05-04_153000_manual_account_a --yes
```

Restore names are restricted to the expected backup-name pattern to avoid accidental path traversal.

## Verify Service

Validate the generated plist:

```bash
plutil -lint "$HOME/Library/LaunchAgents/com.tiktokbackupdays.ttstore.plist"
```

Check LaunchAgent status:

```bash
launchctl print "gui/$(id -u)/com.tiktokbackupdays.ttstore"
```

Check logs:

```bash
tail -n 100 "$HOME/Library/Logs/TikTokBackupDays/backup.log"
tail -n 100 "$HOME/Library/Logs/TikTokBackupDays/launchd.err.log"
```

## Uninstall

If installed by one-line install:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/uninstall_launch_agent.sh
```

If running from a clone:

```bash
./scripts/uninstall_launch_agent.sh
```

Uninstall removes the LaunchAgent plist only. It does not delete backups or logs.

## Troubleshooting

If an old installer command still shows an old error, use the current URL:

```bash
curl -fsSL https://raw.githubusercontent.com/dammu/TikTokBackupDays/master/scripts/install_from_github.sh | bash
```

If you changed the schedule, rerun install with the new time:

```bash
curl -fsSL https://raw.githubusercontent.com/dammu/TikTokBackupDays/master/scripts/install_from_github.sh | bash -s -- --time 06:30
```

If the source directory does not exist yet, open TikTok Live Studio once so it can create:

```text
$HOME/Library/Application Support/TikTok Live Studio/TTStore
```

If a backup or restore says another operation is running, check for an active process first. If nothing is running, remove the stale lock:

```bash
rm -rf "$HOME/Documents/TikTokBackupDays/TTStoreBackups/.lock"
```
