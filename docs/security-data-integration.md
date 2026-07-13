# SCAD Security Data Integration and Risk Scoring

SCAD includes a security data integration layer that collects findings from DevSecOps tools, normalizes them into one format, and calculates a risk-based release decision.

## Data flow

```text
CodeQL / Trivy / Checkov / Gitleaks / npm audit
        -> SCAD Findings API
        -> Normalization Engine
        -> Security Findings Store
        -> Risk Scoring Engine
        -> Overall Security Score
        -> Approved / Needs Review / Blocked
```

## Findings API

### Ingest one finding

```http
POST /findings
Content-Type: application/json
X-SCAD-Ingest-Token: <token>
```

```json
{
  "tool": "trivy",
  "category": "container",
  "severity": "HIGH",
  "title": "Vulnerable package in container image",
  "component": "undici",
  "cve": "CVE-2026-12151",
  "cvssScore": 8.1,
  "epssProbability": 0.72,
  "evidence": {
    "image": "scad-api:latest"
  }
}
```

### Ingest many findings

```http
POST /findings/bulk
Content-Type: application/json
X-SCAD-Ingest-Token: <token>
```

```json
{
  "findings": [
    {
      "tool": "gitleaks",
      "category": "secret",
      "severity": "CRITICAL",
      "title": "Cloud credential exposed"
    },
    {
      "tool": "checkov",
      "category": "iac",
      "severity": "HIGH",
      "title": "Public network exposure",
      "evidence": {
        "publicExposure": true
      }
    }
  ]
}
```

## Query endpoints

- `GET /findings` - list normalized findings
- `GET /findings?severity=HIGH` - filter findings by severity
- `GET /findings/summary` - summarize findings by severity, category, and tool
- `GET /security/score` - calculate the release risk score

## Risk scoring model

SCAD starts with a score of `100` and subtracts risk points.

| Signal | Deduction |
|---|---:|
| Low severity | -1 |
| Medium severity | -5 |
| High severity | -15 |
| Critical severity | -30 |
| CVSS >= 7 | -5 |
| CVSS >= 9 | -10 |
| EPSS >= 0.3 | -5 |
| EPSS >= 0.7 | -10 |
| Secret exposure | -50 and blocks release |
| IaC public exposure | -20 |
| Container runs as root | -20 |
| Runtime monitoring disabled | -10 |

## Release decision

| Score | Decision |
|---|---|
| `>= 85` and no blockers | Approved |
| `60-84` and no blockers | Needs Review |
| `< 60` or any blocker | Blocked |

Example response:

```json
{
  "score": 40,
  "riskLevel": "high",
  "decision": "blocked",
  "recommendation": "Fix blocking findings before deploying.",
  "blockers": ["Secret exposure blocks release."]
}
```

This makes SCAD a data-driven DevSecOps platform instead of a simple CI/CD pipeline.
