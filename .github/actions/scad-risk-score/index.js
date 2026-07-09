const fs = require("node:fs");
const path = require("node:path");

const severityDeductions = {
  LOW: 1,
  MEDIUM: 5,
  HIGH: 15,
  CRITICAL: 30,
};

function getInput(name, fallback = "") {
  const upperName = name.toUpperCase();
  return (
    process.env[`INPUT_${upperName}`] ||
    process.env[`INPUT_${upperName.replace(/-/g, "_")}`] ||
    fallback
  );
}

function setOutput(name, value) {
  if (!process.env.GITHUB_OUTPUT) {
    return;
  }

  fs.appendFileSync(process.env.GITHUB_OUTPUT, `${name}=${value}\n`);
}

function appendSummary(markdown) {
  if (!process.env.GITHUB_STEP_SUMMARY) {
    return;
  }

  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${markdown}\n`);
}

function normalizeSeverity(severity) {
  const normalized = String(severity || "LOW").toUpperCase();
  return Object.hasOwn(severityDeductions, normalized) ? normalized : "LOW";
}

function normalizeFindings(raw) {
  const parsed = JSON.parse(raw);
  const findings = Array.isArray(parsed) ? parsed : parsed.findings || [];

  if (!Array.isArray(findings)) {
    throw new Error("Findings file must contain an array or an object with a findings array.");
  }

  return findings.map((finding, index) => ({
    id: finding.id || `finding-${index + 1}`,
    tool: String(finding.tool || "unknown"),
    category: String(finding.category || "unknown").toLowerCase(),
    severity: normalizeSeverity(finding.severity),
    title: String(finding.title || "Untitled security finding"),
    cvssScore: Number(finding.cvssScore || 0),
    epssProbability: Number(finding.epssProbability || 0),
    status: String(finding.status || "open").toLowerCase(),
    evidence: finding.evidence && typeof finding.evidence === "object" ? finding.evidence : {},
  }));
}

function epssDeduction(epssProbability) {
  if (epssProbability >= 0.7) {
    return 10;
  }

  if (epssProbability >= 0.3) {
    return 5;
  }

  return 0;
}

function cvssDeduction(cvssScore) {
  if (cvssScore >= 9) {
    return 10;
  }

  if (cvssScore >= 7) {
    return 5;
  }

  return 0;
}

function policyDeductions(finding) {
  let deduction = 0;
  const blockers = [];
  const reasons = [];

  if (finding.category === "secret") {
    deduction += 50;
    blockers.push("Secret exposure blocks release.");
    reasons.push("Secret exposure policy: -50");
  }

  if (finding.category === "pipeline" && finding.evidence.failedGate === true) {
    deduction += 35;
    blockers.push(`Required pipeline gate failed: ${finding.tool}.`);
    reasons.push("Failed required security gate: -35");
  }

  if (finding.category === "iac" && finding.evidence.publicExposure === true) {
    deduction += 20;
    reasons.push("IaC public exposure policy: -20");
  }

  if (finding.category === "container" && finding.evidence.runsAsRoot === true) {
    deduction += 20;
    reasons.push("Container runs as root policy: -20");
  }

  return { deduction, blockers, reasons };
}

function scoreFinding(finding) {
  if (finding.status === "fixed" || finding.status === "false_positive") {
    return null;
  }

  const severityDeduction = severityDeductions[finding.severity] || 0;
  const cvss = cvssDeduction(finding.cvssScore);
  const epss = epssDeduction(finding.epssProbability);
  const policy = policyDeductions(finding);
  const deduction = severityDeduction + cvss + epss + policy.deduction;

  return {
    ...finding,
    deduction,
    blockers: policy.blockers,
    reasons: [
      `${finding.severity} severity: -${severityDeduction}`,
      finding.cvssScore ? `CVSS ${finding.cvssScore}: -${cvss}` : undefined,
      finding.epssProbability ? `EPSS ${finding.epssProbability}: -${epss}` : undefined,
      ...policy.reasons,
    ].filter(Boolean),
  };
}

function classify(score, blockers, minimumScore) {
  if (blockers.length > 0 || score < 60) {
    return {
      riskLevel: "high",
      decision: "blocked",
      recommendation: "Fix blocking security findings before deployment.",
    };
  }

  if (score < minimumScore) {
    return {
      riskLevel: "medium",
      decision: "needs_review",
      recommendation: "Manual security review is required before deployment.",
    };
  }

  return {
    riskLevel: "low",
    decision: "approved",
    recommendation: "Security gates passed. Deployment can continue.",
  };
}

function calculateRisk(findings, minimumScore) {
  const scoredFindings = findings.map(scoreFinding).filter(Boolean);
  const totalDeduction = scoredFindings.reduce((sum, finding) => sum + finding.deduction, 0);
  const score = Math.max(0, 100 - totalDeduction);
  const blockers = scoredFindings.flatMap((finding) => finding.blockers);
  const classification = classify(score, blockers, minimumScore);

  return {
    score,
    ...classification,
    blockers,
    deductions: scoredFindings.sort((left, right) => right.deduction - left.deduction),
  };
}

function renderReport(result, minimumScore) {
  const rows = result.deductions
    .map(
      (finding) =>
        `| ${finding.severity} | ${finding.category} | ${finding.tool} | ${finding.deduction} | ${finding.title} |`,
    )
    .join("\n");
  const findingsTable = rows
    ? `| Severity | Category | Tool | Deduction | Title |
|---|---|---|---:|---|
${rows}`
    : "No active findings.";

  return `# SCAD Security Risk Report

| Field | Value |
|---|---|
| Score | ${result.score}/100 |
| Minimum score | ${minimumScore} |
| Risk level | ${result.riskLevel} |
| Decision | ${result.decision} |
| Recommendation | ${result.recommendation} |

## Findings

${findingsTable}
`;
}

function main() {
  const findingsFile = getInput("findings-file");
  const minimumScore = Number(getInput("minimum-score", "85"));
  const reportFile = getInput("report-file", "scad-risk-report.md");

  if (!findingsFile) {
    throw new Error("findings-file input is required.");
  }

  if (!Number.isFinite(minimumScore) || minimumScore < 0 || minimumScore > 100) {
    throw new Error("minimum-score must be a number from 0 to 100.");
  }

  const absoluteFindingsFile = path.resolve(process.cwd(), findingsFile);
  const raw = fs.readFileSync(absoluteFindingsFile, "utf8");
  const findings = normalizeFindings(raw);
  const result = calculateRisk(findings, minimumScore);
  const report = renderReport(result, minimumScore);

  fs.writeFileSync(reportFile, report);
  appendSummary(report);

  setOutput("score", result.score);
  setOutput("decision", result.decision);
  setOutput("risk-level", result.riskLevel);
  setOutput("report-file", reportFile);

  console.log(`SCAD Security Score: ${result.score}/100`);
  console.log(`Risk Level: ${result.riskLevel}`);
  console.log(`Decision: ${result.decision}`);
  console.log(`Report: ${reportFile}`);

  if (result.decision === "blocked") {
    throw new Error("SCAD release blocked because required security gates failed or risk is too high.");
  }

  if (result.decision === "needs_review") {
    throw new Error(`SCAD score ${result.score} is below the minimum required score ${minimumScore}.`);
  }
}

try {
  main();
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
