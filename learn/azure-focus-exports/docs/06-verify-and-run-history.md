# Verify exports and run history

---

## Verify data landed in storage

### Method 1 — Azure Portal

1. Cost Management → **Exports**
2. Click your export
3. Click **storage account** link
4. **Open in Explorer**
5. Browse to container + folder path

### Method 2 — Azure Storage Explorer (desktop)

1. Download Storage Explorer
2. Connect to your storage account
3. Open container → `focus-parquet`
4. Download `manifest.json` and `.parquet` files

### Method 3 — Azure CLI

```bash
az storage blob list \
  --account-name <STORAGE_ACCOUNT> \
  --container-name focus-cost \
  --prefix focus-parquet/ \
  --auth-mode login \
  --output table
```

---

## Read run history

On the export detail blade:

| Field | Meaning |
|-------|---------|
| Last run | When export last executed |
| Next run | Scheduled next execution |
| Status | Success / failed / in progress |
| Run history table | Past executions |

**Note:** Early in the month Azure may run **twice daily** for days 1–5 to reconcile prior month (second run may not show in history UI).

---

## Expected timeline

| When | What you see |
|------|--------------|
| T+0 | Export created, status Enabled |
| T+0 to 24h | First run queued/completed |
| T+run+4h | Files in blob container |
| Daily after | Updated month-to-date files |

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| No files after 48h | Check run history for errors; verify permissions |
| FOCUS option greyed out | Subscription type may not support FOCUS |
| Access denied to storage | Enable trusted Azure services; check firewall |
| Empty parquet files | Normal for very new subscription with no usage |
| Export failed after firewall change | Re-save export in portal to refresh managed identity |

---

## Validate file content (quick)

### manifest.json

```bash
az storage blob download \
  --account-name <STORAGE> \
  --container-name focus-cost \
  --name "focus-parquet/<path>/manifest.json" \
  --file manifest.json \
  --auth-mode login

cat manifest.json | jq .
```

### Parquet (Python)

```python
import pandas as pd
df = pd.read_parquet("part-0000.parquet")
print(df.columns.tolist())
print(df.head())
```

FOCUS columns follow the [FOCUS specification](https://focus.finops.org/) — column names are standardized across clouds.

---

## Next step

- Terraform lab: [../lab/terraform/README.md](../lab/terraform/README.md)
- Power BI: [07-power-bi-and-fabric.md](07-power-bi-and-fabric.md)
