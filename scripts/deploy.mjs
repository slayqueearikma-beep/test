import { createInterface } from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";
import { spawnSync } from "node:child_process";

const args = process.argv.slice(2);
const targetFlagIndex = args.findIndex((arg) => arg === "--target" || arg === "-t");
const targetFlag = targetFlagIndex >= 0 ? args[targetFlagIndex + 1] : undefined;

function runScript(scriptName) {
  const result = spawnSync(process.execPath, [`scripts/${scriptName}`], {
    stdio: "inherit",
  });

  if (result.status !== 0) {
    process.exit(result.status ?? 1);
  }
}

function printMenu() {
  console.log("");
  console.log("SCAD deployment target");
  console.log("  1) Azure Container Apps");
  console.log("  2) Docker (local, open source)");
  console.log("");
}

async function promptForTarget() {
  const rl = createInterface({ input, output });

  try {
    printMenu();
    const answer = await rl.question("Choose target [1/2]: ");
    const choice = answer.trim();

    if (choice === "1" || choice.toLowerCase() === "azure") {
      return "azure";
    }

    if (choice === "2" || choice.toLowerCase() === "docker") {
      return "docker";
    }

    console.log("Invalid choice. Please enter 1 or 2.");
    return promptForTarget();
  } finally {
    rl.close();
  }
}

function resolveTarget() {
  if (!targetFlag) {
    return undefined;
  }

  const normalized = targetFlag.toLowerCase();
  if (normalized === "azure" || normalized === "1") {
    return "azure";
  }

  if (normalized === "docker" || normalized === "2") {
    return "docker";
  }

  throw new Error('Use --target azure or --target docker');
}

const target = resolveTarget() ?? (await promptForTarget());

if (target === "azure") {
  runScript("deploy-azure.mjs");
} else {
  runScript("deploy-docker.mjs");
}
