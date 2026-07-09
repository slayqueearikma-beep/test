# SCAD Security-Gated CI/CD Pipeline

This branch adds a dedicated CI/CD workflow that verifies code pushed by a developer through layered security gates.

Workflow file:

```text
.github/workflows/scad-security-gated-cicd.yml
```

Custom local action:

```text
.github/actions/scad-risk-score/
```

## Pipeline structure

```text
Developer push / pull request
        |
        v
Layer 0 - Repository Structure Gate
        |
        +--> Layer 1 - Code Quality and Dependency Safety
        +--> Layer 2 - Secret Exposure Scanning
        +--> Layer 3 - SAST
        +--> Layer 4 - IaC Security
        +--> Layer 5 - Container Security
        |
        v
Layer 6 - SCAD Risk Score Release Gate
        |
        v
Approved / Needs Review / Blocked
```

## Security layers

### Layer 0 - Repository Structure Gate

Checks that the project keeps the expected professional structure:

- application code exists
- tests exist
- Dockerfile exists
- Terraform files exist
- CI/CD workflow exists
- local secret files like `.env`, `.pem`, and private keys are not tracked

### Layer 1 - Code Quality and Dependency Safety

Runs:

```bash
npm ci
npm run lint
npm test
npm audit --audit-level=high
```

This verifies that developer code is installable, testable, lint-clean, and does not contain high-risk dependency vulnerabilities.

### Layer 2 - Secret Exposure Scanning

Runs Gitleaks against repository history.

This blocks accidental commits of:

- API keys
- passwords
- cloud credentials
- private keys

### Layer 3 - SAST

Runs CodeQL static analysis for JavaScript/TypeScript.

This checks source code for insecure patterns before deployment.

### Layer 4 - IaC Security

Runs Terraform validation and Checkov.

This checks that Azure infrastructure definitions are syntactically valid and do not contain unsafe starter-project misconfigurations.

### Layer 5 - Container Security

Builds the Docker image and scans it with Trivy.

This blocks images with high or critical vulnerabilities.

### Layer 6 - SCAD Risk Score Release Gate

The final job runs even if earlier gates fail.

It converts failed gates into normalized SCAD findings:

```json
{
  "tool": "container-gate",
  "category": "container",
  "severity": "CRITICAL",
  "title": "Container image security gate failed",
  "evidence": {
    "failedGate": true
  }
}
```

Then the local custom action calculates:

- score from `0` to `100`
- risk level
- decision
- markdown report

Decision logic:

| Result | Meaning |
|---|---|
| Approved | All security gates passed and score is high enough |
| Needs Review | Risk is medium and requires manual review |
| Blocked | A required security gate failed or the risk is too high |

## Why this is useful

This pipeline does not only run tools. It organizes them into security layers and turns the result into a release decision.

That demonstrates:

- secure CI/CD design
- shift-left security
- DevSecOps governance
- reusable GitHub Actions
- risk-based deployment control
