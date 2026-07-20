#!/usr/bin/env bash
# Deploy (or update) MarGem on subscription N for monthly credit rotation.
# Usage: ./scripts/switch-subscription.sh 1

set -euo pipefail

SUB="${1:?Usage: $0 <number> e.g. 1 for sub1}"
ALIAS="sub${SUB}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
TFVARS="$TERRAFORM_DIR/subscriptions/${ALIAS}.tfvars"
EXAMPLE="$TERRAFORM_DIR/subscriptions/${ALIAS}.tfvars.example"
STATE="$TERRAFORM_DIR/terraform-${ALIAS}.tfstate"

if [[ ! -f "$TFVARS" ]]; then
  if [[ -f "$EXAMPLE" ]]; then
    cp "$EXAMPLE" "$TFVARS"
    echo ""
    echo "Created $TFVARS"
    echo "Edit subscription_id and secrets, then run: $0 $SUB"
    exit 1
  fi
  echo "Missing $TFVARS — copy an example from subscriptions/ and edit it." >&2
  exit 1
fi

cd "$TERRAFORM_DIR"
[[ -d .terraform ]] || terraform init

echo ""
echo "Deploying to subscription alias '$ALIAS' (state: terraform-${ALIAS}.tfstate)"
echo ""

terraform apply -state="$STATE" -var-file="subscriptions/${ALIAS}.tfvars"

echo ""
echo "=== Active API URL ==="
terraform output -state="$STATE" -raw api_url
echo ""
echo "Rebuild mobile with the API URL above."
