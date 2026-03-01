#!/bin/bash
# kanban-status.sh — Workspace Kanban 현황 대시보드
set -euo pipefail

OWNER="mqzkim"
REPO="mqzkim/local-workspace"
PROJECT_NUM="1"

echo ""
echo "  Workspace Kanban Dashboard"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "  ─────────────────────────────"

# 전체 이슈 현황
OPEN=$(gh issue list --repo $REPO --state open --json number --limit 500 2>/dev/null | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).length))" 2>/dev/null || echo "?")
CLOSED=$(gh issue list --repo $REPO --state closed --json number --limit 500 2>/dev/null | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).length))" 2>/dev/null || echo "?")

echo ""
echo "  Open: $OPEN | Closed: $CLOSED"
echo ""

# 프로젝트별
echo "  -- By Project --"
for proj in "agentops" "shipkit" "unity-game" "infra"; do
  count=$(gh issue list --repo $REPO --label "project:$proj" --state open --json number --limit 500 2>/dev/null | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).length))" 2>/dev/null || echo "0")
  printf "  %-15s %s open\n" "$proj" "$count"
done

echo ""

# 우선순위별
echo "  -- By Priority --"
for pri in "critical" "high" "medium" "low"; do
  count=$(gh issue list --repo $REPO --label "priority:$pri" --state open --json number --limit 500 2>/dev/null | node -e "process.stdin.on('data',d=>console.log(JSON.parse(d).length))" 2>/dev/null || echo "0")
  printf "  %-15s %s\n" "$pri" "$count"
done

echo ""

# Critical 이슈 상세
CRITICAL=$(gh issue list --repo $REPO --label "priority:critical" --state open --json number,title 2>/dev/null | node -e "
const d=JSON.parse(require('fs').readFileSync('/dev/stdin','utf8'));
d.forEach(i=>console.log('  #'+i.number+' '+i.title));
" 2>/dev/null || echo "")

if [ -n "$CRITICAL" ]; then
  echo "  -- Critical Issues --"
  echo "$CRITICAL"
  echo ""
fi

echo "  ─────────────────────────────"
echo "  Web: gh project view $PROJECT_NUM --owner $OWNER --web"
echo ""
