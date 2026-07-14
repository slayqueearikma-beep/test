# Automatic deploy on push

When code is pushed to `main`, the SCAD pipeline runs end to end:

```text
git push
  -> security scans (lint, tests, secrets, SAST, IaC)
  -> Docker image build
  -> Trivy image scan
  -> push image to Azure Container Registry
  -> deploy Azure Container App (running container)
  -> health check on /healthz
```

Pull requests still run scans and image build, but they do **not** deploy.

## One-time Azure setup

Add these GitHub repository secrets:

| Secret | Purpose |
|--------|---------|
| `AZURE_CLIENT_ID` | App registration / federated credential client ID |
| `AZURE_TENANT_ID` | Microsoft Entra tenant ID |
| `AZURE_SUBSCRIPTION_ID` | Azure subscription ID |

Create a GitHub environment named `production` (Settings -> Environments). Optional: add approval rules before deploy.

The deploy identity needs at least:

- **Contributor** on the resource group (or subscription for first run)
- **AcrPush** on the container registry after it exists

### Federated credential (recommended)

1. Create an app registration in Microsoft Entra ID.
2. Add a federated credential for GitHub Actions (`repo:<owner>/<repo>:ref:refs/heads/main`).
3. Assign the roles above to the app registration service principal.

## What happens on each push to main

1. Pipeline builds `scad-api:<commit-sha>`.
2. Trivy scans the image. Critical/high unfixed issues block deploy.
3. Terraform creates or updates Azure resources.
4. Image is pushed to ACR.
5. Container App pulls the new image and starts a new revision.
6. Pipeline calls `https://<your-app-url>/healthz` until it returns OK.

## Find your running app URL

Open the latest successful workflow run and check the **Verify deployed container** step, or read the Terraform output from the deploy job logs:

```text
Deployment healthy at https://ca-....azurecontainerapps.io
```

## Manual deploy

You can still deploy any tag manually from the Actions tab:

**SCAD Platform Pipeline** -> **Run workflow** -> optional `image_tag`

## Disable automatic deploy

To keep scans on `main` but skip deploy, remove the `production` environment or temporarily change the deploy job `if` condition in `.github/workflows/scad-devsecops.yml`.
