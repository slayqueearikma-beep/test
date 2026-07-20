# MarGem Budget Azure (~$15–25/month)

The **cheapest** way to run MarGem in the cloud: **one small VM** running Docker Compose (Postgres + API) plus minimal blob storage for images.

No Container Apps, no managed PostgreSQL, no Key Vault.

## Cost estimate

| Resource | ~Monthly |
|----------|----------|
| VM `Standard_B1s` (1 vCPU, 1GB RAM) | ~$8–10 |
| VM `Standard_B1ms` (2GB RAM, if B1s OOMs) | ~$15 |
| Blob storage (LRS) | ~$1–3 |
| Public IP (Basic) | ~$3 |
| **Total** | **~$15–25** |

Compare to full PaaS stack: ~$50–90/month.

## One-command deploy (Windows)

```powershell
cd souq-local

# 1. One-time setup
copy infra\terraform-budget\terraform.tfvars.example infra\terraform-budget\terraform.tfvars
# Edit: subscription_id, ssh_public_key, passwords

# Generate SSH key if needed:
ssh-keygen -t rsa -b 4096
Get-Content $env:USERPROFILE\.ssh\id_rsa.pub   # paste into terraform.tfvars

# 2. Deploy everything
.\start_azure_budget.ps1
```

## What it creates

- 1× Ubuntu VM with Docker
- NSG (ports 22 SSH, 8000 API)
- Blob storage for uploads
- Postgres + API in Docker on the VM

## After deploy

```powershell
# Test
curl http://YOUR_VM_IP:8000/health

# Flutter (beta — uses HTTP)
flutter run --dart-define=API_BASE_URL=http://YOUR_VM_IP:8000
```

**Note:** Budget tier uses **HTTP**, not HTTPS. Fine for beta/testing. Play Store production needs HTTPS (upgrade to full Terraform stack or add a domain + Caddy later).

## Save money when not using

```powershell
# Stop VM (keeps data, ~$3/mo disk)
.\stop_azure_budget.ps1 -Deallocate

# Start VM again
az vm start --resource-group rg-margem-budget-sub1 --name margem-budget-sub1-vm

# Redeploy app after code changes
.\start_azure_budget.ps1
```

## Delete everything

```powershell
.\stop_azure_budget.ps1 -Destroy
```

## vs full stack (`infra/terraform/`)

| | Budget VM | Full PaaS |
|--|-----------|-----------|
| Cost | ~$15–25 | ~$50–90 |
| Ops | You manage VM | Azure managed |
| HTTPS | HTTP only | HTTPS built-in |
| Scale | 1 VM | Auto-scale |
| Best for | Beta, first users | Growth, Play Store |
