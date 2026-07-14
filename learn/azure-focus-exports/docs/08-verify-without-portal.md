# Verify exports without the Azure Portal

Use **Terraform** to create exports, then **CLI** to list them and check blob files. No portal needed.

---

## Step 1 — Deploy the lab with Terraform

```powershell
cd learn\azure-focus-exports\lab\terraform
copy terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars — set a unique storage_account_name

az login
terraform init
terraform apply
```

Type `yes` when prompted.

---

## Step 2 — See exports from Terraform (right after apply)

```powershell
terraform output
```

Shows storage account, container, and export folder paths.

**FOCUS export details:**

```powershell
terraform state show azapi_resource.focus_export
```

Look for `schedule.status` = `Active`, `definition.type` = `FocusCost`, `format` = `Parquet`.

**ActualCost export details:**

```powershell
terraform state show azurerm_resource_group_cost_management_export.actual_cost
```

---

## Step 3 — List exports with Azure CLI (2025 API)

> `az costmanagement export list` uses an **old API** and often **does not show** FOCUS exports. Use `az rest` instead.

```powershell
$sub = az account show --query id -o tsv

# List all exports at subscription scope (includes FOCUS)
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/$sub/providers/Microsoft.CostManagement/exports?api-version=2025-03-01"
```

**FOCUS export run history:**

```powershell
$sub = az account show --query id -o tsv
$name = "lab-focus-daily"   # or your focus_export_name from terraform.tfvars

az rest --method GET `
  --uri "https://management.azure.com/subscriptions/$sub/providers/Microsoft.CostManagement/exports/$name/runHistory?api-version=2025-03-01"
```

Status values: `Completed`, `InProgress`, `Failed`.

**ActualCost export at resource group scope:**

```powershell
$rg = terraform output -raw resource_group_name
az rest --method GET `
  --uri "https://management.azure.com/subscriptions/$sub/resourceGroups/$rg/providers/Microsoft.CostManagement/exports?api-version=2025-03-01"
```

---

## Step 4 — See export **files** in storage (proof data landed)

```powershell
$account = terraform output -raw storage_account_name
$container = terraform output -raw container_name

az storage blob list `
  --account-name $account `
  --container-name $container `
  --prefix focus-parquet/ `
  --auth-mode login `
  -o table
```

If you see folders and `.parquet` files (and `_manifest.json`), the export ran successfully.

Download a manifest:

```powershell
az storage blob download `
  --account-name $account `
  --container-name $container `
  --name "focus-parquet/<run-folder>/_manifest.json" `
  --file manifest.json `
  --auth-mode login
```

---

## Quick verify script

From repo root:

```powershell
.\learn\azure-focus-exports\scripts\verify-exports.ps1
```

Runs the commands above using Terraform outputs from the lab folder.

---

## Timing

- First export run can take **up to 24 hours**
- New subscriptions: Cost Management may need **up to 48 hours**
- `runHistory` empty or `InProgress` = wait and check again later

---

## Troubleshooting

| Symptom | What to check |
|---------|----------------|
| `terraform apply` fails on FOCUS | Subscription type may not support FOCUS — see [02-prerequisites-and-scopes.md](./02-prerequisites-and-scopes.md) |
| Export exists but no blobs | Run history; wait for next daily run |
| `az rest` 403 | Need Cost Management Reader + Storage Blob Data Reader |
| `az costmanagement export list` empty | Expected for FOCUS — use `az rest` with `api-version=2025-03-01` |
