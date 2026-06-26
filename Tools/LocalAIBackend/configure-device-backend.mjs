import os from "node:os";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const rootDir = resolve(__dirname, "../..");
const plistPath = resolve(rootDir, "Fitness Coach/DeveloperLocal.plist");

loadEnv(resolve(rootDir, ".env"));

const port = Number(process.env.FITPILOT_AI_BACKEND_PORT || 8787);
const ip = preferredLanIPv4();

if (!ip) {
  console.error("Could not detect a LAN IPv4 address. Connect to Wi‑Fi and try again.");
  process.exit(1);
}

const backendURL = `http://${ip}:${port}`;

console.log(`FITPILOT_AI_BACKEND_URL=${backendURL}`);
console.log("");
console.log("Option A — Xcode scheme (Run → Arguments → Environment Variables):");
console.log(`  FITPILOT_AI_BACKEND_URL = ${backendURL}`);
console.log("");
console.log("Option B — bundle plist (ignored by git):");
console.log(`  node Tools/LocalAIBackend/configure-device-backend.mjs --write`);

if (process.argv.includes("--write")) {
  const plist = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>FITPILOT_AI_BACKEND_URL</key>
\t<string>${backendURL}</string>
</dict>
</plist>
`;
  writeFileSync(plistPath, plist, "utf8");
  console.log("");
  console.log(`Wrote ${plistPath}`);
  console.log("Rebuild the app on your device.");
}

function preferredLanIPv4() {
  const interfaces = os.networkInterfaces();
  for (const name of ["en0", "en1"]) {
    for (const net of interfaces[name] ?? []) {
      if (net.family === "IPv4" && !net.internal) {
        return net.address;
      }
    }
  }
  for (const nets of Object.values(interfaces)) {
    for (const net of nets ?? []) {
      if (net.family === "IPv4" && !net.internal) {
        return net.address;
      }
    }
  }
  return null;
}

function loadEnv(path) {
  let raw = "";
  try {
    raw = readFileSync(path, "utf8");
  } catch {
    return;
  }

  for (const line of raw.split(/\r?\n/)) {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#")) continue;
    const index = trimmed.indexOf("=");
    if (index === -1) continue;
    const key = trimmed.slice(0, index).trim();
    const value = trimmed.slice(index + 1).trim().replace(/^['"]|['"]$/g, "");
    if (!process.env[key]) process.env[key] = value;
  }
}
