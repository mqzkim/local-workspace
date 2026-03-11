#!/usr/bin/env bash
# claude-hub-scan.sh — 모든 등록 레포를 스캔하여 레지스트리 + 매니페스트 갱신
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh"

hub_ensure_dirs
hub_acquire_lock || exit 1
trap hub_release_lock EXIT

hub_log INFO "Starting full scan..."
node "$SCRIPT_DIR/scan.js"
hub_log OK "Scan complete."
