#!/usr/bin/env node
// init.js — 새 레포를 허브에 등록하고 공유 에셋을 부트스트랩
const fs = require("fs");
const path = require("path");

const HUB_ROOT = process.env.CLAUDE_HUB_ROOT || "C:/workspace/.claude/hub";
const configPath = path.join(HUB_ROOT, "hub.config.json");
const registryPath = path.join(HUB_ROOT, "registry.json");
const sharedDir = path.join(HUB_ROOT, "shared");

const repoPath = process.argv[2];
const alias = process.argv[3] || path.basename(repoPath);

if (!repoPath) {
  console.error("Usage: init.js <repo-path> [alias]");
  process.exit(1);
}

function toWinPath(p) {
  return p.replace(/^\/([a-zA-Z])\//, "$1:/");
}

const resolvedPath = toWinPath(repoPath);

if (!fs.existsSync(resolvedPath)) {
  console.error(`[ERROR] Directory not found: ${resolvedPath}`);
  process.exit(1);
}

// 1. .claude 디렉토리 구조 생성
const subdirs = ["skills", "commands", "rules", "agents", "output-styles"];
for (const sub of subdirs) {
  fs.mkdirSync(path.join(resolvedPath, ".claude", sub), { recursive: true });
}
console.error(`[OK] Created .claude/ structure in ${alias}`);

// 2. hub.config.json에 등록
const config = JSON.parse(fs.readFileSync(configPath, "utf8"));
if (config.repos.some(r => r.alias === alias)) {
  console.error(`[WARN] Repo already registered: ${alias}`);
} else {
  config.repos.push({ alias, path: repoPath, isRoot: false });
  fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
  console.error(`[OK] Registered repo: ${alias}`);
}

// 3. shared/ 에셋 복사
function copyRecursive(src, dst) {
  const stat = fs.statSync(src);
  if (stat.isDirectory()) {
    fs.mkdirSync(dst, { recursive: true });
    for (const f of fs.readdirSync(src)) {
      copyRecursive(path.join(src, f), path.join(dst, f));
    }
  } else {
    fs.mkdirSync(path.dirname(dst), { recursive: true });
    fs.copyFileSync(src, dst);
  }
}

let copied = 0;
for (const sub of subdirs) {
  const srcDir = path.join(sharedDir, sub);
  if (!fs.existsSync(srcDir)) continue;

  for (const entry of fs.readdirSync(srcDir)) {
    const src = path.join(srcDir, entry);
    const dst = path.join(resolvedPath, ".claude", sub, entry);
    try {
      copyRecursive(src, dst);
      copied++;
      console.error(`[COPY] ${sub}/${entry} -> ${alias}`);
    } catch (e) {
      console.error(`[WARN] Failed to copy ${sub}/${entry}: ${e.message}`);
    }
  }
}

// 4. 레지스트리 sharedTo 업데이트
const registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
for (const [assetType, assets] of Object.entries(registry.assets)) {
  for (const [name, asset] of Object.entries(assets)) {
    if (asset.scope === "shared" && !asset.sharedTo.includes(alias)) {
      asset.sharedTo.push(alias);
    }
  }
}
registry.repos[alias] = { path: repoPath, alias, lastScanned: new Date().toISOString() };
fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2));

console.log(JSON.stringify({ status: "ok", alias, copied }));
console.error(`[OK] Init complete: ${copied} assets copied to ${alias}`);
