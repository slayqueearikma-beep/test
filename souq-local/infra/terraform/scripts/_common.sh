#!/usr/bin/env bash
# Shared helpers for subscription migration scripts (bash)

set -euo pipefail

terraform_dir() {
  cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd
}

sub_alias() {
  echo "sub${1}"
}

sub_tfvars() {
  echo "$(terraform_dir)/subscriptions/$(sub_alias "$1").tfvars"
}

sub_state() {
  echo "$(terraform_dir)/terraform-$(sub_alias "$1").tfstate"
}

sub_backup_dir() {
  echo "$(terraform_dir)/backups/$(sub_alias "$1")"
}

sub_dump() {
  echo "$(sub_backup_dir "$1")/margem.dump"
}

sub_blobs_dir() {
  echo "$(sub_backup_dir "$1")/blobs"
}

tf_var() {
  local file="$1" name="$2" default="${3:-}"
  if [[ ! -f "$file" ]]; then
    [[ -n "$default" ]] && { echo "$default"; return; }
    echo "Missing tfvars: $file" >&2; exit 1
  fi
  local val
  val=$(grep -E "^[[:space:]]*${name}[[:space:]]*=" "$file" | head -1 | sed -E 's/^[^=]*=[[:space:]]*"([^"]*)".*/\1/')
  if [[ -z "$val" ]]; then
    val=$(grep -E "^[[:space:]]*${name}[[:space:]]*=" "$file" | head -1 | awk -F= '{print $2}' | tr -d ' ')
  fi
  if [[ -z "$val" ]]; then
    [[ -n "$default" ]] && { echo "$default"; return; }
    echo "Variable $name not found in $file" >&2; exit 1
  fi
  echo "$val"
}

tf_output() {
  local state="$1" name="$2"
  (cd "$(terraform_dir)" && terraform output -state="$state" -raw "$name")
}

pg_connection_uri() {
  local sub="$1"
  local host login password
  host=$(tf_output "$(sub_state "$sub")" postgres_host)
  login=$(tf_var "$(sub_tfvars "$sub")" postgres_admin_login margemadmin)
  password=$(tf_var "$(sub_tfvars "$sub")" postgres_admin_password)
  echo "postgresql://${login}:${password}@${host}:5432/margem?sslmode=require"
}

run_pg_dump() {
  local uri="$1" outfile="$2"
  mkdir -p "$(dirname "$outfile")"
  if command -v pg_dump >/dev/null 2>&1; then
    pg_dump "$uri" -Fc -f "$outfile"
  elif command -v docker >/dev/null 2>&1; then
    local dir file
    dir=$(cd "$(dirname "$outfile")" && pwd)
    file=$(basename "$outfile")
    docker run --rm -v "${dir}:/backup" postgres:16 pg_dump "$uri" -Fc -f "/backup/$file"
  else
    echo "Install pg_dump or Docker to back up the database." >&2
    exit 1
  fi
}

run_pg_restore() {
  local uri="$1" dumpfile="$2"
  [[ -f "$dumpfile" ]] || { echo "Dump not found: $dumpfile" >&2; exit 1; }
  if command -v pg_restore >/dev/null 2>&1; then
    pg_restore --clean --if-exists --no-owner --no-acl -d "$uri" "$dumpfile" || [[ $? -le 1 ]]
  elif command -v docker >/dev/null 2>&1; then
    local dir file
    dir=$(cd "$(dirname "$dumpfile")" && pwd)
    file=$(basename "$dumpfile")
    docker run --rm -v "${dir}:/backup" postgres:16 \
      pg_restore --clean --if-exists --no-owner --no-acl -d "$uri" "/backup/$file" || [[ $? -le 1 ]]
  else
    echo "Install pg_restore or Docker to restore the database." >&2
    exit 1
  fi
}

backup_blobs() {
  local sub="$1"
  local storage rg conn dest
  storage=$(tf_output "$(sub_state "$sub")" storage_account_name)
  rg=$(tf_output "$(sub_state "$sub")" resource_group_name)
  dest=$(sub_blobs_dir "$sub")
  mkdir -p "$dest"
  conn=$(az storage account show-connection-string -g "$rg" -n "$storage" --query connectionString -o tsv)
  az storage blob download-batch --destination "$dest" --source margem-media --connection-string "$conn" --pattern "*"
}

restore_blobs_to() {
  local from="$1" to="$2"
  local src storage rg conn
  src=$(sub_blobs_dir "$from")
  if [[ ! -d "$src" ]] || [[ -z "$(ls -A "$src" 2>/dev/null || true)" ]]; then
    echo "No blob backup at $src — skipping media restore."
    return 0
  fi
  storage=$(tf_output "$(sub_state "$to")" storage_account_name)
  rg=$(tf_output "$(sub_state "$to")" resource_group_name)
  conn=$(az storage account show-connection-string -g "$rg" -n "$storage" --query connectionString -o tsv)
  az storage blob upload-batch --destination margem-media --source "$src" --connection-string "$conn" --overwrite
}

copy_jwt_secret() {
  local from="$1" to="$2"
  local from_file to_file jwt
  from_file=$(sub_tfvars "$from")
  to_file=$(sub_tfvars "$to")
  jwt=$(tf_var "$from_file" jwt_secret_key)
  if grep -qE '^[[:space:]]*jwt_secret_key[[:space:]]*=' "$to_file"; then
    sed -i.bak -E "s|^[[:space:]]*jwt_secret_key[[:space:]]*=.*|jwt_secret_key          = \"${jwt}\"|" "$to_file"
    rm -f "${to_file}.bak"
  else
    echo "jwt_secret_key          = \"${jwt}\"" >>"$to_file"
  fi
  echo "Copied jwt_secret_key from sub${from} → sub${to}."
}
