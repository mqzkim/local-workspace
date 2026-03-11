#!/usr/bin/env bash
# on-file-write.sh — PostToolUse(Write|Edit) hook: .claude/ 파일 변경 감지
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/claude-hub-lib.sh" 2>/dev/null || exit 0

# stdin에서 hook 입력 읽기
INPUT=$(cat)

# 변경된 파일 경로 추출
FILE_PATH=$(echo "$INPUT" | node -e "
  let data='';
  process.stdin.on('data',c=>data+=c);
  process.stdin.on('end',()=>{
    try {
      const input = JSON.parse(data);
      console.log(input.tool_input?.file_path || input.tool_input?.filePath || '');
    } catch { console.log(''); }
  });
" 2>/dev/null)

# .claude/ 디렉토리 내 파일인지 확인
if echo "$FILE_PATH" | grep -q "\.claude/"; then
  hub_log INFO "Claude asset modified: $FILE_PATH"
  node "$SCRIPT_DIR/scan.js" > /dev/null 2>&1 || true
  hub_log OK "Post-write scan complete"
fi

exit 0
