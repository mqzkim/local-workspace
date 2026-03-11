#!/usr/bin/env bash
# on-format.sh — PostToolUse(Write|Edit) 자동 포맷팅 훅
# stdin으로 tool_input JSON을 받아 file_path 기반으로 포맷터 실행

set -euo pipefail

# stdin에서 file_path 추출
INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | grep -oP '"file_path"\s*:\s*"[^"]*"' | head -1 | sed 's/.*: *"//;s/"$//' || true)

# 파일 경로가 없으면 종료
if [ -z "$FILE_PATH" ]; then
  exit 0
fi

# Windows 경로를 Unix 경로로 변환
FILE_PATH=$(echo "$FILE_PATH" | sed 's|\\|/|g')

# 확장자 추출
EXT="${FILE_PATH##*.}"

case "$EXT" in
  ts|tsx|js|jsx|json)
    npx prettier --write "$FILE_PATH" 2>/dev/null || true
    ;;
  py)
    ruff format "$FILE_PATH" 2>/dev/null || python -m ruff format "$FILE_PATH" 2>/dev/null || black "$FILE_PATH" 2>/dev/null || python -m black "$FILE_PATH" 2>/dev/null || true
    ;;
  md)
    # Obsidian 호환을 위해 .md는 포맷팅 스킵
    ;;
  *)
    # 알 수 없는 확장자는 스킵
    ;;
esac

exit 0
