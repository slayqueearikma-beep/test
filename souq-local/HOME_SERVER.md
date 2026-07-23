# MarGem Home Server — Laptop API + local (or Azure) images

Run the API and database on **your laptop**. Images default to **local disk** on the
laptop (no Azure required). Optionally point `STORAGE_BACKEND=azure` at Blob (~$1–3/month).

## Architecture

```
Your laptop (Linux)
┌─────────────────────────────┐
│ Docker                      │
│  ├── Postgres               │
│  ├── FastAPI :8000          │
│  └── /data/media (images)   │
└─────────────────────────────┘
         ▲
    Phone / users
```

Optional Azure mode:

```
Your laptop                    Azure (~$1-3/mo)
┌─────────────────────┐      ┌──────────────────┐
│ Docker API+Postgres │─────▶│ Blob margem-media│
└─────────────────────┘      └──────────────────┘
```

## Setup (one time)

### On your laptop (Linux)

```bash
# Install Docker
sudo apt update && sudo apt install -y docker.io docker-compose-plugin
sudo usermod -aG docker $USER
# log out and back in

git clone <your-repo>
cd souq-local
```

### Configure `.env.home`

```bash
cp env.home.example .env.home
```

Edit `.env.home`:

| Variable | Example |
|----------|---------|
| `POSTGRES_PASSWORD` | Strong password |
| `JWT_SECRET_KEY` | 32+ random chars |
| `STORAGE_BACKEND` | `local` (default) or `azure` |
| `PUBLIC_API_URL` | `http://192.168.1.50:8000` — **must** be the LAN IP your phone uses |
| `ALLOWED_HOSTS` | `localhost,127.0.0.1,192.168.1.50` |
| `CORS_ORIGINS` | `http://192.168.1.50:8000` |
| `AZURE_STORAGE_CONNECTION_STRING` | Only if `STORAGE_BACKEND=azure` |

Find laptop IP:

```bash
hostname -I | awk '{print $1}'    # Linux
```

```powershell
ipconfig   # Windows — look for IPv4
```

## Start / stop

**Linux laptop — one command starts everything:**

```bash
chmod +x start_home_server.sh stop_home_server.sh

# Docker (API + Postgres) + Flutter on USB phone
./start_home_server.sh

# Rebuild API image after code changes
./start_home_server.sh --build

# API only (no Flutter)
./start_home_server.sh --api-only

./stop_home_server.sh
```

Manual compose (same as the script):

```bash
docker compose -f docker-compose.home.yml --env-file .env.home up -d --build
docker compose -f docker-compose.home.yml --env-file .env.home down
```

**Windows (if laptop runs Windows):**


```powershell
.\start_home_server.ps1
.\stop_home_server.ps1
```

## Backups (home server)

```bash
chmod +x scripts/backup_home_db.sh
./scripts/backup_home_db.sh
# writes backups/margem-YYYYMMDD….sql.gz — copy off-site
```

## Connect from phone

### Wireless debugging (no USB cable)

Phone and Ubuntu server must be on the **same Wi-Fi**.

**On phone:** Settings → Developer options → **Wireless debugging** → ON

**Step 1 — Pair (first time only)**

Tap **“Pair device with pairing code”** on the phone. You’ll see:
- IP address & port (pairing port, e.g. `192.168.11.107:37123`)
- 6-digit pairing code

On the server:

```bash
chmod +x setup_wireless_adb.sh
./setup_wireless_adb.sh pair 192.168.11.107:37123 123456
```

**Step 2 — Connect**

On the Wireless debugging screen, note **“IP address & port”** (debug port — different from pairing port):

```bash
./setup_wireless_adb.sh connect 192.168.11.107:41293
./setup_wireless_adb.sh status
```

**Step 3 — Start everything**

```bash
./start_home_server.sh
```

If connection drops after reboot, run `connect` again (pairing is usually once per Wi-Fi).

### Same Wi-Fi (manual flutter run)

```bash
flutter run --dart-define=API_BASE_URL=http://192.168.1.50:8000
```

### From anywhere (recommended): Tailscale

1. Install [Tailscale](https://tailscale.com/) on laptop + phone (free)
2. Note laptop Tailscale IP (e.g. `100.x.x.x`)
3. Add to `.env.home`:

```env
ALLOWED_HOSTS=["100.x.x.x","100.x.x.x:8000","192.168.1.50","192.168.1.50:8000"]
CORS_ORIGINS=["http://100.x.x.x:8000","http://192.168.1.50:8000"]
```

4. Restart: `docker compose -f docker-compose.home.yml --env-file .env.home up -d`

```bash
flutter run --dart-define=API_BASE_URL=http://100.x.x.x:8000
```

## Costs

| Item | Cost |
|------|------|
| Laptop electricity | ~$2-5/mo if 24/7 |
| Azure Blob | ~$1-3/mo |
| **Total** | **~$3-8/mo** |

## vs other options

| Setup | Cost | 24/7 | Public access |
|-------|------|------|---------------|
| **Home + Blob** | ~$3-8 | If laptop stays on | Tailscale |
| `start_lab.ps1` | $0 | No (dev only) | LAN only |
| `start_azure_budget.ps1` | ~$15-25 | Yes | Public IP |

## Keep laptop awake (Linux)

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target
```

Or disable sleep in power settings.

## Troubleshooting Azure blob setup

### `404 ResourceNotFound` on storage account keys

Azure sometimes needs a minute after creating a storage account before keys/blob APIs work. This is usually a timing issue, not a wrong subscription.

**Step 1 — check Azure (PowerShell on Windows):**

```powershell
az account show
az provider show --namespace Microsoft.Storage --query registrationState
az group show -n rg-margem-home-sub1
az storage account show -n margemhomesub1stpbqc13 -g rg-margem-home-sub1
```

If `Microsoft.Storage` is not `Registered`, run:

```powershell
az provider register --namespace Microsoft.Storage
# wait 1-2 minutes, then retry
```

**Step 2 — retry Terraform:**

```powershell
cd souq-local\infra\terraform-storage
terraform init -upgrade
terraform apply
```

**Step 3 — if it still fails, clean up and start fresh:**

```powershell
terraform destroy
terraform apply
```

If `destroy` complains about missing resources:

```powershell
terraform state list
terraform state rm azurerm_storage_container.media
terraform state rm azurerm_storage_account.media
terraform apply
```

Or delete the resource group in the [Azure Portal](https://portal.azure.com), then run `terraform apply` again.

**Step 4 — pull latest repo** (includes a 60s wait fix between storage account and container):

```powershell
git pull origin cursor/production-ready-f384
.\setup_azure_blob.ps1
```

## Delete Azure blob only

```bash
cd infra/terraform-storage
terraform destroy
```
