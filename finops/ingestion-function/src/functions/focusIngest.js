import { app } from "@azure/functions";
import { getBlobServiceClient, copySummaryToCurated, estimateCsvRows } from "../shared/storage.js";
import { ensureSchema, insertCostFile } from "../shared/sql.js";

function parseBlobUrl(subject) {
  const match = subject?.match(/\/blobServices\/default\/containers\/([^/]+)\/blobs\/(.+)$/);
  if (!match) {
    return null;
  }
  return { container: match[1], blobPath: decodeURIComponent(match[2]) };
}

function detectExportType(blobPath) {
  if (blobPath.includes("focus-parquet")) return "FocusCost";
  if (blobPath.includes("actual-cost")) return "ActualCost";
  if (blobPath.includes("usage")) return "Usage";
  return "Unknown";
}

app.eventGrid("FocusIngest", {
  handler: async (event, context) => {
    const parsed = parseBlobUrl(event.subject);
    if (!parsed) {
      context.log("Skipping unsupported event subject", event.subject);
      return;
    }

    await ensureSchema();
    const exportType = detectExportType(parsed.blobPath);
    const client = getBlobServiceClient();
    const blobClient = client
      .getContainerClient(parsed.container)
      .getBlockBlobClient(parsed.blobPath);

    let rowEstimate = 0;
    if (parsed.blobPath.endsWith(".csv")) {
      const download = await blobClient.download();
      const content = await streamToString(download.readableStreamBody);
      rowEstimate = estimateCsvRows(content);
    }

    await insertCostFile({
      blobPath: `${parsed.container}/${parsed.blobPath}`,
      exportType,
      rowEstimate,
    });

    const summaryBlob = await copySummaryToCurated(parsed.blobPath, {
      exportType,
      rowEstimate,
      source: `${parsed.container}/${parsed.blobPath}`,
      ingestedAt: new Date().toISOString(),
    });

    context.log(`Ingested cost file ${parsed.blobPath} (${exportType}) -> ${summaryBlob}`);
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
