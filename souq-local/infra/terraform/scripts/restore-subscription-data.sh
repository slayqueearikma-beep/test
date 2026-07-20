#!/usr/bin/env bash
# Restore PostgreSQL + blob media onto a newly deployed subscription.
# Usage: ./scripts/restore-subscription-data.sh 2 1

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

TO_SUB="${1:?Usage: $0 <to-sub> <from-sub>}"
FROM_SUB="${2:?Usage: $0 <to-sub> <from-sub>}"

STATE="$(sub_state "$TO_SUB")"
DUMP="$(sub_dump "$FROM_SUB")"

[[ -f "$STATE" ]] || { echo "Deploy sub${TO_SUB} first." >&2; exit 1; }
[[ -f "$DUMP" ]] || { echo "No dump at $DUMP — run backup-subscription-data.sh $FROM_SUB first." >&2; exit 1; }

echo ""
echo "=== Restoring sub${FROM_SUB} data onto sub${TO_SUB} ==="
echo ""

run_pg_restore "$(pg_connection_uri "$TO_SUB")" "$DUMP"
echo "Database restore complete."

restore_blobs_to "$FROM_SUB" "$TO_SUB"
echo "Blob restore complete."

API=$(tf_output "$(sub_state "$TO_SUB")" api_url)
echo ""
echo "Data migration complete. Verify: curl ${API}/health"
