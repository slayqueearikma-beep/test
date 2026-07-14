# Manifest.json and file partitioning

From: [File partitioning](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports#file-partitioning-for-large-datasets)

---

## Why partitioning exists

Azure **always partitions** export files:

- Each uncompressed chunk stays under **~1 GB**
- Large datasets split into `part-0000.parquet`, `part-0001.parquet`, etc.
- **Cannot be disabled** (by design)
- Even small exports get a manifest + partition pattern for consistency

---

## manifest.json — read this first

Every export run delivers a **manifest.json** that describes:

- Export name and configuration
- Run ID and date range
- List of all blob partitions (`blobs[]`)
- Row counts and byte counts

Example structure (simplified from Microsoft docs):

```json
{
  "manifestVersion": "2024-04-01",
  "byteCount": 8032,
  "blobCount": 1,
  "dataRowCount": 36,
  "exportConfig": {
    "exportName": "learn-focus-daily",
    "type": "FocusCost",
    "timeFrame": "MonthToDate"
  },
  "deliveryConfig": {
    "partitionData": true,
    "dataOverwriteBehavior": "OverwritePreviousReport",
    "fileFormat": "Parquet",
    "rootFolderPath": "focus-parquet"
  },
  "runInfo": {
    "runId": "bbac73f1-9a05-4de6-84ab-c72b568a03b4",
    "startDate": "2025-03-01T00:00:00",
    "endDate": "2025-03-21T00:00:00Z"
  },
  "blobs": [
    {
      "blobName": "focus-parquet/.../part0.parquet",
      "byteCount": 8032,
      "dataRowCount": 36
    }
  ]
}
```

Full sample in: [`../samples/manifest.example.json`](../samples/manifest.example.json)

---

## How to ingest partitioned data

```text
1. List blobs in export folder
2. Find manifest.json for the run
3. Parse manifest.blobs[] for file names
4. Read ALL parquet parts (not just one)
5. Union in Spark / Fabric / Power BI / SQL pipeline
```

**Never hardcode** partition file names — they can change.

---

## Overwrite behavior (daily exports)

Default: **OverwritePreviousReport**

- Each day replaces the previous day's file for that period
- Keeps storage clean
- Always re-process the latest run for month-to-date

SCAD Terraform sets:

```hcl
dataOverwriteBehavior = "OverwritePreviousReport"
partitionData         = true
```

---

## Tools that handle partitions well

| Tool | Good for |
|------|----------|
| **Microsoft Fabric** | Native FinOps workspace |
| **Power BI** | Import folder of Parquet |
| **Azure Synapse / Spark** | Large scale |
| **Python (pandas/pyarrow)** | Learning scripts |
| **Excel** | Poor — use curated summaries only |

---

## Exercise

[exercise-02-read-manifest.md](../exercises/exercise-02-read-manifest.md)

---

## Next step

[06-verify-and-run-history.md](06-verify-and-run-history.md)
