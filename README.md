# TikTok TTStore Backup Days

macOS LaunchAgent based daily backup for TikTok Live Studio `TTStore` configuration files.

## What It Backs Up

Source directory:

```text
$HOME/Library/Application Support/TikTok Live Studio/TTStore
```

Backup destination:

```text
$HOME/Documents/TikTokBackupDays/TTStoreBackups
```

Logs:

```text
$HOME/Library/Logs/TikTokBackupDays/backup.log
$HOME/Library/Logs/TikTokBackupDays/launchd.out.log
$HOME/Library/Logs/TikTokBackupDays/launchd.err.log
```

## Behavior

- Runs automatically every day at `05:00` macOS local display time, using the Mac's configured time zone.
- Also runs once immediately after installation because `RunAtLoad` is enabled.
- Keeps backups for `90` days.
- Rejects suspicious backups smaller than `1` byte or larger than `50 MB`.
- Writes detailed logs for start, source, destination, validation, prune, backup, and restore events.
- Creates a pre-restore safety backup before restoring over current files.

## One-Line Install

Run this on macOS:

```bash
curl -fsSL https://raw.githubusercontent.com/dammu/TikTokBackupDays/master/scripts/bootstrap_github.sh | bash
```

This downloads the repo zip into:

```text
$HOME/.local/share/TikTokBackupDays
```

Then it runs:

```bash
$HOME/.local/share/TikTokBackupDays/scripts/install_launch_agent.sh
```

## Git Clone Deploy On A Mac

Prerequisites on macOS:

- `bash`, `python3`, `rsync`, `curl`, `unzip`, and `launchctl` available from the default system install or developer tools.
- Run these commands on macOS, not from a Windows clone of the repo.

Clone the repo, then run:

```bash
chmod +x scripts/*.sh
./scripts/install_launch_agent.sh
```

The installer generates this user LaunchAgent:

```text
$HOME/Library/LaunchAgents/com.tiktokbackupdays.ttstore.plist
```

It automatically uses the current Mac user through `$HOME`, so the repo works on different Macs with different usernames.

## Manual Backup

Automatic backup:

```bash
./scripts/tiktok_ttstore_backup.sh
```

Manual marked backup:

```bash
./scripts/tiktok_ttstore_backup.sh backup --manual
```

Manual backup directories are named like:

```text
2026-05-04_153000_manual
```

Automatic backup directories are named like:

```text
2026-05-04_050000_auto
```

## List Backups

```bash
./scripts/tiktok_ttstore_backup.sh list
```

## Restore

Restore latest backup:

```bash
./scripts/tiktok_ttstore_backup.sh restore
```

Restore latest backup without confirmation:

```bash
./scripts/tiktok_ttstore_backup.sh restore --yes
```

Restore a specific backup:

```bash
./scripts/tiktok_ttstore_backup.sh restore --date 2026-05-04_153000_manual --yes
```

## Check Service Status

Validate the generated plist:

```bash
plutil -lint "$HOME/Library/LaunchAgents/com.tiktokbackupdays.ttstore.plist"
```

Check the LaunchAgent status:

```bash
launchctl print "gui/$(id -u)/com.tiktokbackupdays.ttstore"
```

## Stop And Remove Service

```bash
./scripts/uninstall_launch_agent.sh
```

Backups and logs are not deleted by uninstall.
