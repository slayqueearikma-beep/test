# Troubleshooting — region policy (403 RequestDisallowedByAzure)

## The error

```text
RequestDisallowedByAzure: Resource '...' was disallowed by Azure:
This policy maintains a set of best available regions where your subscription can deploy resources.
```

This means your subscription **cannot deploy in the region you chose** (often `westeurope`). Common on:

- Azure for Students
- Free trial subscriptions
- Sponsored / enterprise subscriptions with region policies

This is **not** a Terraform bug.

---

## Fix in 3 steps

### 1. Find an allowed region

```powershell
az account list-locations --query "[?metadata.regionCategory=='Recommended'].{Region:name, Display:displayName}" -o table
```

Quick test (try until one succeeds):

```powershell
az group create --name rg-region-test --location eastus
az group delete --name rg-region-test --yes
```

Try in order: `eastus`, `westus2`, `centralus`, `northeurope`, `uksouth`.

Or run the helper script:

```powershell
.\learn\azure-focus-exports\scripts\pick-allowed-region.ps1
```

### 2. Update `terraform.tfvars`

```hcl
storage_account_name = "stfocusoussama01"   # globally unique, 3-24 lowercase letters/numbers
location             = "eastus"             # region that passed the test above
```

**Do not use** generic names like `abc123` — they are often already taken globally.

### 3. Clean up partial deploy and re-apply

If a resource group was created in the wrong region:

```powershell
az group delete --name rg-focus-export-lab --yes
```

Then:

```powershell
cd learn\azure-focus-exports\lab\terraform
terraform apply
```

---

## Other common errors

| Error | Fix |
|-------|-----|
| Storage account name already taken | Use a longer unique name, e.g. `stfocusoussama01` |
| `abc123` too generic | Must be globally unique across all Azure |
| FOCUS export fails on apply | Subscription may not support FOCUS — see [02-prerequisites-and-scopes.md](./02-prerequisites-and-scopes.md) |
| Export exists, no blobs yet | Wait up to 24 hours for first run |

---

## After a successful apply

Verify without the portal: [08-verify-without-portal.md](./08-verify-without-portal.md)
