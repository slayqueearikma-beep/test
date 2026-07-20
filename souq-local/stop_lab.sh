#!/usr/bin/env bash
# MarGem local lab — stop backend + Flutter
# Usage: ./stop_lab.sh

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo ""
echo "=== MarGem Lab — stopping ==="
echo ""

cd "$ROOT"
if command -v docker >/dev/null; then
  echo "[1/2] Stopping Docker containers..."
  docker compose down
else
  echo "Docker not found — skipping."
fi

echo "[2/2] Stopping Flutter processes for this project..."
pkill -f "flutter.*${ROOT}/mobile" 2>/dev/null || true
pkill -f "dart.*${ROOT}/mobile" 2>/dev/null || true

rm -rf "$ROOT/.lab" 2>/dev/null || true

echo ""
echo "Lab stopped."
echo ""
