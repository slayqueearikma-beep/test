#!/usr/bin/env bash
# Pair and connect an Android phone for wireless Flutter debugging (Android 11+).
# Phone and this server must be on the same Wi-Fi.
#
# Usage:
#   ./setup_wireless_adb.sh pair 192.168.11.107:37123 123456
#   ./setup_wireless_adb.sh connect 192.168.11.107:41293
#   ./setup_wireless_adb.sh install-adb    # install latest Google platform-tools
#   ./setup_wireless_adb.sh status
#   ./setup_wireless_adb.sh disconnect

set -euo pipefail

# Prefer Google platform-tools over old apt adb
for dir in "$HOME/Android/platform-tools" "$HOME/Android/Sdk/platform-tools"; do
  if [[ -d "$dir" ]]; then
    export PATH="$dir:$PATH"
  fi
done

usage() {
  echo "Usage:"
  echo "  $0 install-adb                           # latest adb (recommended)"
  echo "  $0 pair <ip:pairing_port> <6-digit-code> # first time only"
  echo "  $0 connect <ip:debug_port>               # after pair / reconnect"
  echo "  $0 status"
  echo "  $0 disconnect"
  echo ""
  echo "On phone: Settings → Developer options → Wireless debugging"
  echo "  1. Tap 'Pair device with pairing code' (code expires in ~60s)"
  echo "  2. Use pair command immediately with that IP:port + code"
  echo "  3. On main screen, use 'IP address & port' for connect"
  exit 1
}

adb_version_ok() {
  command -v adb >/dev/null 2>&1 || return 1

  # "Version 34.0.5-..." line from platform-tools
  local pt_ver
  pt_ver="$(adb version 2>/dev/null | awk '/^Version / {print $2}' | cut -d- -f1)"
  if [[ -n "$pt_ver" ]]; then
    local major minor
    major="${pt_ver%%.*}"
    minor="$(echo "$pt_ver" | cut -d. -f2)"
    [[ "$major" -gt 31 ]] && return 0
    [[ "$major" -eq 31 && "$minor" -ge 0 ]] && return 0
  fi

  # "Android Debug Bridge version 1.0.41" — wireless needs 1.0.39+
  local client_patch
  client_patch="$(adb version 2>/dev/null | sed -n 's/.*version 1\.0\.\([0-9]*\).*/\1/p' | head -n1)"
  [[ -n "$client_patch" && "$client_patch" -ge 39 ]] && return 0

  return 1
}

install_platform_tools() {
  echo "Installing latest Android platform-tools to ~/Android/platform-tools ..."
  mkdir -p "$HOME/Android"
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN
  curl -fsSL -o "$tmp/platform-tools.zip" "https://dl.google.com/android/repository/platform-tools-latest-linux.zip"
  unzip -q "$tmp/platform-tools.zip" -d "$tmp"
  rm -rf "$HOME/Android/platform-tools"
  mv "$tmp/platform-tools" "$HOME/Android/platform-tools"
  export PATH="$HOME/Android/platform-tools:$PATH"
  if ! grep -q 'Android/platform-tools' "$HOME/.bashrc" 2>/dev/null; then
    echo 'export PATH="$HOME/Android/platform-tools:$PATH"' >> "$HOME/.bashrc"
  fi
  echo "Installed: $(adb version | head -n1)"
  echo "Run: source ~/.bashrc"
}

require_adb() {
  if ! command -v adb >/dev/null 2>&1; then
    echo "adb not found. Run: $0 install-adb" >&2
    exit 1
  fi
}

require_adb_pairing() {
  require_adb
  if ! adb_version_ok; then
    echo "adb is too old for wireless pairing." >&2
    adb version | head -n2 >&2
    echo "Run: $0 install-adb" >&2
    exit 1
  fi
}

pair_device() {
  local target="$1"
  local code="$2"
  echo "Pairing with $target (code expires quickly — regenerate on phone if this fails) ..."
  adb kill-server
  sleep 1
  adb start-server
  if adb pair "$target" "$code"; then
    return 0
  fi
  echo "Retrying with interactive code input ..."
  printf '%s\n' "$code" | adb pair "$target"
}

cmd="${1:-}"
shift || true

case "$cmd" in
  install-adb)
    install_platform_tools
    ;;
  pair)
    [[ $# -eq 2 ]] || usage
    require_adb_pairing
    pair_device "$1" "$2"
    echo ""
    echo "Pair OK. Now connect using the DEBUG port from the phone main screen:"
    echo "  $0 connect <ip:debug_port>"
    ;;
  connect)
    [[ $# -eq 1 ]] || usage
    require_adb
    target="$1"
    echo "Connecting to $target ..."
    adb kill-server
    sleep 1
    adb start-server
    adb connect "$target"
    echo ""
    adb devices -l
    ;;
  status)
    require_adb
    adb devices -l
    if command -v flutter >/dev/null 2>&1; then
      echo ""
      flutter devices
    fi
    ;;
  disconnect)
    require_adb
    adb disconnect
    adb devices -l
    ;;
  *)
    usage
    ;;
esac
