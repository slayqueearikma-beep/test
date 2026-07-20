#!/usr/bin/env bash
# Tear down MarGem on subscription N when credits/budget are exhausted.
# Usage: ./scripts/destroy-subscription.sh 1

set -euo pipefail

SUB="${1:?Usage: $0 <number> e.g. 1 for sub1}"
ALIAS="sub${SUB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TFVARS="$TERRAFORM_DIR/subscriptions/${ALIAS}.tfvars"
STATE="$TERRAFORM_DIR/terraform-${ALIAS}.tfstate"

[[ -f "$TFVARS" ]] || { echo "Missing $TFVARS" >&2; exit 1; }
[[ -f "$STATE" ]] || { echo "No state $STATE — nothing to destroy for $ALIAS" >&2; exit 1; }

echo ""
echo "This will DESTROY all MarGem resources in $ALIAS."
echo "Back up PostgreSQL first if needed (see subscriptions/MONTHLY-ROTATION.md)."
echo ""
read -r -p "Type $ALIAS to confirm destroy: " confirm
[[ "$confirm" == "$ALIAS" ]] || { echo "Cancelled."; exit 0; }

cd "$TERRAFORM_DIR"
terraform destroy -state="$STATE" -var-file="subscriptions/${ALIAS}.tfvars"

echo ""
echo "Destroyed $ALIAS. Deploy next month with: ./scripts/switch-subscription.sh $((SUB + 1))"
