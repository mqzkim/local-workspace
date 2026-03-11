#!/usr/bin/env bash
# on-stop.sh — Stop 이벤트 시 검증 리마인더 출력
# 작업 완료 전 검증 프로토콜을 상기시키는 JSON 메시지 출력

cat <<'EOF'
{
  "verification_reminder": {
    "message": "[Verification Check] 작업 완료 전 다음을 확인하세요:",
    "checklist": [
      "typecheck 실행했는가? (npm run typecheck / mypy)",
      "테스트 실행했는가? (npm run test / pytest)",
      "lint 실행했는가? (npm run lint / ruff check)",
      "실행 결과를 사용자에게 명시했는가?",
      "UI 변경 시 스크린샷 / API 변경 시 curl 테스트 했는가?"
    ],
    "skip_if": "문서/주석/설정 파일만 변경한 경우"
  }
}
EOF
