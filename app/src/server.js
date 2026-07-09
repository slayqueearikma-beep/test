import express from "express";
import helmet from "helmet";
import pinoHttp from "pino-http";
import client from "prom-client";
import crypto from "node:crypto";
import { pathToFileURL } from "node:url";
import { defaultFindingsStore } from "./findings.js";
import { calculateRiskScore } from "./risk-scoring.js";

const serviceName = process.env.SERVICE_NAME || "scad-api";
const version = process.env.APP_VERSION || "1.0.0";
const environment = process.env.NODE_ENV || "development";
const port = Number.parseInt(process.env.PORT || "8080", 10);

client.collectDefaultMetrics({
  labels: { service: serviceName },
  prefix: "scad_",
});

const httpRequestDuration = new client.Histogram({
  name: "scad_http_request_duration_seconds",
  help: "HTTP request duration in seconds.",
  labelNames: ["method", "route", "status_code"],
  buckets: [0.01, 0.05, 0.1, 0.3, 0.5, 1, 2, 5],
});

function parseTraceparent(traceparent) {
  const match = /^00-([a-f0-9]{32})-[a-f0-9]{16}-[a-f0-9]{2}$/i.exec(traceparent || "");
  return match ? match[1].toLowerCase() : undefined;
}

function sanitizeTraceId(value) {
  const traceId = String(value || "").trim();
  return /^[A-Za-z0-9_.:-]{8,128}$/.test(traceId) ? traceId : undefined;
}

function createTraceContext(req, res, next) {
  const traceId =
    parseTraceparent(req.headers.traceparent) ||
    sanitizeTraceId(req.headers["x-request-id"]) ||
    sanitizeTraceId(req.headers["x-correlation-id"]) ||
    crypto.randomUUID();

  req.traceId = traceId;
  res.locals.traceId = traceId;
  res.set("X-Request-Id", traceId);
  res.set("X-Correlation-Id", traceId);

  next();
}

function requireIngestToken(req, res, next) {
  const expectedToken = process.env.SCAD_INGEST_TOKEN;

  if (!expectedToken && environment === "production") {
    return res.status(503).json({
      error: "ingest_not_configured",
      message: "SCAD_INGEST_TOKEN must be configured in production.",
    });
  }

  if (expectedToken && req.headers["x-scad-ingest-token"] !== expectedToken) {
    return res.status(401).json({
      error: "unauthorized",
      message: "A valid SCAD ingest token is required.",
    });
  }

  return next();
}

export function createApp({ findingsStore = defaultFindingsStore } = {}) {
  const app = express();

  app.disable("x-powered-by");
  app.use(createTraceContext);
  app.use(helmet());
  app.use(express.json({ limit: "100kb" }));
  app.use(
    pinoHttp({
      genReqId: (req) => req.traceId,
      customProps: (req) => ({
        traceId: req.traceId,
      }),
      redact: ["req.headers.authorization", "req.headers.cookie"],
    }),
  );

  app.use((req, res, next) => {
    const endTimer = httpRequestDuration.startTimer();
    res.on("finish", () => {
      endTimer({
        method: req.method,
        route: req.route?.path || req.path,
        status_code: String(res.statusCode),
      });
    });
    next();
  });

  app.get("/", (_req, res) => {
    res.json({
      name: "SCAD",
      description: "Secure Cloud-Native Application Delivery platform demo API.",
      version,
      environment,
    });
  });

  app.get("/healthz", (_req, res) => {
    res.status(200).json({ status: "healthy" });
  });

  app.get("/readyz", (_req, res) => {
    res.status(200).json({
      status: "ready",
      dependencies: {
        configuration: "loaded",
      },
    });
  });

  app.get("/deployment", (_req, res) => {
    res.json({
      service: serviceName,
      platform: "Azure Container Apps",
      imageTag: process.env.IMAGE_TAG || "local",
      commitSha: process.env.GITHUB_SHA || "local",
      securityControls: [
        "SAST",
        "secret scanning",
        "dependency scanning",
        "IaC scanning",
        "container image scanning",
        "runtime monitoring",
        "security findings normalization",
        "CVSS and EPSS risk scoring",
        "risk-based release decision",
        "request tracing and correlation IDs",
      ],
    });
  });

  app.get("/trace", (req, res) => {
    res.json({
      traceId: req.traceId,
      headers: {
        requestId: res.get("X-Request-Id"),
        correlationId: res.get("X-Correlation-Id"),
      },
    });
  });

  app.get("/findings", (req, res) => {
    res.json({
      findings: findingsStore.list({
        status: req.query.status,
        severity: req.query.severity,
        category: req.query.category,
        tool: req.query.tool,
      }),
    });
  });

  app.post("/findings", requireIngestToken, (req, res, next) => {
    try {
      const finding = findingsStore.add(req.body);
      req.log.info(
        {
          event: "security_finding_ingested",
          findingId: finding.id,
          severity: finding.severity,
          tool: finding.tool,
        },
        "security finding ingested",
      );

      res.status(201).json({ finding });
    } catch (error) {
      next(error);
    }
  });

  app.post("/findings/bulk", requireIngestToken, (req, res, next) => {
    try {
      const findings = findingsStore.addMany(req.body.findings || req.body);
      req.log.info(
        {
          event: "security_findings_bulk_ingested",
          count: findings.length,
        },
        "security findings bulk ingested",
      );

      res.status(201).json({ findings });
    } catch (error) {
      next(error);
    }
  });

  app.get("/findings/summary", (_req, res) => {
    res.json(findingsStore.summary());
  });

  app.get("/security/score", (_req, res) => {
    const findings = findingsStore.list();
    res.json(calculateRiskScore(findings));
  });

  app.get("/metrics", async (_req, res, next) => {
    try {
      res.set("Content-Type", client.register.contentType);
      res.end(await client.register.metrics());
    } catch (error) {
      next(error);
    }
  });

  app.use((req, res) => {
    res.status(404).json({
      error: "not_found",
      message: `Route ${req.method} ${req.path} does not exist.`,
    });
  });

  app.use((error, req, res, _next) => {
    const isClientError = /Finding|requires|payload|must be/i.test(error.message);

    req.log?.warn({ error: error.message }, "request failed");
    res.status(isClientError ? 400 : 500).json({
      error: isClientError ? "bad_request" : "internal_server_error",
      message: environment === "production" && !isClientError ? "Unexpected server error." : error.message,
    });
  });

  return app;
}

const isDirectRun = process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href;

if (isDirectRun) {
  createApp().listen(port, () => {
    console.log(`${serviceName} listening on port ${port}`);
  });
}
