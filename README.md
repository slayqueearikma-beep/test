# SCAD - Secure Cloud-Native Application Delivery

SCAD is a DevSecOps portfolio project that demonstrates how to test, scan, containerize, and deploy a cloud-native application to Azure using automated security controls.

The project is designed for a DevSecOps / Cloud Architect profile. It combines application delivery, infrastructure as code, container security, secret management, observability, security data integration, and risk-based release decisions in one repository.

## Architecture flow

```text
Developer
  -> GitHub Repository
  -> GitHub Actions DevSecOps Pipeline
  -> SAST / Secret / Dependency / IaC Scans
  -> Docker Image Build
  -> Container Image Scan
  -> Azure Container Registry
  -> Azure Container Apps
  -> Azure Monitor / Log Analytics / Alerts
  -> Security Findings API
  -> Risk Scoring Engine
  -> Approved / Needs Review / Blocked
```

## Repository structure

```text
.
├── app/                         # SCAD demo API
│   ├── src/server.js             # Express API with health, readiness, and metrics
│   ├── test/server.test.js        # Node.js tests
│   └── Dockerfile                # Production container image
├── infrastructure/terraform/     # Azure infrastructure as code
├── .github/workflows/            # DevSecOps CI/CD pipeline
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
- Optional Azure deployment through GitHub Actions OIDC credentials
- Security findings normalization API
- CVSS, EPSS, and policy-based risk scoring
- Automated release decision: approved, needs review, or blocked
- Request tracing with `X-Request-Id`, `X-Correlation-Id`, and W3C `traceparent` support

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
- `GET /trace` - shows the current request trace ID and correlation headers
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

Every API response includes:

```http
X-Request-Id: <trace-id>
X-Correlation-Id: <trace-id>
```

Send your own trace ID with `X-Request-Id`, `X-Correlation-Id`, or a W3C `traceparent` header to correlate API responses with logs and monitoring events.

## Docker

```bash
docker build -t scad-api:local -f app/Dockerfile app
docker run --rm -p 8080:8080 scad-api:local
```

## Azure deployment

The Terraform stack creates:

- Azure Resource Group
- Azure Container Registry
- Azure Container Apps Environment
- Azure Container App
- Azure Key Vault
- User-assigned Managed Identity
- Log Analytics Workspace
- RBAC assignments for secure ACR and Key Vault access

Deployment is designed to run from the `SCAD DevSecOps Pipeline` workflow using these GitHub secrets:

- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`
- `AZURE_SUBSCRIPTION_ID`

## Project goal

SCAD is not a replacement for GitHub Actions. It is a secure delivery platform built with GitHub Actions, Terraform, Docker, and Azure services to show real-world DevSecOps and cloud architecture practices.

The security data integration layer is documented in [`docs/security-data-integration.md`](docs/security-data-integration.md).

The security-gated CI/CD structure and custom SCAD risk-score action are documented in [`docs/security-gated-cicd.md`](docs/security-gated-cicd.md).
