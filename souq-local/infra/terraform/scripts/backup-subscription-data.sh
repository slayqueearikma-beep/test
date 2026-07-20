#!/usr/bin/env bash
# Back up PostgreSQL + blob media from a subscription.
# Usage: ./scripts/backup-subscription-data.sh 1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

SUB="${1:?Usage: $0 <sub-number>}"
STATE="$(sub_state "$SUB")"
DUMP="$(sub_dump "$SUB")"
BLOBS="$(sub_blobs_dir "$SUB")"

[[ -f "$STATE" ]] || { echo "No deployment for sub${SUB}. Deploy with switch-subscription.sh first." >&2; exit 1; }

echo ""
echo "=== Backing up sub${SUB} data ==="
echo "  Database → $DUMP"
echo "  Blobs    → $BLOBS"
echo ""

run_pg_dump "$(pg_connection_uri "$SUB")" "$DUMP"
echo "Database backup complete."

backup_blobs "$SUB"
echo "Blob backup complete."
echo ""
echo "Backup saved under: $(sub_backup_dir "$SUB")"
