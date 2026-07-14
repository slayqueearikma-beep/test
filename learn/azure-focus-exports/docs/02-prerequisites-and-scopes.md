# Prerequisites and scopes

Based on: [Microsoft tutorial — Prerequisites](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports#prerequisites)

---

## Azure permissions you need

For **subscription** scope exports:

| Role | Can do |
|------|--------|
| **Owner** | Create, modify, delete exports |
| **Contributor** | Create/modify own exports |
| **Reader** | Limited export scheduling |

You also need **write access** to the target Storage Account when creating or changing the export destination.

---

## Storage account requirements

- Must support **Blob** (or File) storage
- Container must **not** be used as object replication destination
- For firewall-enabled storage:
  - Enable **Allow trusted Azure services**
  - Cost Management creates a **system-assigned managed identity**
  - Identity gets **Storage Blob Data Contributor** on the container

---

## Supported scopes for FOCUS

FOCUS exports support:

- EA: Enrollment, department, account, **subscription**, **resource group**
- MCA: Billing account, billing profile, invoice section, **subscription**, **resource group**
- MPA: Customer, **subscription**, **resource group**

**Not supported for FOCUS:**

- **Management group** scope
- Some **MOSP** billing scopes

SCAD uses **subscription-level** FOCUS export + **resource group** Actual/Usage exports.

---

## Timing before you start

| Wait | Reason |
|------|--------|
| Up to **48 hours** | New subscription — Cost Management not ready |
| Up to **24 hours** | First export run to complete |
| Up to **4 hours** | After run starts, data appears in storage |

Do not panic if the container is empty on day one.

---

## What to prepare

Before creating an export, have:

1. Azure subscription with billing enabled
2. Storage account (or permission to create one)
3. Container name (e.g. `focus-cost`)
4. Folder path (e.g. `focus-parquet`)
5. Decision: **Portal lab** or **Terraform lab**

---

## Lab vs production

| | Learning lab (`learn/.../lab/terraform`) | SCAD production |
|---|------------------------------------------|-----------------|
| Purpose | Study FOCUS exports | Full FinOps platform |
| Scope | Subscription or RG you choose | SCAD resource group + subscription |
| Coupled to SCAD app | No | Yes |

---

## Next step

[03-portal-create-export.md](03-portal-create-export.md) — create export in Azure Portal.
