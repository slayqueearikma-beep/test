# SCAD CI/CD Platform

Industry-style pipeline layout for SCAD using reusable workflows, composite actions, and environment promotion.

## Workflow map

| Workflow | Trigger | Purpose |
|----------|---------|---------|
| `scad-platform.yml` | PR, push to `main`, manual | Main orchestrator |
| `scad-terraform-plan.yml` | PR touching Terraform | Plan comment on PR |
| `scad-release.yml` | Tag `v*.*.*` | Release assets + production deploy |
| `scad-scheduled.yml` | Weekly cron + manual | Security and drift checks |

## Reusable workflows

| Workflow | Responsibility |
|----------|----------------|
| `reusable-validate-app.yml` | Lint, tests, coverage gate, npm audit |
| `reusable-security-scan.yml` | Gitleaks, CodeQL, dependency review, Checkov, SARIF |
| `reusable-build-supply-chain.yml` | Docker build, Trivy, SBOM, Cosign, provenance |
| `reusable-risk-gate.yml` | SCAD risk scoring policy gate |
| `reusable-deploy-azure.yml` | Azure deploy with signed image promotion |

## Composite actions

| Action | Responsibility |
|--------|----------------|
| `scad-risk-gate` | Block pipeline on `blocked` decision |
| `scad-smoke-test` | Post-deploy health and API smoke tests |

## Promotion model

```text
PR
 -> validate + security + build + risk gate
 -> no deploy

push main
 -> validate + security + build + risk gate
 -> deploy staging
 -> deploy production only when:
      - manual workflow input deploy_production=true, or
      - release tag workflow

tag v1.2.3
 -> release workflow
 -> production deploy
```

## Required GitHub environments

Create these environments in repository settings:

1. `staging`
2. `production` (recommended approval rules)

## Required secrets

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Artifacts produced

- Coverage report
- Pipeline security findings JSON
- SBOM (SPDX)
- Signed image tarball (promoted to ACR without rebuild)
- Risk decision snapshot

## Security dashboards

SARIF results are uploaded for:

- CodeQL
- Checkov
- Trivy

View them in GitHub **Security** tab.

## Local commands

```bash
npm run test
npm run deploy
node scripts/ci-risk-gate.mjs --findings pipeline-findings.json
```

## Production hardening roadmap

- Enable `SCAD_REQUIRE_API_AUTH=true` and configure `SCAD_AUTH_SECRET`
- Move Terraform state to Azure Storage (`backend.tf.example`)
- Add Azure Key Vault secret references for ingest/auth tokens
- Enforce branch protection on required checks from `scad-platform.yml`
