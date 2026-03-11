#!/usr/bin/env bash
# claude-hub-lib.sh — Claude Hub 공유 함수 라이브러리

# Git Bash에서는 /c/workspace, Node.js에서는 C:/workspace 필요
HUB_ROOT="/c/workspace/.claude/hub"
HUB_ROOT_WIN="C:/workspace/.claude/hub"
HUB_REGISTRY="$HUB_ROOT/registry.json"
HUB_CONFIG="$HUB_ROOT/hub.config.json"
HUB_SHARED="$HUB_ROOT/shared"
HUB_MANIFESTS="$HUB_ROOT/manifests"
HUB_LOGS="$HUB_ROOT/logs"
HUB_SCRIPTS="$HUB_ROOT/scripts"
HUB_LOCK="$HUB_ROOT/.hub.lock"

# Node.js에 전달할 환경변수
export CLAUDE_HUB_ROOT="$HUB_ROOT_WIN"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

hub_timestamp() {
  date -u +"%Y-%m-%dT%H:%M:%SZ"
}

hub_log() {
  local level="$1" msg="$2"
  echo "[$(hub_timestamp)] [$level] $msg" >> "$HUB_LOGS/hub.log"
  case $level in
    ERROR) echo -e "${RED}[ERROR]${NC} $msg" >&2 ;;
    WARN)  echo -e "${YELLOW}[WARN]${NC} $msg" >&2 ;;
    OK)    echo -e "${GREEN}[OK]${NC} $msg" >&2 ;;
    INFO)  echo -e "${BLUE}[INFO]${NC} $msg" >&2 ;;
  esac
}

hub_hash_file() {
  sha256sum "$1" 2>/dev/null | cut -d' ' -f1
}

hub_ensure_dirs() {
  mkdir -p "$HUB_SHARED"/{agents,commands,output-styles,skills,rules}
  mkdir -p "$HUB_MANIFESTS"
  mkdir -p "$HUB_LOGS"
}

hub_acquire_lock() {
  local max_wait=10 waited=0
  while [ -f "$HUB_LOCK" ] && [ $waited -lt $max_wait ]; do
    sleep 1
    waited=$((waited + 1))
  done
  if [ -f "$HUB_LOCK" ]; then
    local lock_age
    lock_age=$(( $(date +%s) - $(stat -c %Y "$HUB_LOCK" 2>/dev/null || date +%s) ))
    if [ $lock_age -gt 60 ]; then
      rm -f "$HUB_LOCK"
    else
      hub_log ERROR "Cannot acquire lock after ${max_wait}s"
      return 1
    fi
  fi
  echo $$ > "$HUB_LOCK"
  return 0
}

hub_release_lock() {
  rm -f "$HUB_LOCK"
}

hub_get_repos() {
  node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('$HUB_CONFIG', 'utf8'));
    cfg.repos.forEach(r => console.log(r.alias + '|' + r.path));
  "
}
