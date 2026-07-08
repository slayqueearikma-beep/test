import crypto from "node:crypto";

const allowedStatuses = new Set(["open", "accepted", "fixed", "false_positive"]);
const severityOrder = ["LOW", "MEDIUM", "HIGH", "CRITICAL"];

function normalizeSeverity(severity) {
  const normalized = String(severity || "LOW").toUpperCase();
  return severityOrder.includes(normalized) ? normalized : "LOW";
}

function normalizeNumber(value, fallback = undefined) {
  if (value === undefined || value === null || value === "") {
    return fallback;
  }

  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function normalizeStatus(status) {
  const normalized = String(status || "open").toLowerCase();
  return allowedStatuses.has(normalized) ? normalized : "open";
}

export function normalizeFinding(input) {
  if (!input || typeof input !== "object" || Array.isArray(input)) {
    throw new Error("Finding must be a JSON object.");
  }

  if (!input.tool || !input.title) {
    throw new Error("Finding requires at least 'tool' and 'title'.");
  }

  const now = new Date().toISOString();
  const severity = normalizeSeverity(input.severity);
  const epssProbability = normalizeNumber(input.epssProbability, 0);
  const cvssScore = normalizeNumber(input.cvssScore);

  return {
    id: input.id || crypto.randomUUID(),
    tool: String(input.tool),
    category: String(input.category || "unknown"),
    severity,
    title: String(input.title),
    component: input.component ? String(input.component) : undefined,
    cve: input.cve ? String(input.cve) : undefined,
    cvssScore,
    epssProbability: Math.min(Math.max(epssProbability, 0), 1),
    status: normalizeStatus(input.status),
    source: String(input.source || "manual"),
    commitSha: String(input.commitSha || process.env.GITHUB_SHA || "local"),
    environment: String(input.environment || process.env.NODE_ENV || "development"),
    evidence: input.evidence && typeof input.evidence === "object" ? input.evidence : {},
    createdAt: input.createdAt || now,
    updatedAt: now,
  };
}

export class FindingsStore {
  #findings = new Map();

  add(input) {
    const finding = normalizeFinding(input);
    this.#findings.set(finding.id, finding);
    return finding;
  }

  addMany(inputs) {
    if (!Array.isArray(inputs)) {
      throw new Error("Bulk findings payload must be an array.");
    }

    return inputs.map((input) => this.add(input));
  }

  list({ status, severity, category, tool } = {}) {
    return [...this.#findings.values()].filter((finding) => {
      return (
        (!status || finding.status === status) &&
        (!severity || finding.severity === normalizeSeverity(severity)) &&
        (!category || finding.category === category) &&
        (!tool || finding.tool === tool)
      );
    });
  }

  summary() {
    const findings = this.list();
    const bySeverity = Object.fromEntries(severityOrder.map((severity) => [severity, 0]));
    const byCategory = {};
    const byTool = {};

    for (const finding of findings) {
      bySeverity[finding.severity] += 1;
      byCategory[finding.category] = (byCategory[finding.category] || 0) + 1;
      byTool[finding.tool] = (byTool[finding.tool] || 0) + 1;
    }

    return {
      total: findings.length,
      open: findings.filter((finding) => finding.status === "open").length,
      fixed: findings.filter((finding) => finding.status === "fixed").length,
      bySeverity,
      byCategory,
      byTool,
    };
  }

  clear() {
    this.#findings.clear();
  }
}

export const defaultFindingsStore = new FindingsStore();
