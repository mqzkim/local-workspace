#!/usr/bin/env bash
# WSL 마이그레이션 후 워크스페이스 경로 치환
# git clone 후 ~/workspace 에서 실행
set -euo pipefail

WS="$HOME/workspace"

if [ ! -d "$WS/.claude" ]; then
  echo "ERROR: $WS/.claude 디렉토리가 없습니다. git clone 먼저 실행하세요."
  exit 1
fi

echo "=== 워크스페이스 경로 치환 ==="

# 프로젝트 settings.json
if [ -f "$WS/.claude/settings.json" ]; then
  sed -i 's|C:/workspace|/home/mqz/workspace|g' "$WS/.claude/settings.json"
  sed -i 's|/c/workspace|/home/mqz/workspace|g' "$WS/.claude/settings.json"
  echo "  .claude/settings.json 치환 완료"
fi

# Hub 설정 파일들
HUB="$WS/.claude/hub"
if [ -d "$HUB" ]; then
  # hub.config.json
  [ -f "$HUB/hub.config.json" ] && \
    sed -i 's|C:/workspace|/home/mqz/workspace|g; s|C:/Users/USER|/home/mqz|g' "$HUB/hub.config.json" && \
    echo "  hub.config.json 치환 완료"

  # registry.json
  [ -f "$HUB/registry.json" ] && \
    sed -i 's|C:/workspace|/home/mqz/workspace|g; s|C:/Users/USER|/home/mqz|g' "$HUB/registry.json" && \
    echo "  registry.json 치환 완료"

  # claude-hub-lib.sh
  [ -f "$HUB/scripts/claude-hub-lib.sh" ] && \
    sed -i 's|HUB_ROOT="/c/workspace/.claude/hub"|HUB_ROOT="/home/mqz/workspace/.claude/hub"|; s|HUB_ROOT_WIN="C:/workspace/.claude/hub"|HUB_ROOT_WIN="/home/mqz/workspace/.claude/hub"|' "$HUB/scripts/claude-hub-lib.sh" && \
    echo "  claude-hub-lib.sh 치환 완료"

  # JS 스크립트 4개
  for f in sync.js scan.js init.js status.js; do
    [ -f "$HUB/scripts/$f" ] && \
      sed -i 's|"C:/workspace/.claude/hub"|"/home/mqz/workspace/.claude/hub"|g' "$HUB/scripts/$f" && \
      echo "  $f 치환 완료"
  done

  # Hook 스크립트 내 경로
  for f in "$HUB/scripts/hooks/"*.sh; do
    [ -f "$f" ] && sed -i 's|C:/workspace|/home/mqz/workspace|g; s|/c/workspace|/home/mqz/workspace|g' "$f"
  done
  echo "  Hook 스크립트 치환 완료"
fi

echo ""
echo "=== 경로 치환 완료 ==="
echo "검증: grep -r 'C:/workspace\|C:/Users/USER\|/c/workspace' $WS/.claude/ --include='*.json' --include='*.sh' --include='*.js' | head -20"
