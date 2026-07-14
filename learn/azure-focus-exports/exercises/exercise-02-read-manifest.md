# Exercise 02 — Read the manifest and Parquet files

**Goal:** Understand how Azure partitions FOCUS exports and what metadata you get for free.

## Steps

1. In **Storage account** → **Containers** → your export container, navigate to:
   ```
   focus-parquet/<run-folder>/
   ```
2. Download `_manifest.json` and compare to [samples/manifest.example.json](../samples/manifest.example.json).
3. Note these fields:
   - `runInfo.status` — Completed / Failed / InProgress
   - `runInfo.files[].blobName` — paths to Parquet parts
   - `runInfo.dataRowCount` — rows in this run
   - `exportConfig.type` — should be `FocusCost`
4. Download one `.parquet` file.

### Option A — Azure Storage Explorer

Open the file locally; some versions preview Parquet schema.

### Option B — Python (quick peek)

```bash
pip install pandas pyarrow
python -c "
import pandas as pd
df = pd.read_parquet('00000001.parquet')
print(df.columns.tolist())
print(df.head(3))
"
```

### Option C — Power BI

**Get data** → **Azure** → **Azure Data Lake Storage Gen2** or **Blob** → point at the container path.

## Check your work

- [ ] You found `_manifest.json` without help
- [ ] You listed at least 5 column names from FOCUS Parquet
- [ ] You know why manifests matter for incremental ingestion (see [docs/05-manifest-and-partitioning.md](../docs/05-manifest-and-partitioning.md))

## Reflection questions

1. What happens if you run the export daily for a month — how many folders appear?
2. How would an Azure Function know a **new** file arrived? (Hint: Event Grid on blob create)
3. How does this connect to SCAD's `FocusIngest` function in `finops/ingestion-function/`?

## Next

[Exercise 03 — Terraform lab](./exercise-03-terraform-lab.md)
