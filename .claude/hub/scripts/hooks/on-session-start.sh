#!/usr/bin/env bash
# on-session-start.sh — SessionStart hook: 자동 sync + 상태 요약 주입
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh" 2>/dev/null || exit 0

# 자동 sync (pull만, 빠르게)
if [ -f "$HUB_CONFIG" ]; then
  node "$SCRIPT_DIR/sync.js" --pull > /dev/null 2>&1 || true
fi

# 상태 요약을 additionalContext로 출력
if [ -f "$HUB_REGISTRY" ]; then
  SUMMARY=$(node -e "
    const fs = require('fs');
    const reg = JSON.parse(fs.readFileSync('$HUB_ROOT_WIN/registry.json', 'utf8'));
    const counts = {};
    let total = 0;
    for (const [type, assets] of Object.entries(reg.assets)) {
      const c = Object.keys(assets).length;
      counts[type] = c;
      total += c;
    }
    console.log('[Claude Hub] ' + total + ' assets synced | skills:' + counts.skills + ' agents:' + counts.agents + ' commands:' + counts.commands);
  " 2>/dev/null || echo "")

  if [ -n "$SUMMARY" ]; then
    echo "{\"hookSpecificOutput\":{\"hookEventName\":\"SessionStart\",\"additionalContext\":\"$SUMMARY\"}}"
  fi
fi

exit 0
