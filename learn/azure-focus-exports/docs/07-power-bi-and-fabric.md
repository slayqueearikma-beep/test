# Power BI and Microsoft Fabric

---

## Why FOCUS + Power BI is a strong combo

- FOCUS = **standard columns** (BillingAccountId, ChargePeriodStart, BilledCost, etc.)
- Parquet = **fast import** into Power BI
- Fabric = Microsoft's recommended FinOps analytics path for FOCUS

Microsoft docs: [Create a Fabric workspace for FinOps](https://learn.microsoft.com/en-us/fabric/cicd/FinOps/create-fabric-workspace-for-finops)

---

## Option 1 — Power BI from Parquet blobs (learning)

1. Open **Power BI Desktop**
2. **Get Data** → **Azure** → **Azure Blob Storage**
3. Enter storage account name
4. Navigate to `focus-cost/focus-parquet/`
5. Select **Parquet** files (or folder)
6. **Load** or **Transform** in Power Query

Tip: load **entire folder** so all partitions are combined.

---

## Option 2 — Power BI from manifest-driven refresh

Advanced pattern:

1. Read `manifest.json` first (Power Query JSON parser)
2. Expand `blobs[]` list
3. Load only listed parquet paths
4. Append into one table

This matches how enterprise pipelines work.

---

## Option 3 — Fabric workspace for FinOps

Microsoft's path for FOCUS-native analytics:

```text
FOCUS export (Parquet in Blob)
  → Fabric Lakehouse shortcut or copy
  → Semantic model
  → FinOps dashboards
```

See official Fabric FinOps docs for workspace templates.

---

## Option 4 — SCAD SQL tables (after ingestion)

If you deployed SCAD FinOps module with Azure Function ingestion:

| SQL table | Power BI use |
|-----------|--------------|
| `cost_files` | Track which exports were ingested |
| `pipeline_runs` | DevSecOps + cost on one dashboard |

Connect: **Get Data** → **Azure SQL Database**

Details: `docs/finops-power-bi.md` in repo root.

---

## Starter dashboard ideas

| Visual | Source |
|--------|--------|
| Daily spend trend | FOCUS `BilledCost` by date |
| Cost by service | FOCUS `ServiceName` |
| Cost by resource group | FOCUS `SubAccountId` / tags |
| Month-to-date total | Filter current month |
| Export health | SQL `cost_files` count by day |
| Pipeline risk trend | SQL `pipeline_runs.risk_score` |

---

## FOCUS column learning tip

Open one Parquet file and list columns. Compare to:

https://focus.finops.org/specifications/1.0/

Key columns you'll use often:

- `ChargePeriodStart` / `ChargePeriodEnd`
- `BilledCost` / `EffectiveCost`
- `BillingCurrency`
- `ServiceName`
- `ResourceId`
- `Tags` (JSON map)

---

## Next step

Complete exercises in [../exercises/](../exercises/)
