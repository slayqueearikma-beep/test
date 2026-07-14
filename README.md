# SCAD - Secure Cloud-Native Application Delivery

SCAD is a DevSecOps portfolio project that demonstrates how to test, scan, containerize, and deploy a cloud-native application to Azure using automated security controls.

The project is designed for a DevSecOps / Cloud Architect profile. It combines application delivery, infrastructure as code, container security, secret management, observability, security data integration, and risk-based release decisions in one repository.

## Architecture flow

```text
Developer
  -> GitHub Repository
  -> GitHub Actions Platform Pipeline
  -> Validate / Security / Supply Chain (reusable workflows)
  -> Risk Gate (SCAD policy engine)
  -> Staging Deploy -> Production Promote
```

## Repository structure

```text
.
├── app/                         # SCAD demo API
│   ├── src/server.js             # Express API with health, readiness, and metrics
│   ├── test/server.test.js        # Node.js tests
│   └── Dockerfile                # Production container image
├── infrastructure/terraform/     # Azure infrastructure as code
├── .github/
│   ├── workflows/                # Platform, release, scheduled, reusable workflows
│   ├── actions/                  # Composite actions (risk gate, smoke tests)
│   ├── dependabot.yml
│   └── pull_request_template.md
└── docs/                         # Architecture and presentation notes
```

## Security controls

The pipeline includes:

- Application linting and tests
- Dependency vulnerability audit
- Secret scanning with Gitleaks
- Terraform validation
- IaC security scanning with Checkov
- Docker image build
- Container vulnerability scanning with Trivy
- SBOM generation with Syft (SPDX)
- Container image signing and verification with Cosign
- SLSA-style build provenance attestations
- Optional Azure deployment through GitHub Actions OIDC credentials
- Security findings normalization API
- CVSS, EPSS, and policy-based risk scoring
- Automated release decision: approved, needs review, or blocked
- Reusable workflow architecture for industry-style CI/CD
- Coverage gate, SARIF uploads, staging/production promotion
- Weekly scheduled security and drift checks

Pipeline reference: [`docs/ci-cd-platform.md`](docs/ci-cd-platform.md)

Azure architecture and FinOps analytics:

- [`docs/azure-architecture.md`](docs/azure-architecture.md)
- [`docs/finops-power-bi.md`](docs/finops-power-bi.md)

Some enterprise Azure hardening checks are intentionally documented as future improvements instead of blocking the starter deployment. Examples include private endpoints for Key Vault, disabling all public network access, ACR geo-replication, ACR zone redundancy, and Defender-backed registry scanning. These controls are valuable in production, but they require additional network design, premium SKUs, and higher cloud cost.

## Local development

```bash
cd app
npm install
npm test
npm run lint
npm start
```

The API listens on port `8080` by default.

Useful endpoints:

- `GET /` - service metadata
- `GET /healthz` - liveness probe
- `GET /readyz` - readiness probe
- `GET /deployment` - deployment and security control metadata
- `GET /findings` - normalized security findings
- `POST /findings` - ingest one security finding
- `POST /findings/bulk` - ingest multiple security findings
- `GET /findings/summary` - findings summary by severity, category, and tool
- `GET /security/score` - CVSS/EPSS/policy risk score and release decision
- `GET /metrics` - Prometheus metrics

In production, set `SCAD_INGEST_TOKEN` and send it with write requests:

```http
X-SCAD-Ingest-Token: <token>
```

## Docker

Manual commands:

```bash
docker build -t scad-api:local -f app/Dockerfile app
docker run --rm -p 8080:8080 scad-api:local
```

Automated workflow with Docker Compose and npm scripts:

```bash
npm run docker:up       # build + start in background
npm run docker:verify   # health check + non-root user check
npm run docker:logs     # follow container logs
npm run docker:down     # stop and remove container
```

The compose service uses container name `scad-api`, so `docker stop scad-api` also works after `docker:up`.

## Choose deploy target (Azure or Docker)

Interactive menu from the repo root:

```bash
npm run deploy
```

You will see:

```text
SCAD deployment target
  1) Azure Container Apps
  2) Docker (local, open source)

Choose target [1/2]:
```

Non-interactive options:

```bash
npm run deploy:azure
npm run deploy:docker
npm run deploy -- --target azure
npm run deploy -- --target docker
```

- **Option 1 (Azure):** builds the image, pushes to ACR, deploys Container Apps. If Azure CLI or Terraform is missing locally, it triggers the GitHub Actions deploy workflow instead.
- **Option 2 (Docker):** builds and runs the container locally with Docker Compose on `http://127.0.0.1:8080`.

## Azure deployment (automatic on push to main)

After security checks pass, a push to `main` automatically:

1. Builds the Docker image
2. Scans it with Trivy
3. Pushes it to Azure Container Registry
4. Deploys it to Azure Container Apps (running container)
5. Verifies `/healthz` on the live URL

Pull requests run scans and image build only; they do not deploy.

The Terraform stack creates:

- Azure Resource Group
- Azure Container Registry
- Azure Container Apps Environment
- Azure Container App
- Azure Key Vault
- User-assigned Managed Identity
- Log Analytics Workspace
- RBAC assignments for secure ACR and Key Vault access

One-time setup: add these GitHub secrets and a `production` environment:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

See [`docs/auto-deploy.md`](docs/auto-deploy.md) for the full setup guide.

## Project goal

SCAD is not a replacement for GitHub Actions. It is a secure delivery platform built with GitHub Actions, Terraform, Docker, and Azure services to show real-world DevSecOps and cloud architecture practices.

The security data integration layer is documented in [`docs/security-data-integration.md`](docs/security-data-integration.md).

Supply chain controls are documented in [`docs/supply-chain-security.md`](docs/supply-chain-security.md).
