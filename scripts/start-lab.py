#!/usr/bin/env python3
"""Start the Azure VM that hosts the Minecraft lab."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_TERRAFORM_DIR = REPO_ROOT / "terraform"


def run(command: list[str], *, cwd: Path | None = None, capture: bool = False) -> str:
    try:
        completed = subprocess.run(
            command,
            cwd=str(cwd) if cwd else None,
            check=True,
            text=True,
            stdout=subprocess.PIPE if capture else None,
            stderr=subprocess.PIPE if capture else None,
        )
    except FileNotFoundError:
        print(f"Missing command: {command[0]}", file=sys.stderr)
        sys.exit(1)
    except subprocess.CalledProcessError as exc:
        if capture and exc.stderr:
            print(exc.stderr.strip(), file=sys.stderr)
        print(f"Command failed: {' '.join(command)}", file=sys.stderr)
        sys.exit(exc.returncode)

    return completed.stdout.strip() if capture and completed.stdout else ""


def terraform_output(terraform_dir: Path, name: str) -> str:
    return run(["terraform", "output", "-raw", name], cwd=terraform_dir, capture=True)


def ensure_azure_login() -> None:
    run(["az", "account", "show"], capture=True)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Start the Azure Minecraft lab VM.")
    parser.add_argument(
        "--terraform-dir",
        default=str(DEFAULT_TERRAFORM_DIR),
        help="Path to the Terraform directory. Defaults to ./terraform.",
    )
    parser.add_argument("--resource-group", help="Override resource group name.")
    parser.add_argument("--vm-name", help="Override VM name.")
    parser.add_argument(
        "--no-wait",
        action="store_true",
        help="Return immediately after submitting the Azure start request.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    terraform_dir = Path(args.terraform_dir).resolve()

    ensure_azure_login()

    resource_group = args.resource_group or terraform_output(terraform_dir, "resource_group_name")
    vm_name = args.vm_name or terraform_output(terraform_dir, "virtual_machine_name")

    command = ["az", "vm", "start", "--resource-group", resource_group, "--name", vm_name]
    if args.no_wait:
        command.append("--no-wait")

    print(f"Starting VM {resource_group}/{vm_name}...")
    run(command)

    if args.no_wait:
        print("Start request submitted.")
        return 0

    print("VM started.")
    minecraft_address = terraform_output(terraform_dir, "minecraft_server_address")
    print(f"Minecraft address: {minecraft_address}")
    print("The Minecraft systemd service starts automatically when the VM boots.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
