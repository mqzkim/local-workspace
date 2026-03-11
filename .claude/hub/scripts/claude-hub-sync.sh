#!/usr/bin/env bash
# claude-hub-sync.sh — 공유 에셋 동기화
# Usage: claude-hub-sync.sh [--push|--pull|--both] [asset] [type] [repo]
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh"

hub_ensure_dirs
hub_acquire_lock || exit 1
trap hub_release_lock EXIT

hub_log INFO "Starting sync: ${1:---both}"
node "$SCRIPT_DIR/sync.js" "$@"
hub_log OK "Sync complete."
