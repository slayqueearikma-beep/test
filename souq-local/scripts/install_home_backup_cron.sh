#!/usr/bin/env bash
# Install a daily local backup job for a MarGem home server.
# Optionally set RCLONE_REMOTE (for example "b2:margem-backups") before running
# to copy archives off-site after each successful backup.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CRON_FILE="$HOME/.config/cron.d/margem-home-backup"
LOG_FILE="$ROOT/backups/backup.log"

mkdir -p "$(dirname "$CRON_FILE")" "$ROOT/backups"
cat > "$CRON_FILE" <<EOF
SHELL=/bin/bash
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
17 2 * * * cd "$ROOT" && RCLONE_REMOTE="${RCLONE_REMOTE:-}" ./scripts/backup_home_db.sh >> "$LOG_FILE" 2>&1
EOF

crontab "$CRON_FILE"
echo "Installed daily MarGem backup at 02:17 local time."
if [[ -n "${RCLONE_REMOTE:-}" ]]; then
  echo "Off-site copy enabled through rclone remote: $RCLONE_REMOTE"
else
  echo "Off-site copy is not configured. Set RCLONE_REMOTE and install/configure rclone, then run again."
fi
