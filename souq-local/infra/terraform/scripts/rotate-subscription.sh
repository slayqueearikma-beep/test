#!/usr/bin/env bash
# Rotate to the next subscription AND keep all data (DB + images).
# Usage: ./scripts/rotate-subscription.sh 1 2

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=_common.sh
source "$SCRIPT_DIR/_common.sh"

FROM_SUB="${1:?Usage: $0 <from-sub> <to-sub>}"
TO_SUB="${2:?Usage: $0 <from-sub> <to-sub>}"
SKIP_DESTROY="${SKIP_DESTROY:-}"

[[ "$TO_SUB" -gt "$FROM_SUB" ]] || { echo "to-sub must be greater than from-sub" >&2; exit 1; }

TO_TFVARS="$(sub_tfvars "$TO_SUB")"
TO_EXAMPLE="$(terraform_dir)/subscriptions/$(sub_alias "$TO_SUB").tfvars.example"

if [[ ! -f "$TO_TFVARS" ]]; then
  if [[ -f "$TO_EXAMPLE" ]]; then
    cp "$TO_EXAMPLE" "$TO_TFVARS"
    copy_jwt_secret "$FROM_SUB" "$TO_SUB"
    echo "Created $TO_TFVARS — edit subscription_id and postgres password, then re-run."
    exit 1
  fi
  echo "Missing $TO_TFVARS" >&2
  exit 1
fi

echo ""
echo "=========================================="
echo " MarGem subscription rotation with data"
echo " sub${FROM_SUB}  -->  sub${TO_SUB}"
echo "=========================================="
echo ""

echo "[1/4] Backing up sub${FROM_SUB}..."
"$SCRIPT_DIR/backup-subscription-data.sh" "$FROM_SUB"

echo ""
echo "[2/4] Deploying sub${TO_SUB}..."
"$SCRIPT_DIR/switch-subscription.sh" "$TO_SUB"

echo ""
echo "[3/4] Restoring data onto sub${TO_SUB}..."
"$SCRIPT_DIR/restore-subscription-data.sh" "$TO_SUB" "$FROM_SUB"

echo ""
echo "[4/4] Old subscription cleanup"
if [[ "$SKIP_DESTROY" == "1" ]]; then
  echo "Skipped destroy. Run: ./scripts/destroy-subscription.sh $FROM_SUB"
else
  read -r -p "Destroy sub${FROM_SUB} now to stop billing? (y/N): " confirm
  if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
    "$SCRIPT_DIR/destroy-subscription.sh" "$FROM_SUB"
  else
    echo "Left sub${FROM_SUB} running — destroy it soon."
  fi
fi

API=$(tf_output "$(sub_state "$TO_SUB")" api_url)
echo ""
echo "=== Done — same users/sellers/data on sub${TO_SUB} ==="
echo "API URL: $API"
