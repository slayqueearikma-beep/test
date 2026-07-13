import { execSync } from "node:child_process";

function run(command) {
  console.log(`\n> ${command}\n`);
  execSync(command, { stdio: "inherit" });
}

console.log("Deploying SCAD with local Docker...\n");

run("docker compose up --build -d");
run("node scripts/verify-docker.mjs");

console.log("\nDocker deployment complete.");
console.log("API URL: http://127.0.0.1:8080");
console.log("Stop with: npm run docker:down");
