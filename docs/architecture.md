# SCAD Architecture

SCAD means **Secure Cloud-Native Application Delivery**.

## High-level diagram

```mermaid
flowchart LR
    Developer((Developer))
    Repo[GitHub Repository]
    Pipeline[GitHub Actions DevSecOps Pipeline]
    Security[Security Gates<br/>SAST<br/>Secret Scan<br/>Dependency Scan<br/>IaC Scan]
    Build[Docker Image Build]
    ImageScan[Container Image Scan]
    Registry[Azure Container Registry]
    IaC[Terraform Infrastructure as Code]
    Runtime[Azure Container Apps]
    App[SCAD Cloud-Native API]
    Secrets[Azure Key Vault]
    Identity[Managed Identity]
    Observability[Azure Monitor<br/>Log Analytics<br/>Alerts]

    Developer --> Repo --> Pipeline --> Security --> Build --> ImageScan --> Registry --> Runtime --> App
    Pipeline --> IaC --> Runtime
    IaC --> Registry
    IaC --> Secrets
    App --> Identity --> Secrets
    App --> Observability
```

## Detailed flow

1. A developer pushes code to GitHub.
2. GitHub Actions starts the SCAD DevSecOps pipeline.
3. The pipeline installs dependencies, runs linting, runs tests, and audits dependencies.
4. Gitleaks scans the repository for accidental secrets.
5. Terraform is formatted, initialized, validated, and scanned with Checkov.
6. The pipeline builds a Docker image for the API.
7. Trivy scans the image for high and critical vulnerabilities.
8. For manual deployments, Terraform provisions Azure infrastructure.
9. The image is pushed to Azure Container Registry.
10. Azure Container Apps pulls and runs the image using managed identity.
11. The app exposes health, readiness, deployment metadata, and Prometheus metrics endpoints.
12. Logs and metrics are sent to Azure Monitor and Log Analytics.

## Main architecture decisions

- **One repository** keeps the app, pipeline, and infrastructure easy to present.
- **Azure Container Apps** provides a professional cloud-native runtime without the operational overhead of AKS.
- **Terraform** demonstrates infrastructure as code and repeatable deployments.
- **Managed Identity** avoids hardcoded cloud credentials in application code.
- **Key Vault** centralizes secrets for future app integrations.
- **Security gates** stop vulnerable code, leaked secrets, insecure IaC, or vulnerable images before deployment.

## Production hardening roadmap

For a real enterprise deployment, the next controls to add are:

- Private endpoints for Key Vault and Azure Container Registry
- Disabled public network access for sensitive services
- Premium ACR with zone redundancy and geo-replication
- Defender for Cloud registry vulnerability assessment
- Network-isolated Container Apps environment
- Centralized alert routing to an incident response channel

The first SCAD version keeps the cloud footprint smaller so it is easier to deploy, demo, and explain as a portfolio project.
