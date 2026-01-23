#!/usr/bin/env node
import { put } from "@vercel/blob";
import { readFileSync } from "fs";

const dmgPath = process.argv[2];
const version = process.argv[3];

if (!dmgPath || !version) {
  console.error("Usage: upload-release.mjs <dmg-path> <version>");
  console.error("Example: upload-release.mjs dist/Vox-1.0.0.dmg v1.0.0");
  process.exit(1);
}

if (!process.env.BLOB_READ_WRITE_TOKEN) {
  console.error("Error: BLOB_READ_WRITE_TOKEN environment variable is required");
  process.exit(1);
}

console.log(`Uploading ${dmgPath} as version ${version}...`);

const content = readFileSync(dmgPath);

// Upload versioned copy
const versioned = await put(`releases/Vox-${version}.dmg`, content, {
  access: "public",
  addRandomSuffix: false,
});
console.log(`Uploaded: ${versioned.url}`);

// Upload as "latest" for stable URL (overwrite previous)
const latest = await put("releases/Vox-latest.dmg", content, {
  access: "public",
  addRandomSuffix: false,
  allowOverwrite: true,
});
console.log(`Latest: ${latest.url}`);

console.log("");
console.log("Download URL (versioned):", versioned.url);
console.log("Download URL (latest):", latest.url);
