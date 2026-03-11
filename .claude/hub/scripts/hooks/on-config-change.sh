#!/usr/bin/env bash
# on-config-change.sh — ConfigChange(skills) hook: 변경 감지 → 재스캔
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh" 2>/dev/null || exit 0

hub_log INFO "ConfigChange detected: skills modified"

# 재스캔 (비동기로 빠르게)
node "$SCRIPT_DIR/scan.js" > /dev/null 2>&1 || true

hub_log OK "Post-change scan complete"
exit 0
