# What is FOCUS?

**FOCUS** = **FinOps Open Cost and Usage Specification**

It is an **open standard** for cloud cost and usage data. Microsoft Azure supports exporting billing data directly in FOCUS format.

Official spec: https://focus.finops.org/

---

## Why FOCUS exists

Before FOCUS, FinOps teams had to:

- Download **separate** actual and amortized exports
- Normalize different cloud vendor formats (Azure, AWS, GCP)
- Build heavy ETL pipelines
- Store duplicate data

FOCUS gives you **one standardized schema** that:

- Combines **actual + amortized** cost concepts
- Uses efficient **Parquet** format (not only CSV)
- Reduces processing time and storage cost
- Works with **Power BI**, **Microsoft Fabric**, Spark, SQL

---

## FOCUS vs other Azure export types

| Export type | What it contains | Format | When to use |
|-------------|------------------|--------|-------------|
| **Actual cost** | What you were billed | CSV | Invoice reconciliation |
| **Amortized cost** | Reservations/savings plans spread daily | CSV | True daily cost of reserved capacity |
| **Usage only** | Usage meters, no purchases | CSV | Legacy / usage analytics |
| **FOCUS** | Standardized cost + usage (actual + amortized combined) | **Parquet** | **Modern FinOps platforms, Fabric, multi-cloud** |

Microsoft quote from the tutorial:

> FOCUS combines actual and amortized costs and reduces data processing times and storage and compute costs.

---

## What FOCUS files look like in Azure

When you create a **Cost and usage details (FOCUS)** export:

```text
Storage Account
  └── container (e.g. focus-cost)
        └── focus-parquet/          ← root folder you configure
              └── YYYY/MM/DD/       ← partitioned paths
                    ├── manifest.json
                    ├── part-0000.parquet
                    └── part-0001.parquet (if large)
```

- **Parquet** = columnar, compressed, fast for analytics
- **manifest.json** = index of all partition files (always read this first)
- **Partitioning** = always on (cannot disable); files split if > ~1 GB uncompressed

---

## FOCUS in SCAD

SCAD provisions a FOCUS export in:

`infrastructure/terraform/modules/finops/main.tf` (`azapi_resource.focus_export`)

Settings used:

| Setting | SCAD value |
|---------|------------|
| Type | `FocusCost` |
| Format | `Parquet` |
| Granularity | `Daily` |
| Timeframe | `MonthToDate` |
| Partitioning | `true` |
| Overwrite | `OverwritePreviousReport` |
| Container path | `focus-cost/focus-parquet/` |

---

## Key concepts to remember

1. **FOCUS is a data standard**, not a tool
2. **Export** = scheduled job that writes files to Blob Storage
3. **manifest.json** = map of all data files for one run
4. **Parquet** = what Power BI / Fabric / Spark prefer over CSV
5. **Not all subscription types support FOCUS** (e.g. some MOSP scopes)

---

## Next step

Read [02-prerequisites-and-scopes.md](02-prerequisites-and-scopes.md) before creating your first export.
