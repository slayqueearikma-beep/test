# Supply chain security in SCAD

SCAD extends the DevSecOps pipeline with software supply chain controls so builds are traceable, signed, and verifiable before deployment.

## Pipeline flow

```text
Build image
  -> Trivy scan
  -> Syft SBOM (SPDX)
  -> Upload SBOM artifact
  -> Cosign sign image
  -> Attach SBOM attestation
  -> SLSA build provenance attestation
  -> (on main) push to ACR
  -> Cosign sign production image
  -> Verify signature before deploy
  -> Azure Container Apps rollout
```

## Controls

| Control | Tool | When |
|---------|------|------|
| SBOM | Syft (`anchore/sbom-action`) | Every build |
| Vulnerability scan | Trivy | Every build |
| Image signing | Cosign keyless (Sigstore) | Every build; again on ACR push |
| SBOM attestation | Cosign attest (SPDX) | Every build |
| Build provenance | GitHub `attest-build-provenance` | Every build |
| Signature verification | Cosign verify | Before Azure deploy |

## Where to find artifacts

### SBOM

Open a workflow run -> **Build and scan image** -> **Artifacts** -> `sbom-scad-api-<commit-sha>`.

### Signatures and provenance

- Cosign signatures are stored with the image digest in the CI runner and registry flow.
- Build provenance appears under the workflow run **Attestations** tab in GitHub.

## Deploy policy

Production deploy on `main` only proceeds when:

1. Security scans pass
2. Trivy reports no blocking CRITICAL/HIGH issues
3. Image is pushed to ACR
4. Cosign signature is created for the production image
5. `cosign verify` succeeds for the expected GitHub Actions identity

## Identity used for verification

Deploy verifies signatures issued by:

- **Issuer:** `https://token.actions.githubusercontent.com`
- **Identity:** workflow in this repository (`https://github.com/<owner>/<repo>/...`)

## Local development

Local Docker runs (`npm run deploy:docker`) do not produce Cosign signatures. Supply chain gates are enforced in GitHub Actions CI/CD.

## Future improvements

- Pin base images by digest in `app/Dockerfile`
- Policy engine (OPA/Kyverno) requiring signed images in cluster
- Store SBOM in ACR as OCI referrer artifact
- SLSA Level 3 hardening with isolated build runners
