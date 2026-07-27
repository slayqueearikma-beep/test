#!/usr/bin/env bash
# Backup MarGem Postgres and local media from docker-compose.home.yml.
# Usage: ./scripts/backup_home_db.sh [output-dir]

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${1:-$ROOT/backups}"
RETENTION_DAYS="${BACKUP_RETENTION_DAYS:-14}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$OUT_DIR"
FILE="$OUT_DIR/margem-$STAMP.sql.gz"
MEDIA_FILE="$OUT_DIR/margem-media-$STAMP.tar.gz"

if ! docker ps --format '{{.Names}}' | grep -qx 'margem-home-db'; then
  echo "Container margem-home-db is not running." >&2
  exit 1
fi

echo "Writing $FILE ..."
docker exec margem-home-db pg_dump -U margemadmin -d margem | gzip > "$FILE"

# Local media is a named Docker volume. Back it up alongside the database so
# restored listings do not point at missing images.
if docker volume inspect margem_home_media >/dev/null 2>&1; then
  echo "Writing $MEDIA_FILE ..."
  docker run --rm \
    -v margem_home_media:/source:ro \
    -v "$OUT_DIR":/backup \
    alpine:3.20 \
    tar -C /source -czf "/backup/$(basename "$MEDIA_FILE")" .
else
  echo "Media volume margem_home_media not found; database backup completed." >&2
fi

echo "Done. Copy both database and media archives off-site for disaster recovery."
ls -lh "$FILE" "$MEDIA_FILE" 2>/dev/null || ls -lh "$FILE"

if [[ -n "${RCLONE_REMOTE:-}" ]]; then
  command -v rclone >/dev/null 2>&1 || {
    echo "RCLONE_REMOTE is set but rclone is not installed." >&2
    exit 1
  }
  rclone copy "$OUT_DIR" "$RCLONE_REMOTE" --include 'margem*.gz' --immutable
  echo "Copied archives to $RCLONE_REMOTE."
fi

find "$OUT_DIR" -type f \( -name 'margem-*.sql.gz' -o -name 'margem-media-*.tar.gz' \) \
  -mtime "+$RETENTION_DAYS" -delete
