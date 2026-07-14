# Terraform lab — FOCUS export (standalone)

Minimal infrastructure to practice the [Microsoft improved exports tutorial](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports) without deploying the full SCAD platform.

## What this creates

| Resource | Purpose |
|----------|---------|
| Resource group | Isolated lab scope |
| Storage account + container | Export destination |
| `azurerm_resource_group_cost_management_export` | ActualCost (CSV, daily) |
| `azapi_resource` FOCUS export | FOCUS 1.0 Parquet, daily |

## Prerequisites

- Azure subscription with **Cost Management + Billing** reader (or higher) on the subscription
- Terraform >= 1.5
- `az login` completed
- FOCUS export may fail on unsupported subscription types (e.g. some MOSP / management group scopes) — see [docs/02-prerequisites-and-scopes.md](../../docs/02-prerequisites-and-scopes.md)

## Deploy

```bash
cd learn/azure-focus-exports/lab/terraform
cp terraform.tfvars.example terraform.tfvars
# Edit storage_account_name to something globally unique

terraform init
terraform plan
terraform apply
```

## Verify

1. Portal → **Cost Management** → **Exports** — confirm `lab-focus-daily` and `lab-actual-cost-daily`
2. After the next scheduled run, browse storage → `cost-exports` → `focus-parquet/`
3. Open `_manifest.json` under the date folder — see [samples/manifest.example.json](../../samples/manifest.example.json)

## Destroy (stop ongoing export charges for storage only)

```bash
terraform destroy
```

Exports stop when resources are deleted. You still pay for storage until the account is removed.

## Relation to SCAD

The production FinOps module lives at `infrastructure/terraform/modules/finops/`. This lab is a **smaller copy** for learning only.
