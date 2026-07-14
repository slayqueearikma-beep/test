import { readFileSync } from "node:fs";
import { calculateRiskScore } from "../app/src/risk-scoring.js";
import { normalizeFinding } from "../app/src/findings.js";

function parseArgs(argv) {
  const options = {
    findings: "pipeline-findings.json",
    minimumScore: 60,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--findings") {
      options.findings = argv[index + 1];
      index += 1;
    } else if (arg === "--minimum-score") {
      options.minimumScore = Number(argv[index + 1]);
      index += 1;
    }
  }

  return options;
}

const options = parseArgs(process.argv.slice(2));
const payload = JSON.parse(readFileSync(options.findings, "utf8"));
const findings = (Array.isArray(payload.findings) ? payload.findings : []).map(
  normalizeFinding,
);
const result = calculateRiskScore(findings);

console.log("SCAD risk gate evaluation");
console.log(JSON.stringify(result, null, 2));

if (result.decision === "blocked") {
  console.error("Release blocked by SCAD risk policy.");
  process.exit(1);
}

if (result.score < options.minimumScore) {
  console.error(
    `Risk score ${result.score} is below minimum threshold ${options.minimumScore}.`,
  );
  process.exit(1);
}

console.log(`Risk gate passed with decision: ${result.decision}`);
