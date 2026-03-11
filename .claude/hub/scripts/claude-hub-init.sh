#!/usr/bin/env bash
# claude-hub-init.sh — 새 레포 부트스트랩
# Usage: claude-hub-init.sh <repo-path> [alias]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh"

hub_ensure_dirs
hub_acquire_lock || exit 1
trap hub_release_lock EXIT

hub_log INFO "Initializing repo: ${2:-$(basename "$1")}"
node "$SCRIPT_DIR/init.js" "$@"

# 초기 스캔
node "$SCRIPT_DIR/scan.js" > /dev/null 2>&1 || true

hub_log OK "Init complete."
