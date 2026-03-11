# Workspace Development Guide

> Claude Code가 이 워크스페이스에서 따라야 할 핵심 가이드.
> 프로젝트에 독립적인 범용 개발 환경.

---

## 실행 환경

- **OS**: Windows 11 Home (Build 10.0.26200) 64-bit, RAM 32GB
- **Shell**: Git Bash (Claude Code 내부) — **항상 Unix 문법** 사용
- **Node.js**: v22.15.0 / npm 11.5.2
- **Python**: 3.13.3 / **Git**: 2.51.0.windows.1
- **작업 디렉토리**: `C:\workspace`

---

## 서브프로젝트별 빌드/테스트/린트 명령

### claude-workspace (Next.js)
```bash
npm run typecheck          # tsc --noEmit
npm run lint               # eslint
npm run test               # vitest
npx prettier --check .     # 포맷 확인
npx prettier --write .     # 포맷 적용
```

### trading (Python)
```bash
mypy src/                  # 타입체크
ruff check src/            # 린트
ruff format src/           # 포맷
pytest tests/              # 테스트
```

---

## 검증 프로토콜 (Boris #1 원칙)

> **모든 작업 완료 전 반드시 5단계 검증을 수행한다. 검증 없이 "완료" 선언 금지.**

1. **타입체크** — `typecheck` 또는 `mypy` 실행, 에러 0 확인
2. **테스트** — 관련 테스트 실행, 전부 통과 확인
3. **린트** — `lint` 또는 `ruff check` 실행, 에러 0 확인
4. **결과 명시** — 실행 결과를 사용자에게 구체적으로 보고
5. **수동 확인** — UI 변경 시 스크린샷, API 변경 시 curl 테스트

### 검증 생략 가능한 경우
- 문서/주석만 변경
- `.gitignore`, 설정 파일만 변경
- 대화/질문/응답 (코드 변경 없음)

---

## 워크플로우: 탐색 → 계획 → 합의 → 실행 → 검증 → 회고

모든 비자명 작업은 아래 6단계를 따른다. **계획 없는 실행 금지**.

### 1. 탐색 (Explore)
- 관련 코드, 아키텍처, 기존 패턴 파악
- 영향 범위(blast radius) 사전 평가

### 2. 계획 (Plan)
- 구체적 구현 계획 수립 (파일별 변경사항 명시)
- 3+파일 변경 시 Plan mode 필수 (`.claude/rules/plan-first.md`)
- 대안 비교 및 트레이드오프 분석

### 3. 합의 (Align)
- 계획을 사용자에게 제시하고 **승인 후 실행**
- 불확실한 부분은 질문으로 해소

### 4. 실행 (Implement)
- 승인된 계획에 따라 최소 변경
- 변경마다 검증 (빌드, 테스트, 타입체크)

### 5. 검증 (Verify)
- 위 검증 프로토콜 5단계 수행
- `/verify` 커맨드로 자동 실행 가능

### 6. 회고 (Retrospect)
- 세션 종료 시 핵심 학습 추출
- 반복 패턴은 메모리에 기록

---

## Skill-First 규칙 (강제)

> **모든 작업 요청은 반드시 Skill을 통해 실행한다. 예외 없음.**
> 상세 규칙: `.claude/rules/skill-first.md`

1. 기존 Skill 매칭 → 있으면 즉시 Skill 호출
2. 없으면 → Team Agent로 새 Skill 생성 → 생성된 Skill로 작업 수행
3. **Skill 없이 직접 코드 작성/수정 절대 금지**

---

## 아키텍처 (DDD)

> **모든 코드 작업 전 반드시 DDD 아키텍처 규칙을 확인한다.**

- **DDD 규칙**: `.claude/rules/ddd.md`
- **DDD 가이드**: `docs/DDD_GUIDE.md`
- 레이어 의존성: `presentation → application → domain ← infrastructure`
- 바운디드 컨텍스트 간 직접 import 금지 — 도메인 이벤트만 허용

---

## 에이전트 & 확장

### 전문 에이전트 (`.claude/agents/`)

| 에이전트 | 용도 |
|---------|------|
| backend-architect | 백엔드 아키텍처, API 설계 |
| frontend-developer | React UI, 반응형, 접근성 |
| fullstack-developer | E2E 기능 구현 |
| technical-writer | 문서화, 가이드 작성 |
| ui-ux-designer | UI/UX 설계, 디자인 시스템 |
| llms-maintainer | LLMs.txt, AI 크롤러 최적화 |
| skill-auditor | 스킬/에이전트 품질 감사 |
| hub-manager | Hub 중앙 관리 |
| **build-validator** | **typecheck + lint + test 파이프라인** |
| **code-architect** | **DDD 레이어 의존성 검증** |
| **verify-app** | **E2E 검증 (워크트리 격리)** |

### 커스텀 커맨드 (`.claude/commands/`)

| 커맨드 | 용도 |
|--------|------|
| kanban | 칸반 보드 조회/관리 |
| **verify** | **변경 프로젝트 자동 빌드/테스트/린트** |
| **simplify** | **코드 중복/과도설계 분석** |
| vercel-deploy-optimize | Vercel 배포 최적화 |
| vercel-edge-function | Edge Function 생성 |
| vercel-env-sync | 환경변수 동기화 |

---

## 칸반 기반 작업 관리

- **보드**: [Workspace Kanban](https://github.com/users/mqzkim/projects/1)
- **CLI**: `/kanban` 커맨드 또는 `gh project` 명령어
- **대시보드**: `bash scripts/kanban-status.sh`

### 작업 프로세스
1. 이슈 생성 → 보드 Backlog에 자동 배치
2. **작업 시작** → `/kanban start #N` → 브랜치 생성 + In Progress
3. **작업 완료** → `/kanban done #N` → PR 생성 + In Review
4. **PR 머지** → Done 자동 이동 + 이슈 닫힘

### 라벨 체계
- **프로젝트**: `project:agentops/shipkit/unity-game/infra`
- **우선순위**: `priority:critical/high/medium/low`
- **유형**: `type:feature/bugfix/chore/docs/refactor/test`

---

## Git 워크플로우

- **메인 브랜치**: `main`
- 커밋 메시지: conventional commits (feat/fix/chore/docs)
- **수동 커밋 전용** — 자동 커밋 훅 없음
- Co-Authored-By 태그 포함
- **워크트리 활용**: 기능 격리가 필요한 작업에 `verify-app` 에이전트 + worktree 사용

---

## Obsidian Vault 연동

- **Vault 경로**: `C:\workspace\vault\vault\`
- 내부 링크: `[[노트명]]` (위키링크), 태그: `#태그명`
- 프론트매터: YAML (`---` 블록)
- 콜아웃: `> [!note]`, `> [!warning]` 등
- 제목에 특수문자(`\ / :`) 사용 금지

---

## Codex 마이그레이션 참고

- Codex 정책 파일: `AGENTS.md`
- 마이그레이션 리포트: `.codex/MIGRATION_REPORT.md`
- 재생성: `./scripts/migrate-claude-to-codex.ps1`

---

## Team Learnings (컴파운딩 엔지니어링)

> 세션마다 발견한 학습을 여기에 추가한다. 시간이 지날수록 팀이 똑똑해진다.

| 날짜 | 학습 |
|------|------|
| 2026-03-12 | Boris 스타일 검증 프로토콜 도입 — 모든 작업 완료 전 typecheck/test/lint 필수 |

---

## Error Corrections Log

> 교정 사항을 누적 기록한다. 같은 실수를 반복하지 않기 위함.

| 날짜 | 교정 내용 |
|------|-----------|
| — | (아직 기록 없음) |
