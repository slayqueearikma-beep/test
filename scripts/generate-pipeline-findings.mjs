import { writeFileSync } from "node:fs";
import { execSync } from "node:child_process";

function parseArgs(argv) {
  const options = {
    output: "pipeline-findings.json",
    commit: "local",
    ref: "local",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--output") {
      options.output = argv[index + 1];
      index += 1;
    } else if (arg === "--commit") {
      options.commit = argv[index + 1];
      index += 1;
    } else if (arg === "--ref") {
      options.ref = argv[index + 1];
      index += 1;
    }
  }

  return options;
}

function severityFromAudit(level) {
  const normalized = String(level || "low").toLowerCase();
  if (normalized === "critical") return "CRITICAL";
  if (normalized === "high") return "HIGH";
  if (normalized === "moderate") return "MEDIUM";
  return "LOW";
}

function findingsFromAudit() {
  try {
    const audit = JSON.parse(execSync("npm audit --json", { encoding: "utf8" }));
    const vulnerabilities = Object.values(audit.vulnerabilities || {});

    return vulnerabilities.slice(0, 25).map((entry) => ({
      tool: "npm-audit",
      category: "dependency",
      severity: severityFromAudit(entry.severity),
      title: entry.name || "Vulnerable dependency",
      component: entry.name,
      evidence: {
        range: entry.range,
        via: entry.via,
      },
    }));
  } catch {
    return [
      {
        tool: "npm-audit",
        category: "dependency",
        severity: "HIGH",
        title: "Dependency audit reported vulnerabilities",
        evidence: {
          source: "npm audit",
        },
      },
    ];
  }
}

const options = parseArgs(process.argv.slice(2));
const findings = [
  ...findingsFromAudit(),
  {
    tool: "github-actions",
    category: "pipeline",
    severity: "LOW",
    title: "Pipeline findings snapshot generated",
    evidence: {
      commit: options.commit,
      ref: options.ref,
      generatedAt: new Date().toISOString(),
    },
  },
];

writeFileSync(
  options.output,
  JSON.stringify(
    {
      generatedAt: new Date().toISOString(),
      commit: options.commit,
      ref: options.ref,
      findings,
    },
    null,
    2,
  ),
);

console.log(`Wrote ${findings.length} pipeline findings to ${options.output}`);
