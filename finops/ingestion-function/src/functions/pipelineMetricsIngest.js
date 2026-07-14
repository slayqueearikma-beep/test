import { app } from "@azure/functions";
import { getBlobServiceClient, copySummaryToCurated } from "../shared/storage.js";
import { ensureSchema, insertPipelineRun } from "../shared/sql.js";

function parseBlobUrl(subject) {
  const match = subject?.match(/\/blobServices\/default\/containers\/([^/]+)\/blobs\/(.+)$/);
  if (!match) {
    return null;
  }
  return { container: match[1], blobPath: decodeURIComponent(match[2]) };
}

app.eventGrid("PipelineMetricsIngest", {
  handler: async (event, context) => {
    const parsed = parseBlobUrl(event.subject);
    if (!parsed) {
      context.log("Skipping unsupported event subject", event.subject);
      return;
    }

    await ensureSchema();
    const client = getBlobServiceClient();
    const download = await client
      .getContainerClient(parsed.container)
      .getBlockBlobClient(parsed.blobPath)
      .download();
    const content = await streamToString(download.readableStreamBody);
    const payload = JSON.parse(content);

    await insertPipelineRun({
      workflow: payload.workflow,
      runId: payload.runId,
      status: payload.status,
      conclusion: payload.conclusion,
      durationSeconds: payload.durationSeconds,
      riskScore: payload.riskScore,
      riskDecision: payload.riskDecision,
      commitSha: payload.commitSha,
      environment: payload.environment,
    });

    const summaryBlob = await copySummaryToCurated(parsed.blobPath, {
      type: "pipeline-metrics",
      ...payload,
      ingestedAt: new Date().toISOString(),
    });

    context.log(`Ingested pipeline metrics ${parsed.blobPath} -> ${summaryBlob}`);
  },
});

async function streamToString(readableStream) {
  if (!readableStream) {
    return "";
  }
  const chunks = [];
  for await (const chunk of readableStream) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}
