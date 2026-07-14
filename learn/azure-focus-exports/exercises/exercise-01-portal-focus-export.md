# Exercise 01 — Create a FOCUS export in the portal

**Goal:** Complete the Microsoft tutorial flow by hand before using Terraform.

**Tutorial:** [Create and manage improved exports](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports)

## Steps

1. Sign in to [Azure portal](https://portal.azure.com).
2. Open **Cost Management + Billing** → your **subscription** (not a management group for your first attempt).
3. Go to **Cost Management** → **Exports** → **Add**.
4. Configure:
   - **Name:** `learn-focus-daily`
   - **Dataset:** **FOCUS cost and usage data (preview)**
   - **Scope:** This subscription
   - **Storage account:** Create new or use existing (note the container name)
   - **Path:** `focus-parquet/` (or any folder name you prefer)
   - **Format:** Parquet
   - **Recurrence:** Daily
   - **Time frame:** Month to date (or Billing month to date if offered)
5. Save and wait for **Run history** to show a completed run (may take until the next day).

## Check your work

- [ ] Export appears under **Exports** with status Active
- [ ] Run history shows **Completed** (not Failed)
- [ ] Storage container contains a folder with today's date and `_manifest.json`
- [ ] You can explain FOCUS vs ActualCost in one sentence (see [docs/04-export-data-types.md](../docs/04-export-data-types.md))

## If it fails

| Error | What to try |
|-------|-------------|
| FOCUS not available | Confirm subscription type; try enrollment / EA / MCA / PAYG |
| Permission denied | Need Cost Management Contributor or custom role with export write |
| Storage access | Grant Storage Blob Data Contributor to your user or the export managed identity |

## Next

[Exercise 02 — Read the manifest](./exercise-02-read-manifest.md)
