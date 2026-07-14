import { execSync } from "node:child_process";
import { readFileSync, existsSync, writeFileSync } from "node:fs";
import { calculateRiskScore } from "../app/src/risk-scoring.js";
import { normalizeFinding } from "../app/src/findings.js";

function parseArgs(argv) {
  const options = {
    storageAccount: process.env.SCAD_FINOPS_STORAGE_ACCOUNT || "",
    container: process.env.SCAD_FINOPS_PIPELINE_CONTAINER || "pipeline-metrics",
    workflow: process.env.GITHUB_WORKFLOW || "local",
    runId: process.env.GITHUB_RUN_ID || `local-${Date.now()}`,
    status: process.env.GITHUB_JOB_STATUS || "completed",
    conclusion: process.env.PIPELINE_CONCLUSION || "success",
    commitSha: process.env.GITHUB_SHA || "local",
    environment: process.env.DEPLOYMENT_ENVIRONMENT || "ci",
    durationSeconds: Number(process.env.PIPELINE_DURATION_SECONDS || 0),
    riskScore: process.env.PIPELINE_RISK_SCORE
      ? Number(process.env.PIPELINE_RISK_SCORE)
      : null,
    riskDecision: process.env.PIPELINE_RISK_DECISION || null,
    findingsFile: process.env.PIPELINE_FINDINGS_FILE || "",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--storage-account") {
      options.storageAccount = argv[index + 1];
      index += 1;
    }
  }

  return options;
}

const options = parseArgs(process.argv.slice(2));

if (!options.storageAccount) {
  throw new Error(
    "SCAD_FINOPS_STORAGE_ACCOUNT is required. Set it from Terraform output finops_storage_account_name.",
  );
}

if (options.findingsFile && existsSync(options.findingsFile)) {
  try {
    const findings = JSON.parse(readFileSync(options.findingsFile, "utf8"));
    const normalized = (findings.findings || []).map(normalizeFinding);
    const score = calculateRiskScore(normalized);
    options.riskScore = score.score;
    options.riskDecision = score.decision;
  } catch (error) {
    console.warn("Could not compute risk score from findings file:", error.message);
  }
}

const payload = {
  workflow: options.workflow,
  runId: options.runId,
  status: options.status,
  conclusion: options.conclusion,
  durationSeconds: options.durationSeconds,
  riskScore: options.riskScore,
  riskDecision: options.riskDecision,
  commitSha: options.commitSha,
  environment: options.environment,
  recordedAt: new Date().toISOString(),
};

const blobName = `${options.runId}.json`;
const tempFile = `/tmp/${blobName}`;
writeFileSync(tempFile, JSON.stringify(payload, null, 2));

const command = [
  "az storage blob upload",
  `--account-name ${options.storageAccount}`,
  `--container-name ${options.container}`,
  `--name ${blobName}`,
  `--file ${tempFile}`,
  "--auth-mode login",
  "--overwrite",
].join(" ");

console.log(`Publishing pipeline metrics to ${options.storageAccount}/${options.container}/${blobName}`);
execSync(command, { stdio: "inherit" });
console.log("Pipeline metrics published.");
