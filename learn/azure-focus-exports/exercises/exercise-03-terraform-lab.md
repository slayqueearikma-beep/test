# Exercise 03 — Deploy exports with Terraform

**Goal:** Reproduce the portal export as code using the standalone lab in this repo.

## Steps

1. Read [lab/terraform/README.md](../lab/terraform/README.md).
2. Copy `terraform.tfvars.example` → `terraform.tfvars` and set a **unique** `storage_account_name`.
3. Run:
   ```bash
   cd learn/azure-focus-exports/lab/terraform
   terraform init
   terraform plan
   terraform apply
   ```
4. Compare portal **Exports** list with `terraform show`.
5. Optional: change tags or export names and run `terraform plan` again — observe drift vs portal edits.

## Check your work

- [ ] `terraform apply` succeeded
- [ ] Both ActualCost and FOCUS exports exist
- [ ] Outputs show `focus_export_path` and `portal_exports_url`
- [ ] You can destroy cleanly with `terraform destroy` when finished

## Compare to SCAD FinOps module

| This lab | SCAD `modules/finops/` |
|----------|-------------------------|
| Storage + exports only | + SQL, Function, Event Grid, App Insights |
| Learning / disposable | Wired to pipeline metrics + Power BI docs |
| Same AzAPI FOCUS pattern | Same `FocusCost` + Parquet path idea |

Open `infrastructure/terraform/modules/finops/main.tf` and find `azapi_resource.focus_export` — note similarities.

## Stretch goals

1. Add a second export with `timeframe = "TheLastMonth"` in a separate `.tf` file (do not apply to production without change control).
2. Document your subscription ID and export names in a personal runbook (never commit secrets).
3. Connect Power BI using [docs/07-power-bi-and-fabric.md](../docs/07-power-bi-and-fabric.md).

## Done?

You have completed the FOCUS learning track. Return to SCAD FinOps docs: `docs/finops-power-bi.md`.
