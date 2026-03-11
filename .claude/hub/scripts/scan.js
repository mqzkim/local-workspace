#!/usr/bin/env node
// scan.js — 모든 등록 레포를 스캔하여 레지스트리 + 매니페스트 갱신
const fs = require("fs");
const path = require("path");
const crypto = require("crypto");

const HUB_ROOT = process.env.CLAUDE_HUB_ROOT || "C:/workspace/.claude/hub";
const configPath = path.join(HUB_ROOT, "hub.config.json");
const registryPath = path.join(HUB_ROOT, "registry.json");
const manifestsDir = path.join(HUB_ROOT, "manifests");

const config = JSON.parse(fs.readFileSync(configPath, "utf8"));

function toWinPath(p) {
  return p.replace(/^\/([a-zA-Z])\//, "$1:/");
}

function hashFile(filePath) {
  const content = fs.readFileSync(filePath);
  return crypto.createHash("sha256").update(content).digest("hex");
}

function parseFrontmatter(content) {
  const match = content.match(/^---\r?\n([\s\S]*?)\r?\n---/);
  if (!match) return {};
  const fm = {};
  match[1].split(/\r?\n/).forEach(line => {
    const idx = line.indexOf(":");
    if (idx > 0) {
      const key = line.substring(0, idx).trim();
      const val = line.substring(idx + 1).trim().replace(/^"(.*)"$/, "$1");
      fm[key] = val;
    }
  });
  return fm;
}

function scanDir(repoPath, subdir) {
  const dir = path.join(repoPath, ".claude", subdir);
  const results = {};
  if (!fs.existsSync(dir)) return results;

  let entries;
  try {
    entries = fs.readdirSync(dir, { withFileTypes: true });
  } catch { return results; }

  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (fullPath.includes("node_modules")) continue;

    if (entry.isDirectory()) {
      const files = {};
      let dirFiles;
      try {
        dirFiles = fs.readdirSync(fullPath).filter(f => {
          try { return fs.statSync(path.join(fullPath, f)).isFile(); }
          catch { return false; }
        });
      } catch { continue; }
      if (dirFiles.length === 0) continue;

      for (const f of dirFiles) {
        const fp = path.join(fullPath, f);
        try {
          files[f] = { sha256: hashFile(fp), size: fs.statSync(fp).size };
        } catch { /* skip */ }
      }

      const mainFile = dirFiles.find(f => f === "SKILL.md") || dirFiles[0];
      let metadata = {};
      if (mainFile) {
        try {
          metadata = parseFrontmatter(fs.readFileSync(path.join(fullPath, mainFile), "utf8"));
        } catch { /* skip */ }
      }
      results[entry.name] = { format: "directory", files, metadata };

    } else if (entry.name.endsWith(".md")) {
      const name = entry.name.replace(/\.md$/, "");
      try {
        const content = fs.readFileSync(fullPath, "utf8");
        const metadata = parseFrontmatter(content);
        const stat = fs.statSync(fullPath);
        results[name] = {
          format: "flat",
          files: { [entry.name]: { sha256: hashFile(fullPath), size: stat.size } },
          metadata
        };
      } catch { /* skip */ }
    }
  }
  return results;
}

// 레지스트리 로드 또는 초기화
let registry;
try {
  registry = JSON.parse(fs.readFileSync(registryPath, "utf8"));
} catch {
  registry = {
    "$schema": "claude-hub-registry-v1",
    version: "1.0.0",
    lastUpdated: null,
    repos: {},
    assets: { skills: {}, agents: {}, commands: {}, rules: {}, "output-styles": {} }
  };
}

const subdirMap = {
  skills: "skills",
  agents: "agents",
  commands: "commands",
  rules: "rules",
  "output-styles": "output-styles"
};

for (const repo of config.repos) {
  const repoPath = toWinPath(repo.path);
  console.error(`[SCAN] ${repo.alias}: ${repoPath}`);

  registry.repos[repo.alias] = {
    path: repo.path,
    alias: repo.alias,
    lastScanned: new Date().toISOString()
  };

  const manifest = {
    "$schema": "claude-hub-manifest-v1",
    repo: repo.alias,
    path: repo.path,
    generatedAt: new Date().toISOString(),
    assets: {}
  };

  for (const [assetType, subdir] of Object.entries(subdirMap)) {
    const scanned = scanDir(repoPath, subdir);
    manifest.assets[assetType] = {};

    for (const [name, data] of Object.entries(scanned)) {
      manifest.assets[assetType][name] = { ...data, isSharedCopy: false };

      const existing = registry.assets[assetType]?.[name];
      if (!existing) {
        registry.assets[assetType][name] = {
          type: assetType.replace(/s$/, ""),
          format: data.format,
          origin: repo.alias,
          scope: "shared",
          files: data.files,
          metadata: data.metadata,
          sharedTo: [],
          tags: []
        };
      } else if (existing.origin === repo.alias) {
        existing.files = data.files;
        existing.metadata = { ...existing.metadata, ...data.metadata };
      }
    }
  }

  const manifestPath = path.join(manifestsDir, repo.alias + ".manifest.json");
  fs.writeFileSync(manifestPath, JSON.stringify(manifest, null, 2));
  console.error(`[SCAN] Wrote manifest: ${repo.alias}`);
}

registry.lastUpdated = new Date().toISOString();
fs.writeFileSync(registryPath, JSON.stringify(registry, null, 2));

// 요약
const counts = {};
let total = 0;
for (const [type, assets] of Object.entries(registry.assets)) {
  const c = Object.keys(assets).length;
  counts[type] = c;
  total += c;
}
console.log(JSON.stringify({ status: "ok", total, counts }, null, 2));
console.error(`[SCAN] Registry updated: ${total} assets`);
