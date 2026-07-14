import { BlobServiceClient } from "@azure/storage-blob";
import { DefaultAzureCredential } from "@azure/identity";

export function getBlobServiceClient() {
  const accountName = process.env.SCAD_FINOPS_STORAGE_ACCOUNT;
  if (!accountName) {
    throw new Error("SCAD_FINOPS_STORAGE_ACCOUNT is not configured.");
  }

  const credential = new DefaultAzureCredential();
  return new BlobServiceClient(
    `https://${accountName}.blob.core.windows.net`,
    credential,
  );
}

export async function copySummaryToCurated(sourcePath, summary) {
  const client = getBlobServiceClient();
  const curatedContainer = process.env.CURATED_CONTAINER || "curated";
  const container = client.getContainerClient(curatedContainer);
  const blobName = sourcePath.replace(/\//g, "_") + ".summary.json";
  const body = JSON.stringify(summary, null, 2);
  await container.getBlockBlobClient(blobName).upload(body, Buffer.byteLength(body), {
    blobHTTPHeaders: { blobContentType: "application/json" },
  });
  return blobName;
}

export function estimateCsvRows(content) {
  if (!content) {
    return 0;
  }
  return Math.max(content.split("\n").length - 1, 0);
}
