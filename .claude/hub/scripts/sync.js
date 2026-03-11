#!/usr/bin/env node
// sync.js — 공유 에셋 동기화 (push: origin→hub, pull: hub→repos)
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const HUB_ROOT = process.env.CLAUDE_HUB_ROOT || "C:/workspace/.claude/hub";
const registryPath = path.join(HUB_ROOT, "registry.json");
const configPath = path.join(HUB_ROOT, "hub.config.json");
const sharedDir = path.join(HUB_ROOT, "shared");

const args = process.argv.slice(2);
const action = args[0] || "--both"; // --push, --pull, --both
const assetFilter = args[1] || null;
const typeFilter = args[2] || null;
const repoFilter = args[3] || null;

const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

function toWinPath(p) {
  return p.replace(/^\/([a-zA-Z])\//, "$1:/");
}

function hashFile(p) {
  try { return crypto.createHash("sha256").update(fs.readFileSync(p)).digest("hex"); }
  catch { return null; }
}

function copyRecursive(src, dst) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dst, { recursive: true });
    for (const f of fs.readdirSync(src)) {
      const srcF = path.join(src, f);
      const dstF = path.join(dst, f);
      if (fs.statSync(srcF).isFile()) {
        fs.copyFileSync(srcF, dstF);
      }
    }
  } else {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
  }
}

const subdirMap = {
  skills: "skills", agents: "agents", commands: "commands",
  rules: "rules", "output-styles": "output-styles"
};

let syncCount = 0;

// PUSH: origin repo → hub shared/
if (action === "--push" || action === "--both") {
  for (const [assetType, assets] of Object.entries(registry.assets)) {
    if (typeFilter && assetType !== typeFilter) continue;
    const subdir = subdirMap[assetType];

    for (const [name, asset] of Object.entries(assets)) {
      if (assetFilter && name !== assetFilter) continue;
      if (asset.scope !== "shared") continue;

      const repo = config.repos.find(r => r.alias === asset.origin);
      if (!repo) continue;
      const repoPath = toWinPath(repo.path);

      let srcPath, dstPath;
      if (asset.format === "directory") {
        srcPath = path.join(repoPath, ".claude", subdir, name);
        dstPath = path.join(sharedDir, subdir, name);
      } else {
        const fileName = Object.keys(asset.files)[0];
        srcPath = path.join(repoPath, ".claude", subdir, fileName);
        dstPath = path.join(sharedDir, subdir, fileName);
      }

      if (fs.existsSync(srcPath)) {
        copyRecursive(srcPath, dstPath);
        console.error(`[PUSH] ${assetType}/${name}: ${asset.origin} -> hub`);
        syncCount++;
      }
    }
  }
}

// PULL: hub shared/ → target repos
if (action === "--pull" || action === "--both") {
  for (const [assetType, assets] of Object.entries(registry.assets)) {
    if (typeFilter && assetType !== typeFilter) continue;
    const subdir = subdirMap[assetType];

    for (const [name, asset] of Object.entries(assets)) {
      if (assetFilter && name !== assetFilter) continue;
      if (asset.scope !== "shared") continue;

      // Pull to all repos except origin
      const targetRepos = config.repos.filter(r => r.alias !== asset.origin);

      for (const targetRepo of targetRepos) {
        if (repoFilter && targetRepo.alias !== repoFilter) continue;
        const targetPath = toWinPath(targetRepo.path);

        let srcPath, dstPath;
        if (asset.format === "directory") {
          srcPath = path.join(sharedDir, subdir, name);
          dstPath = path.join(targetPath, ".claude", subdir, name);
        } else {
          const fileName = Object.keys(asset.files)[0];
          srcPath = path.join(sharedDir, subdir, fileName);
          dstPath = path.join(targetPath, ".claude", subdir, fileName);
        }

        if (!fs.existsSync(srcPath)) continue;

        // 원본 우선 충돌 해결: 항상 덮어쓰기
        fs.mkdirSync(path.dirname(dstPath), { recursive: true });
        copyRecursive(srcPath, dstPath);
        console.error(`[PULL] ${assetType}/${name}: hub -> ${targetRepo.alias}`);
        syncCount++;
      }
    }
  }
}

console.log(JSON.stringify({ status: "ok", synced: syncCount }));
console.error(`[SYNC] Total synced: ${syncCount}`);
