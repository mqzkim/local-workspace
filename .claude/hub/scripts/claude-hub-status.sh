#!/usr/bin/env bash
# claude-hub-status.sh — 전체 에셋 현황 조회
# Usage: claude-hub-status.sh [repo] [type]
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh"

node "$SCRIPT_DIR/status.js" "$@"
