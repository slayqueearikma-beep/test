# Export data types (full reference)

From: [Understand export data types](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports#understand-export-data-types)

---

## All export types

| Type | Description |
|------|-------------|
| **Cost and usage (actual)** | Standard usage + purchase charges as billed |
| **Cost and usage (amortized)** | Reserved instances / savings plans amortized daily |
| **Cost and usage (FOCUS)** | Open FinOps standard; actual + amortized combined |
| **Cost and usage (usage only)** | Usage meters only; legacy |
| **Price sheet** | Organization Azure pricing |
| **Reservation details** | List of reservations |
| **Reservation recommendations** | Buy recommendations |
| **Reservation transactions** | Purchases, exchanges, refunds |

---

## Frequency options (cost datasets)

For Actual, Amortized, FOCUS, Usage:

- One-time export
- **Daily** export of month-to-date
- Monthly export of last month
- Monthly export of last billing month

SCAD FinOps module uses **Daily** + **MonthToDate**.

---

## Format support

| Dataset | CSV | Parquet |
|---------|-----|---------|
| Actual / Amortized / Usage | Yes | Yes (newer exports) |
| **FOCUS** | No | **Yes (primary)** |
| Reservation recommendations | Yes | Varies |

---

## FOCUS-specific limitations (important)

From Microsoft docs:

- **Management group scope NOT supported** for FOCUS
- **Azure MOSP** subscriptions do not support FOCUS
- Use **subscription** or **resource group** scope for learning

If FOCUS export fails in Terraform/portal, try Actual + Amortized first, then fix subscription type.

---

## Historical data limits

| Dataset | Portal backfill | REST API |
|---------|-------------------|----------|
| Actual, Amortized, **FOCUS** | Up to **13 months** | Up to **7 years** |

Portal: use **Export selected dates** (one month per run).

---

## Which export should you use?

```text
Learning FOCUS / FinOps career     → FOCUS (Parquet)
Invoice matching                 → Actual (CSV)
Reserved instance true daily cost  → Amortized (CSV)
Quick Excel open                   → Actual CSV (small subs)
Power BI / Fabric / SQL warehouse  → FOCUS (Parquet)
Multi-cloud FinOps platform        → FOCUS
```

---

## SCAD uses three exports

| SCAD export | Type | Path |
|-------------|------|------|
| `scad-actual-cost` | ActualCost CSV | `focus-cost/actual-cost/` |
| `scad-usage` | Usage CSV | `focus-cost/usage/` |
| `scad-focus-export` | FocusCost Parquet | `focus-cost/focus-parquet/` |

This lets you compare legacy CSV vs FOCUS in the same storage account.

---

## Next step

[05-manifest-and-partitioning.md](05-manifest-and-partitioning.md)
