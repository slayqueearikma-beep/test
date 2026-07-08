const severityDeductions = {
  LOW: 1,
  MEDIUM: 5,
  HIGH: 15,
  CRITICAL: 30,
};

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

function policyDeduction(finding) {
  const category = finding.category.toLowerCase();
  const evidence = finding.evidence || {};
  let deduction = 0;
  const blockers = [];

  if (category === "secret") {
    deduction += 50;
    blockers.push("Secret exposure blocks release.");
  }

  if (category === "iac" && evidence.publicExposure === true) {
    deduction += 20;
  }

  if (category === "container" && evidence.runsAsRoot === true) {
    deduction += 20;
  }

  if (category === "runtime" && evidence.monitoringDisabled === true) {
    deduction += 10;
  }

  return { deduction, blockers };
}

function scoreFinding(finding) {
  const severityDeduction = severityDeductions[finding.severity] || 0;
  const exploitDeduction = epssDeduction(finding.epssProbability);
  const technicalDeduction = cvssDeduction(finding.cvssScore || 0);
  const policy = policyDeduction(finding);
  const totalDeduction =
    severityDeduction + exploitDeduction + technicalDeduction + policy.deduction;

  return {
    findingId: finding.id,
    title: finding.title,
    severity: finding.severity,
    category: finding.category,
    deduction: totalDeduction,
    reasons: [
      `${finding.severity} severity: -${severityDeduction}`,
      finding.cvssScore ? `CVSS ${finding.cvssScore}: -${technicalDeduction}` : undefined,
      finding.epssProbability ? `EPSS ${finding.epssProbability}: -${exploitDeduction}` : undefined,
      policy.deduction ? `SCAD policy rules: -${policy.deduction}` : undefined,
    ].filter(Boolean),
    blockers: policy.blockers,
  };
}

function classifyDecision(score, blockers) {
  if (blockers.length > 0 || score < 60) {
    return {
      riskLevel: "high",
      decision: "blocked",
      recommendation: "Fix blocking findings before deploying.",
    };
  }

  if (score < 85) {
    return {
      riskLevel: "medium",
      decision: "needs_review",
      recommendation: "Security review is required before deployment.",
    };
  }

  return {
    riskLevel: "low",
    decision: "approved",
    recommendation: "Deployment can continue.",
  };
}

export function calculateRiskScore(findings) {
  const activeFindings = findings.filter(
    (finding) => finding.status !== "fixed" && finding.status !== "false_positive",
  );
  const scoredFindings = activeFindings.map(scoreFinding);
  const totalDeduction = scoredFindings.reduce((sum, finding) => sum + finding.deduction, 0);
  const score = Math.max(0, 100 - totalDeduction);
  const blockers = scoredFindings.flatMap((finding) => finding.blockers);
  const classification = classifyDecision(score, blockers);

  return {
    score,
    maxScore: 100,
    riskLevel: classification.riskLevel,
    decision: classification.decision,
    recommendation: classification.recommendation,
    blockers,
    activeFindings: activeFindings.length,
    deductions: scoredFindings.sort((left, right) => right.deduction - left.deduction),
    model: {
      name: "SCAD Risk Scoring Engine",
      version: "1.0",
      inputs: ["severity", "CVSS", "EPSS", "SCAD policy rules"],
      thresholds: {
        approved: "score >= 85 and no blockers",
        needsReview: "60 <= score < 85 and no blockers",
        blocked: "score < 60 or any blocker",
      },
    },
  };
}
