import express from "express";
import helmet from "helmet";
import pinoHttp from "pino-http";
import client from "prom-client";
import { pathToFileURL } from "node:url";

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

export function createApp() {
  const app = express();

  app.disable("x-powered-by");
  app.use(helmet());
  app.use(express.json({ limit: "100kb" }));
  app.use(
    pinoHttp({
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
      ],
    });
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

  app.use((error, _req, res, _next) => {
    res.status(500).json({
      error: "internal_server_error",
      message: environment === "production" ? "Unexpected server error." : error.message,
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
