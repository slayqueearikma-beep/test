# FinOps data path and Power BI integration

This guide explains how SCAD sends cost and pipeline data to Azure and how to visualize it in Power BI or Microsoft Fabric.

## What gets provisioned

Terraform module `infrastructure/terraform/modules/finops` creates:

| Resource | Role |
|----------|------|
| Storage Account `st...finops` | Landing zone for exports and metrics |
| Containers `focus-cost`, `pipeline-metrics`, `curated` | Raw and normalized data |
| Cost exports | ActualCost, Usage, optional FOCUS Parquet |
| Azure SQL `scad-finops` | Structured tables for BI |
| Azure Function | Event-driven ingestion |
| Event Grid | Blob created triggers |
| Application Insights | Ingestion telemetry |

## Tables in Azure SQL

| Table | Contents |
|-------|----------|
| `cost_files` | Metadata for each ingested export file |
| `pipeline_runs` | CI/CD run status, risk score, decision |

## Setup after first deploy

1. Run Terraform deploy (staging or production).
2. Copy Terraform outputs:
   - `finops_storage_account_name`
   - `finops_sql_server_fqdn`
   - `finops_sql_database_name`
3. In GitHub repository settings, add variable:
   - `SCAD_FINOPS_STORAGE_ACCOUNT` = storage account name
4. Optional: set Terraform variable `ci_principal_id` to your GitHub Actions OIDC service principal object ID so the pipeline can upload metrics before the first deploy output is wired manually.

## Power BI from Azure SQL

1. Open **Power BI Desktop**.
2. **Get Data** -> **Azure** -> **Azure SQL Database**.
3. Server: value of `finops_sql_server_fqdn`
4. Database: `scad-finops`
5. Use Microsoft account / Entra auth.
6. Import tables:
   - `pipeline_runs`
   - `cost_files`

### Starter measures

| Visual | Query idea |
|--------|------------|
| Pipeline success rate | `pipeline_runs[conclusion]` |
| Blocked releases | `pipeline_runs[risk_decision] = "blocked"` |
| Cost files ingested | `COUNT(cost_files[id])` by day |
| Environment split | `pipeline_runs[environment]` |

## Power BI from Blob Storage

1. **Get Data** -> **Azure Blob Storage**.
2. Account: `finops_storage_account_name`
3. Container: `curated`
4. Load `*.summary.json` files.

Use this for quick dashboards without SQL credentials.

## Power BI from Log Analytics

1. **Get Data** -> **Azure Monitor** -> **Log Analytics**.
2. Select the SCAD workspace (`log-...`).
3. Example KQL:

```kusto
ContainerAppConsoleLogs_CL
| where TimeGenerated > ago(7d)
| summarize count() by bin(TimeGenerated, 1h)
```

## Power BI from raw FOCUS / cost exports

1. Connect to container `focus-cost`.
2. Load `actual-cost/`, `usage/`, or `focus-parquet/` files.
3. Model billing period, service, cost, resource ID columns from export schema.

FOCUS parquet is best for advanced FinOps models; CSV exports work for starter dashboards.

## How pipeline metrics arrive

```text
GitHub Actions
  -> scripts/publish-pipeline-metrics.mjs
  -> blob pipeline-metrics/{run_id}.json
  -> Event Grid
  -> Function PipelineMetricsIngest
  -> SQL pipeline_runs
```

Metrics are published when:

- Deploy workflow finishes (reads Terraform output), or
- `SCAD_FINOPS_STORAGE_ACCOUNT` repository variable is configured

## How cost exports arrive

```text
Azure Cost Management
  -> scheduled export
  -> blob focus-cost/*
  -> Event Grid
  -> Function FocusIngest
  -> SQL cost_files + curated summary JSON
```

Exports can take 24-48 hours to appear after provisioning.

## Troubleshooting

| Issue | Check |
|-------|-------|
| No files in storage | Cost export schedule and scope |
| FOCUS export failed | Set `enable_focus_export=false` if unsupported |
| Function not firing | Event Grid subscriptions and Function logs in App Insights |
| SQL empty | Function managed identity and Key Vault secret reference |
| Power BI auth fails | Entra user has SQL read access |

## Disable FinOps module

```hcl
enable_finops = false
```

Use this for lightweight CI-only environments.
