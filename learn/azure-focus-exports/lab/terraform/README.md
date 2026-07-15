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
# Edit storage_account_name (globally unique) and location if needed
```

**Region policy?** If apply fails with `RequestDisallowedByAzure`, run `scripts/pick-allowed-region.ps1` and set `location` in `terraform.tfvars`. See [docs/09-region-policy-troubleshooting.md](../../docs/09-region-policy-troubleshooting.md).

```bash
terraform init
terraform plan
terraform apply
```

## Verify (no portal required)

See [docs/08-verify-without-portal.md](../../docs/08-verify-without-portal.md) or run:

```powershell
..\..\scripts\verify-exports.ps1
```

## Destroy (stop ongoing export charges for storage only)

```bash
terraform destroy
```

Exports stop when resources are deleted. You still pay for storage until the account is removed.

## Relation to SCAD

The production FinOps module lives at `infrastructure/terraform/modules/finops/`. This lab is a **smaller copy** for learning only.
