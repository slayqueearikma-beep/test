import assert from "node:assert/strict";
import { after, before, test } from "node:test";
import { createApp } from "../src/server.js";
import { FindingsStore } from "../src/findings.js";

let server;
let baseUrl;
let findingsStore;

before(async () => {
  findingsStore = new FindingsStore();
  server = createApp({ findingsStore }).listen(0);
  await new Promise((resolve) => server.once("listening", resolve));
  const { port } = server.address();
  baseUrl = `http://127.0.0.1:${port}`;
});

after(async () => {
  await new Promise((resolve, reject) => {
    server.close((error) => (error ? reject(error) : resolve()));
  });
});

test("returns service metadata", async () => {
  const response = await fetch(`${baseUrl}/`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.name, "SCAD");
  assert.match(body.description, /Secure Cloud-Native/);
});

test("exposes health and readiness probes", async () => {
  const health = await fetch(`${baseUrl}/healthz`);
  const ready = await fetch(`${baseUrl}/readyz`);

  assert.equal(health.status, 200);
  assert.equal(ready.status, 200);
  assert.deepEqual(await health.json(), { status: "healthy" });
});

test("adds a generated request trace id to responses", async () => {
  const response = await fetch(`${baseUrl}/trace`);
  const body = await response.json();
  const responseTraceId = response.headers.get("x-request-id");

  assert.equal(response.status, 200);
  assert.ok(responseTraceId);
  assert.equal(body.traceId, responseTraceId);
  assert.equal(response.headers.get("x-correlation-id"), responseTraceId);
});

test("propagates client-provided request trace id", async () => {
  const traceId = "demo-trace-12345";
  const response = await fetch(`${baseUrl}/trace`, {
    headers: {
      "x-request-id": traceId,
    },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-request-id"), traceId);
  assert.equal(body.traceId, traceId);
});

test("extracts W3C traceparent trace id", async () => {
  const traceId = "4bf92f3577b34da6a3ce929d0e0e4736";
  const response = await fetch(`${baseUrl}/trace`, {
    headers: {
      traceparent: `00-${traceId}-00f067aa0ba902b7-01`,
    },
  });
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(response.headers.get("x-request-id"), traceId);
  assert.equal(body.traceId, traceId);
});

test("exposes Prometheus metrics", async () => {
  const response = await fetch(`${baseUrl}/metrics`);
  const body = await response.text();

  assert.equal(response.status, 200);
  assert.match(response.headers.get("content-type"), /text\/plain/);
  assert.match(body, /scad_process_cpu_user_seconds_total/);
});

test("ingests normalized security findings", async () => {
  const response = await fetch(`${baseUrl}/findings`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      tool: "trivy",
      category: "container",
      severity: "high",
      title: "Vulnerable package in container image",
      component: "undici",
      cve: "CVE-2026-12151",
      cvssScore: 8.1,
      epssProbability: 0.72,
    }),
  });
  const body = await response.json();

  assert.equal(response.status, 201);
  assert.equal(body.finding.severity, "HIGH");
  assert.equal(body.finding.tool, "trivy");
  assert.equal(body.finding.status, "open");
});

test("summarizes security findings by severity and tool", async () => {
  const response = await fetch(`${baseUrl}/findings/summary`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.total, 1);
  assert.equal(body.bySeverity.HIGH, 1);
  assert.equal(body.byTool.trivy, 1);
});

test("calculates risk score and release decision", async () => {
  await fetch(`${baseUrl}/findings`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({
      tool: "gitleaks",
      category: "secret",
      severity: "critical",
      title: "Cloud credential exposed in repository",
      evidence: { file: ".env" },
    }),
  });

  const response = await fetch(`${baseUrl}/security/score`);
  const body = await response.json();

  assert.equal(response.status, 200);
  assert.equal(body.model.name, "SCAD Risk Scoring Engine");
  assert.equal(body.decision, "blocked");
  assert.equal(body.riskLevel, "high");
  assert.ok(body.score < 60);
  assert.ok(body.blockers.includes("Secret exposure blocks release."));
});

test("rejects malformed findings", async () => {
  const response = await fetch(`${baseUrl}/findings`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ tool: "codeql" }),
  });
  const body = await response.json();

  assert.equal(response.status, 400);
  assert.equal(body.error, "bad_request");
});

test("returns JSON 404 responses", async () => {
  const response = await fetch(`${baseUrl}/missing`);
  const body = await response.json();

  assert.equal(response.status, 404);
  assert.equal(body.error, "not_found");
});
