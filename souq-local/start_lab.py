#!/usr/bin/env python3
"""MarGem local lab — cross-platform start script.

Usage:
  python start_lab.py
  python start_lab.py --no-flutter
  python start_lab.py -d <device_id>
"""

from __future__ import annotations

import argparse
import platform
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MOBILE = ROOT / "mobile"
LAB_DIR = ROOT / ".lab"


def run(cmd: list[str], **kwargs) -> subprocess.CompletedProcess:
    print(f"  $ {' '.join(cmd)}")
    return subprocess.run(cmd, cwd=ROOT, check=False, **kwargs)


def lan_ip() -> str:
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
            s.connect(("8.8.8.8", 80))
            return s.getsockname()[0]
    except OSError:
        return "127.0.0.1"


def wait_for_health(seconds: int = 90) -> bool:
    url = "http://localhost:8000/health"
    deadline = time.time() + seconds
    while time.time() < deadline:
        try:
            with urllib.request.urlopen(url, timeout=3) as resp:
                if resp.status == 200:
                    return True
        except (urllib.error.URLError, TimeoutError):
            time.sleep(2)
    return False


def start_flutter(api_url: str, device_id: str | None) -> None:
    flutter = "flutter"
    args = [flutter, "run", f"--dart-define=API_BASE_URL={api_url}"]
    if device_id:
        args.extend(["-d", device_id])

    system = platform.system()
    mobile = str(MOBILE)
    if system == "Windows":
        cmd = " ".join(args)
        subprocess.Popen(
            ["powershell", "-NoExit", "-Command", f"cd '{mobile}'; {cmd}"],
            cwd=mobile,
        )
    else:
        subprocess.Popen(args, cwd=mobile)


def main() -> int:
    parser = argparse.ArgumentParser(description="Start MarGem local lab")
    parser.add_argument("--no-flutter", action="store_true", help="Start Docker backend only")
    parser.add_argument("-d", "--device", default="", help="Flutter device id")
    args = parser.parse_args()

    LAB_DIR.mkdir(exist_ok=True)

    print("\n=== MarGem Lab — starting ===\n")

    if run(["docker", "info"], capture_output=True).returncode != 0:
        print("ERROR: Docker is not running.", file=sys.stderr)
        return 1

    print("[1/3] Starting Postgres + API...")
    if run(["docker", "compose", "up", "-d", "--build"]).returncode != 0:
        return 1

    print("[2/3] Waiting for API health...")
    if wait_for_health():
        print("      API ready at http://localhost:8000")
    else:
        print("      WARNING: health check timed out")

    ip = lan_ip()
    api_url = f"http://{ip}:8000"
    (LAB_DIR / "api_url.txt").write_text(api_url, encoding="utf-8")

    print(f"\n  Emulator API:   http://10.0.2.2:8000")
    print(f"  Physical phone: {api_url}")
    print(f"  API docs:       http://localhost:8000/docs\n")

    if args.no_flutter:
        print("Backend only. Stop with: python stop_lab.py")
        return 0

    print("[3/3] Launching Flutter...")
    start_flutter(api_url, args.device or None)
    print("\nLab started. Stop with: python stop_lab.py\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
