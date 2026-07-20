#!/usr/bin/env bash
# Start everything for MarGem home server: Docker (API + Postgres) + Flutter app.
# Usage:
#   ./start_home_server.sh           # API + Flutter (if phone connected)
#   ./start_home_server.sh --build   # Rebuild API image first
#   ./start_home_server.sh --api-only # Skip Flutter

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$ROOT/.env.home"
ENV_EXAMPLE="$ROOT/env.home.example"
COMPOSE_FILE="$ROOT/docker-compose.home.yml"
RUN_FLUTTER=true
DOCKER_BUILD=""

for arg in "$@"; do
  case "$arg" in
    --api-only) RUN_FLUTTER=false ;;
    --flutter) RUN_FLUTTER=true ;;
    --build) DOCKER_BUILD="--build" ;;
    -h|--help)
      echo "Usage: $0 [--build] [--api-only]"
      echo "  (default)  Start Docker API + Postgres, then Flutter if a phone is connected"
      echo "  --build    Rebuild Docker images"
      echo "  --api-only Docker only, skip Flutter"
      exit 0
      ;;
    *)
      echo "Unknown option: $arg" >&2
      exit 1
      ;;
  esac
done

get_lan_ip() {
  hostname -I 2>/dev/null | tr ' ' '\n' | grep -E '^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.' | grep -v '^172\.17\.' | head -n1
}

has_phone_device() {
  command -v adb >/dev/null 2>&1 || return 1
  adb devices 2>/dev/null | awk 'NR>1 && $2=="device" {found=1} END {exit !found}'
}

ensure_docker_running() {
  if docker info >/dev/null 2>&1; then
    return 0
  fi
  echo "Docker not responding — trying to start it..."
  if command -v systemctl >/dev/null 2>&1; then
    sudo systemctl start docker 2>/dev/null || true
    sleep 2
  fi
  docker info >/dev/null 2>&1
}

echo ""
echo "=== MarGem Home Server — start all ==="
echo ""

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker not found. Install:" >&2
  echo "  sudo apt install docker.io docker-compose-plugin" >&2
  exit 1
fi

if ! ensure_docker_running; then
  echo "Docker is not running. Try:" >&2
  echo "  sudo systemctl start docker" >&2
  echo "  sudo usermod -aG docker \$USER   # then log out and back in" >&2
  exit 1
fi

if [[ ! -f "$ENV_FILE" ]]; then
  if [[ -f "$ENV_EXAMPLE" ]]; then
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    echo "Created .env.home"
    echo "Edit passwords, Azure connection string, and ALLOWED_HOSTS, then re-run."
    exit 1
  fi
  echo "Missing .env.home — copy env.home.example and configure it first." >&2
  exit 1
fi

LAN_IP="$(get_lan_ip || true)"
LAN_IP="${LAN_IP:-127.0.0.1}"
API_PORT="$(grep -E '^API_PORT=' "$ENV_FILE" | tail -n1 | cut -d= -f2- || true)"
API_PORT="${API_PORT:-8000}"
API_URL="http://${LAN_IP}:${API_PORT}"

check_api_health() {
  local port="$1"
  local lan_ip="$2"
  # Prefer LAN IP — matches typical ALLOWED_HOSTS on home servers.
  if [[ -n "$lan_ip" && "$lan_ip" != "127.0.0.1" ]]; then
    curl -fsS "http://${lan_ip}:${port}/health" >/dev/null 2>&1 && return 0
  fi
  # Fallback when localhost is in ALLOWED_HOSTS.
  curl -fsS -H "Host: localhost" "http://127.0.0.1:${port}/health" >/dev/null 2>&1 && return 0
  curl -fsS -H "Host: 127.0.0.1" "http://127.0.0.1:${port}/health" >/dev/null 2>&1 && return 0
  return 1
}

echo "[1/3] Starting Postgres + API (Docker)..."
docker compose -f "$COMPOSE_FILE" --env-file "$ENV_FILE" up -d $DOCKER_BUILD

echo "[2/3] Waiting for API health..."
ready=false
for _ in $(seq 1 30); do
  if check_api_health "$API_PORT" "$LAN_IP"; then
    ready=true
    break
  fi
  sleep 2
done

echo ""
if [[ "$ready" == true ]]; then
  echo "=== API running ==="
else
  echo "API not ready yet. Check:"
  echo "  docker compose -f docker-compose.home.yml --env-file .env.home logs api"
  echo ""
  echo "If logs show 400 on /health, add localhost to ALLOWED_HOSTS in .env.home:"
  echo '  ALLOWED_HOSTS=["localhost","127.0.0.1","192.168.11.103","192.168.11.103:8000"]'
  exit 1
fi

echo ""
echo "  Same Wi-Fi:   $API_URL"
echo "  This machine: http://localhost:${API_PORT}"
echo "  Health:       http://localhost:${API_PORT}/health"
echo "  Images:       Azure Blob (cloud)"
echo "  Stop all:     ./stop_home_server.sh"
echo ""

if [[ "$RUN_FLUTTER" != true ]]; then
  echo "API-only mode. To run the app later:"
  echo "  cd mobile && flutter run --dart-define=API_BASE_URL=$API_URL"
  exit 0
fi

echo "[3/3] Starting Flutter app..."

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter not installed — API is up, app not started."
  echo ""
  echo "Install Flutter, then re-run ./start_home_server.sh"
  echo "Or run manually: cd mobile && flutter run --dart-define=API_BASE_URL=$API_URL"
  exit 0
fi

if ! has_phone_device; then
  echo "No phone detected (USB or wireless) — API is up, app not started."
  echo ""
  echo "USB: plug in phone with USB debugging on, then re-run ./start_home_server.sh"
  echo "Wi-Fi: ./setup_wireless_adb.sh pair <ip:port> <code>"
  echo "       ./setup_wireless_adb.sh connect <ip:port>"
  echo ""
  echo "Or install the last APK if you already built one."
  exit 0
fi

cd "$ROOT/mobile"
flutter pub get

echo ""
echo "Launching on phone (Ctrl+C stops the app; API keeps running)..."
echo ""
exec flutter run --dart-define=API_BASE_URL="$API_URL"
