import { execSync } from "node:child_process";

const tfDir = "infrastructure/terraform";
const imageTag = process.env.IMAGE_TAG ?? `local-${Date.now()}`;

function run(command, options = {}) {
  console.log(`\n> ${command}\n`);
  execSync(command, { stdio: "inherit", ...options });
}

function runCapture(command, options = {}) {
  return execSync(command, { encoding: "utf8", ...options }).trim();
}

function commandExists(name) {
  try {
    const check =
      process.platform === "win32" ? `where ${name}` : `command -v ${name}`;
    execSync(check, { stdio: "ignore" });
    return true;
  } catch {
    return false;
  }
}

function triggerGitHubDeploy() {
  if (!commandExists("gh")) {
    throw new Error(
      "GitHub CLI (gh) is not installed. Install it or run Azure deploy from GitHub Actions after pushing to main.",
    );
  }

  console.log("Triggering Azure deploy through GitHub Actions...\n");
  run('gh workflow run "SCAD Platform Pipeline"');
  console.log("\nGitHub Actions deploy started.");
  console.log("Track progress with: gh run list --workflow scad-platform.yml");
}

const requiredCommands = ["docker"];
const missing = requiredCommands.filter((name) => !commandExists(name));
if (missing.length > 0) {
  throw new Error(`Missing required tools: ${missing.join(", ")}`);
}

const hasAzureTooling =
  commandExists("az") && commandExists("terraform");

if (!hasAzureTooling) {
  console.log("Azure CLI and/or Terraform not found locally.");
  triggerGitHubDeploy();
  process.exit(0);
}

console.log("Deploying SCAD to Azure Container Apps...\n");

try {
  runCapture("az account show");
} catch {
  throw new Error("Not logged in to Azure. Run: az login");
}

run("terraform init", { cwd: tfDir });
run(
  `terraform apply -auto-approve -target=azurerm_container_registry.this -var="image_tag=${imageTag}"`,
  { cwd: tfDir },
);
run(`docker build -t scad-api:${imageTag} -f app/Dockerfile app`);

const acrLoginServer = runCapture(
  "terraform output -raw container_registry_login_server",
  { cwd: tfDir },
);
const acrName = acrLoginServer.split(".")[0];

run(`az acr login --name ${acrName}`);
run(
  `docker tag scad-api:${imageTag} ${acrLoginServer}/scad-api:${imageTag}`,
);
run(`docker push ${acrLoginServer}/scad-api:${imageTag}`);
run(`terraform apply -auto-approve -var="image_tag=${imageTag}"`, {
  cwd: tfDir,
});

const appUrl = runCapture("terraform output -raw container_app_url", {
  cwd: tfDir,
});

console.log("\nAzure deployment complete.");
console.log(`API URL: ${appUrl}`);
