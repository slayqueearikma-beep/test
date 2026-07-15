# Azure FOCUS Cost Exports — Learning Path

This folder is a **standalone study area** for learning **FOCUS** (FinOps Open Cost and Usage Specification) and Azure Cost Management exports.

It follows the official Microsoft tutorial:

**[Create and manage Cost Management exports](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports)**

SCAD also implements FOCUS in production Terraform (`infrastructure/terraform/modules/finops/`). This folder is for **learning first**, without needing the full SCAD platform running.

---

## What you will learn

1. What Cost Management exports are
2. Difference between Actual, Amortized, Usage, and **FOCUS**
3. How to create exports in the Azure portal
4. How files land in Blob Storage (`manifest.json`, partitions, Parquet)
5. How to verify exports with Storage Explorer
6. How to provision exports with Terraform (lab)
7. How to connect exports to **Power BI / Fabric**

---

## Learning order (recommended)

| Step | File | Time |
|------|------|------|
| 1 | [docs/01-what-is-focus.md](docs/01-what-is-focus.md) | 15 min |
| 2 | [docs/02-prerequisites-and-scopes.md](docs/02-prerequisites-and-scopes.md) | 15 min |
| 3 | [docs/03-portal-create-export.md](docs/03-portal-create-export.md) | 30 min |
| 4 | [docs/04-export-data-types.md](docs/04-export-data-types.md) | 20 min |
| 5 | [docs/05-manifest-and-partitioning.md](docs/05-manifest-and-partitioning.md) | 20 min |
| 6 | [docs/06-verify-and-run-history.md](docs/06-verify-and-run-history.md) | 20 min |
| 7 | [lab/terraform/README.md](lab/terraform/README.md) | 45 min |
| 8 | [docs/07-power-bi-and-fabric.md](docs/07-power-bi-and-fabric.md) | 30 min |
| 9 | [exercises/](exercises/) | hands-on |
| — | [docs/09-region-policy-troubleshooting.md](docs/09-region-policy-troubleshooting.md) | if apply fails with 403 |

---

## Folder structure

```text
learn/azure-focus-exports/
├── README.md                     # You are here
├── docs/                         # Theory + portal steps
├── lab/terraform/                # Minimal Terraform export lab
├── samples/                      # Example manifest.json
└── exercises/                    # Checklists and practice tasks
```

---

## Quick comparison: export types

| Type | Format | Best for |
|------|--------|----------|
| Actual cost | CSV | Raw billed charges |
| Amortized cost | CSV | Reservations / savings plans spread over time |
| Usage only | CSV | Usage meters without purchases |
| **FOCUS** | **Parquet** | **Modern FinOps, Power BI, Fabric, less processing cost** |

FOCUS combines actual + amortized in one open standard.

---

## Hands-on options

### Option A — Azure Portal only (easiest)

Follow [docs/03-portal-create-export.md](docs/03-portal-create-export.md).

### Option A2 — No portal: Terraform + CLI

Follow [docs/08-verify-without-portal.md](docs/08-verify-without-portal.md) — create with Terraform, verify with `terraform output`, `az rest`, and blob listing.

### Option B — Terraform lab (repeatable)

```bash
cd learn/azure-focus-exports/lab/terraform
cp terraform.tfvars.example terraform.tfvars
terraform init
terraform apply
```

### Option C — See SCAD production module

After you understand the basics, compare with:

`infrastructure/terraform/modules/finops/main.tf`

---

## Important timing notes (from Microsoft)

- New subscriptions: Cost Management can take **up to 48 hours** before exports work
- First export run: can take **up to 24 hours** before files appear
- Daily exports in first 5 days of month: Azure may run exports **twice per day** for prior-month reconciliation
- Data usually available within **4 hours** after a run starts

---

## Official links

- [Tutorial: Improved exports](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/tutorial-improved-exports)
- [Cost Management dataset schema index](https://learn.microsoft.com/en-us/azure/cost-management-billing/costs/understand-cost-mgt-data)
- [FOCUS specification](https://focus.finops.org/)
- [Create a Fabric workspace for FinOps](https://learn.microsoft.com/en-us/fabric/cicd/FinOps/create-fabric-workspace-for-finops)

---

## Exercises

- [Exercise 1: Create your first FOCUS export in the portal](exercises/exercise-01-portal-focus-export.md)
- [Exercise 2: Read manifest.json and partitions](exercises/exercise-02-read-manifest.md)
- [Exercise 3: Deploy export with Terraform lab](exercises/exercise-03-terraform-lab.md)
