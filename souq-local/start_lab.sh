#!/usr/bin/env bash
# MarGem local lab — start backend (Docker) + Flutter app
# Usage: ./start_lab.sh
#        ./start_lab.sh --no-flutter

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOBILE="$ROOT/mobile"
LAB_DIR="$ROOT/.lab"
NO_FLUTTER=false
DEVICE_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-flutter) NO_FLUTTER=true; shift ;;
    -d) DEVICE_ID="$2"; shift 2 ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

mkdir -p "$LAB_DIR"

get_lan_ip() {
  hostname -I 2>/dev/null | awk '{print $1}' || echo "127.0.0.1"
}

echo ""
echo "=== MarGem Lab — starting ==="
echo ""

command -v docker >/dev/null || { echo "Docker not found."; exit 1; }
docker info >/dev/null 2>&1 || { echo "Docker is not running."; exit 1; }

cd "$ROOT"
echo "[1/3] Starting Postgres + API (docker compose)..."
docker compose up -d --build

echo "[2/3] Waiting for API health..."
ready=false
for _ in $(seq 1 45); do
  if curl -sf "http://localhost:8000/health" >/dev/null 2>&1; then
    ready=true
    break
  fi
  sleep 2
done

if [[ "$ready" == true ]]; then
  echo "      API ready at http://localhost:8000"
else
  echo "      WARNING: API health check timed out. Try: docker compose logs api"
fi

LAN_IP="$(get_lan_ip)"
API_URL="http://${LAN_IP}:8000"
echo "$API_URL" >"$LAB_DIR/api_url.txt"

echo ""
echo "  Emulator API:   http://10.0.2.2:8000"
echo "  Physical phone: $API_URL"
echo "  API docs:       http://localhost:8000/docs"
echo ""

if [[ "$NO_FLUTTER" == true ]]; then
  echo "Backend only. Stop with: ./stop_lab.sh"
  exit 0
fi

if ! command -v flutter >/dev/null; then
  echo "Flutter not in PATH. Run manually:"
  echo "  cd mobile && flutter run --dart-define=API_BASE_URL=$API_URL"
  exit 0
fi

echo "[3/3] Launching Flutter..."
cd "$MOBILE"
FLUTTER_ARGS=(run --dart-define="API_BASE_URL=$API_URL")
[[ -n "$DEVICE_ID" ]] && FLUTTER_ARGS+=(-d "$DEVICE_ID")

if command -v gnome-terminal >/dev/null; then
  gnome-terminal -- bash -c "cd '$MOBILE'; flutter ${FLUTTER_ARGS[*]}; exec bash"
elif command -v osascript >/dev/null; then
  osascript -e "tell app \"Terminal\" to do script \"cd '$MOBILE' && flutter ${FLUTTER_ARGS[*]}\""
else
  flutter "${FLUTTER_ARGS[@]}"
fi

date -Iseconds >"$LAB_DIR/started_at.txt"
echo ""
echo "Lab started. Stop with: ./stop_lab.sh"
echo ""
