import { execSync } from "node:child_process";

const baseUrl = process.env.SCAD_URL ?? "http://127.0.0.1:8080";
const containerName = process.env.SCAD_CONTAINER ?? "scad-api";

function run(command) {
  return execSync(command, { encoding: "utf8" }).trim();
}

async function sleep(ms) {
  await new Promise((resolve) => setTimeout(resolve, ms));
}

async function waitForHealth(url, attempts = 20, delayMs = 1000) {
  for (let attempt = 1; attempt <= attempts; attempt += 1) {
    try {
      const response = await fetch(url);
      if (!response.ok) {
        throw new Error(`HTTP ${response.status}`);
      }
      return response.json();
    } catch (error) {
      if (attempt === attempts) {
        throw new Error(`Service did not become healthy at ${url}: ${error.message}`);
      }
      await sleep(delayMs);
    }
  }

  throw new Error(`Service did not become healthy at ${url}`);
}

console.log("Verifying SCAD Docker container...\n");

const health = await waitForHealth(`${baseUrl}/healthz`);
console.log(`healthz: ${JSON.stringify(health)}`);

const user = run(`docker exec ${containerName} whoami`);
if (user !== "scad") {
  throw new Error(`Expected non-root user "scad", got "${user}"`);
}
console.log(`user: ${user}`);

try {
  run(`docker exec ${containerName} sh -c "command -v npm"`);
  throw new Error("npm should not be available in the runtime image");
} catch {
  console.log("npm: not present (expected)");
}

let healthStatus = "n/a";
try {
  healthStatus = run(
    `docker inspect ${containerName} --format "{{.State.Health.Status}}"`,
  );
} catch {
  healthStatus = "not configured in compose runtime";
}
console.log(`healthcheck: ${healthStatus}`);

console.log("\nImage verification passed.");
