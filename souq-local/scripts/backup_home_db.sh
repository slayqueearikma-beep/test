#!/usr/bin/env bash
# Backup MarGem Postgres from docker-compose.home.yml
# Usage: ./scripts/backup_home_db.sh [output-dir]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT/backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/margem-$STAMP.sql.gz"

if ! docker ps --format '{{.Names}}' | grep -qx 'margem-home-db'; then
  echo "Container margem-home-db is not running." >&2
  exit 1
fi

echo "Writing $FILE ..."
docker exec margem-home-db pg_dump -U margemadmin -d margem | gzip > "$FILE"
echo "Done. Keep off-site copies of backups for disaster recovery."
ls -lh "$FILE"
