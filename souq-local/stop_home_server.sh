#!/usr/bin/env bash
# Stop MarGem home server containers (Azure blob stays active).
# Usage: ./stop_home_server.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT/.env.home"
COMPOSE_FILE="$ROOT/docker-compose.home.yml"

echo ""
echo "Stopping home server containers..."

if [[ -f "$ENV_FILE" ]]; then
  docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" down
else
  docker compose -f "$COMPOSE_FILE" down
fi

echo "Stopped. Azure blob storage is still active (minimal cost)."
echo ""
