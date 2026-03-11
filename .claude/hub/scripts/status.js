#!/usr/bin/env node
// status.js — 전체 에셋 현황 + 변경 감지
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const HUB_ROOT = process.env.CLAUDE_HUB_ROOT || "C:/workspace/.claude/hub";
const registry = JSON.parse(fs.readFileSync(path.join(HUB_ROOT, "registry.json"), "utf8"));
const config = JSON.parse(fs.readFileSync(path.join(HUB_ROOT, "hub.config.json"), "utf8"));

const args = process.argv.slice(2);
const repoFilter = args[0] || null;
const typeFilter = args[1] || null;

function toWinPath(p) {
  return p.replace(/^\/([a-zA-Z])\//, "$1:/");
}

function hashFile(p) {
  try { return crypto.createHash("sha256").update(fs.readFileSync(p)).digest("hex"); }
  catch { return null; }
}

const subdirMap = {
  skills: "skills", agents: "agents", commands: "commands",
  rules: "rules", "output-styles": "output-styles"
};

console.log("=== Claude Hub Status ===");
console.log(`Last updated: ${registry.lastUpdated}`);
console.log(`Repos: ${config.repos.map(r => r.alias).join(", ")}`);
console.log("");

let totalAssets = 0, sharedCount = 0, modifiedCount = 0, missingCount = 0;

for (const [assetType, assets] of Object.entries(registry.assets)) {
  if (typeFilter && assetType !== typeFilter) continue;
  const entries = Object.entries(assets);
  if (entries.length === 0) continue;

  console.log(`--- ${assetType.toUpperCase()} (${entries.length}) ---`);

  for (const [name, asset] of entries) {
    totalAssets++;
    if (asset.scope === "shared") sharedCount++;

    const status = [];
    const repo = config.repos.find(r => r.alias === asset.origin);
    if (!repo) { status.push("ORPHAN"); }
    else {
      const repoPath = toWinPath(repo.path);
      const subdir = subdirMap[assetType];

      for (const [fname, fdata] of Object.entries(asset.files)) {
        const fpath = asset.format === "directory"
          ? path.join(repoPath, ".claude", subdir, name, fname)
          : path.join(repoPath, ".claude", subdir, fname);
        if (!fs.existsSync(fpath)) {
          status.push(`MISSING(${fname})`);
          missingCount++;
        } else {
          const currentHash = hashFile(fpath);
          if (currentHash && currentHash !== fdata.sha256) {
            status.push(`MODIFIED(${fname})`);
            modifiedCount++;
          }
        }
      }
    }

    const scope = asset.scope === "shared" ? "[SHARED]" : "[LOCAL] ";
    const statusStr = status.length > 0 ? " !! " + status.join(", ") : "";
    const desc = asset.metadata?.description
      ? " — " + (asset.metadata.description.length > 50
          ? asset.metadata.description.substring(0, 50) + "..."
          : asset.metadata.description)
      : "";

    console.log(`  ${scope} ${name} (${asset.origin})${desc}${statusStr}`);
  }
  console.log("");
}

console.log("=== Summary ===");
console.log(`Total:    ${totalAssets}`);
console.log(`Shared:   ${sharedCount}`);
console.log(`Modified: ${modifiedCount}`);
console.log(`Missing:  ${missingCount}`);
