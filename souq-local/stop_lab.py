#!/usr/bin/env python3
"""MarGem local lab — cross-platform stop script.

Usage:
  python stop_lab.py
"""

from __future__ import annotations

import platform
import shutil
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
LAB_DIR = ROOT / ".lab"


def main() -> int:
    print("\n=== MarGem Lab — stopping ===\n")

    if shutil.which("docker"):
        print("[1/2] Stopping Docker containers...")
        subprocess.run(["docker", "compose", "down"], cwd=ROOT, check=False)
    else:
        print("Docker not found — skipping.")

    print("[2/2] Stopping Flutter processes...")
    mobile = str(ROOT / "mobile").replace("\\", "/")
    if platform.system() == "Windows":
        subprocess.run(
            [
                "powershell",
                "-Command",
                (
                    "Get-CimInstance Win32_Process | "
                    "Where-Object { $_.Name -match '^(dart|flutter)\\.exe$' -and $_.CommandLine -match 'souq-local.*mobile' } | "
                    "ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }"
                ),
            ],
            check=False,
        )
    else:
        subprocess.run(["pkill", "-f", f"flutter.*{mobile}"], check=False)
        subprocess.run(["pkill", "-f", f"dart.*{mobile}"], check=False)

    if LAB_DIR.exists():
        shutil.rmtree(LAB_DIR, ignore_errors=True)

    print("\nLab stopped.\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
