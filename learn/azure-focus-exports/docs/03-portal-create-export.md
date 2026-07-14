# Create a FOCUS export in Azure Portal

Step-by-step from the [Microsoft improved exports tutorial](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports#create-exports).

---

## Step 1 — Open Cost Management

1. Go to https://portal.azure.com
2. Search **Cost Management**
3. Select your **billing scope** (subscription is fine for learning)
4. Left menu → **Exports**

---

## Step 2 — Create export

1. Click **+ Create**
2. **Basics** tab → choose a template or **Create your own export**
3. Click **Next**

---

## Step 3 — Configure dataset (FOCUS)

On the **Datasets** tab:

| Field | Recommended value |
|-------|-------------------|
| **Type of data** | **Cost and usage details (FOCUS)** |
| **Dataset version** | Latest (e.g. 1.0 / 1.2-preview if shown) |
| **Export name** | `learn-focus-daily` |
| **Frequency** | **Daily export of month-to-date costs** |

Optional: click **+ Add export** to also add Actual or Amortized for comparison (max 10 per job).

Click **Next**.

---

## Step 4 — Destination (Blob Storage)

On the **Destination** tab:

| Field | Recommended value |
|-------|-------------------|
| Storage type | Azure blob storage |
| Subscription | Your subscription |
| Resource group | Create `rg-focus-learn` or use existing |
| Storage account | Create `stfocuslearn<random>` |
| Container | `focus-cost` |
| Directory path | `focus-parquet` |
| **Format** | **Parquet** |
| Compression | None (or Snappy for Parquet) |
| File partitioning | **On** (default, cannot disable) |
| Overwrite data | **On** (default for daily) |

Click **Next** → **Review + create** → **Create**.

---

## Step 5 — Wait for first run

- Export appears in list as **Enabled**
- First files: up to **24 hours**
- Check **Run history** on the export blade

---

## Step 6 — Verify in Storage Explorer

1. On export row → click **storage account name**
2. **Open in Explorer** (or use Azure Storage Explorer desktop app)
3. Navigate: `focus-cost` → `focus-parquet` → current month folder
4. You should see:
   - `manifest.json`
   - One or more `.parquet` files

---

## Optional portal actions (learn these)

| Action | What it does |
|--------|--------------|
| **Run now** | Trigger export immediately |
| **Export selected dates** | Backfill up to 13 months (one month at a time) |
| **Disable** | Pause schedule |
| **Delete** | Remove export |
| **Refresh** | Update run history view |

---

## Exercise

Complete [exercise-01-portal-focus-export.md](../exercises/exercise-01-portal-focus-export.md).

---

## Next step

[04-export-data-types.md](04-export-data-types.md)
