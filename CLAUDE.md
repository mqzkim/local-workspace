# CLAUDE.md — Developer Workspace

> Claude Code가 이 워크스페이스에서 따라야 할 핵심 가이드.
> 프로젝트에 독립적인 범용 개발 환경. 새 프로젝트 시작 시 이 문서를 기반으로 작업.

---

## 실행 환경

- **OS**: Windows 11 Home (Build 10.0.26200) 64-bit, RAM 32GB
- **Shell**: Git Bash (Claude Code 내부) — **항상 Unix 문법** 사용
- **Node.js**: v22.15.0 / npm 11.5.2
- **Python**: 3.13.3 / **Git**: 2.51.0.windows.1
- **작업 디렉토리**: `C:\workspace`

---

## ⚠️ 최우선 규칙: Skill-First (강제)

> **모든 작업 요청은 반드시 Skill을 통해 실행한다. 예외 없음.**
> 상세 규칙: `.claude/rules/skill-first.md`

1. 기존 Skill 매칭 → 있으면 즉시 Skill 호출
2. 없으면 → Team Agent로 새 Skill 생성 → 생성된 Skill로 작업 수행
3. **Skill 없이 직접 코드 작성/수정 절대 금지**

---

## 핵심 워크플로우: 탐색 → 계획 → 합의 → 실행 → 회고

모든 비자명 작업은 아래 5단계를 따른다. **계획 없는 실행 금지**.

### Phase 1: 탐색 (Explore)
- 관련 코드, 아키텍처, 기존 패턴 파악
- 프로젝트 문서 및 README 우선 확인
- 영향 범위(blast radius) 사전 평가

### Phase 2: 계획 (Plan)
- 구체적 구현 계획 수립 (파일별 변경사항 명시)
- 대안 비교 및 트레이드오프 분석
- 성공 기준(exit criteria) 정의

### Phase 3: 합의 (Align)
- 계획을 사용자에게 제시하고 **승인 후 실행**
- 불확실한 부분은 질문으로 해소
- 범위 변경 시 재합의

### Phase 4: 실행 (Implement)
- 승인된 계획에 따라 코드 작성
- 변경마다 검증 (빌드, 테스트, 타입체크)
- TodoWrite로 진행상황 실시간 추적

### Phase 5: 회고 (Retrospect)
- 세션 종료 시 핵심 학습 추출
- 반복 패턴은 메모리에 기록
- 실패한 접근법도 기록 (같은 실수 방지)

---

## 메모리 시스템

지속적 학습을 위한 메모리 파일 운영:
- **위치**: `~/.claude/projects/C--workspace/memory/`
- **MEMORY.md**: 핵심 요약 (200줄 이내, 자동 로드)
- **주제별 파일**: `debugging.md`, `patterns.md` 등 상세 기록

### 메모리 기록 기준
- ✅ 여러 세션에서 확인된 안정적 패턴
- ✅ 아키텍처 결정과 그 근거
- ✅ 반복 문제의 해결책
- ✅ 사용자가 명시적으로 기억 요청한 사항
- ❌ 세션 한정 임시 정보, 미검증 추측

### 세션 회고 프로토콜
1. **무엇을 했는가**: 변경사항 요약
2. **무엇을 배웠는가**: 새로운 패턴이나 인사이트
3. **다음에 주의할 점**: 실패했던 접근법, 엣지케이스
4. → 유의미한 학습만 메모리에 기록

---

## 새 프로젝트 시작 가이드

새 프로젝트를 이 워크스페이스에 추가할 때:

1. **디렉토리 생성**: `mkdir <project-name>`
2. **스캐폴딩**: 기술 스택에 맞는 초기화 (npx create-next-app, etc.)
3. **프로젝트 CLAUDE.md 작성**: `<project-name>/CLAUDE.md`
4. **.env.example 작성**: 필요한 환경 변수 템플릿
5. **launch.json 업데이트**: `.claude/launch.json`에 dev server 추가
6. **Git 설정**: 초기 커밋 후 작업 시작

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

### 커스텀 커맨드 (`.claude/commands/`)
- `kanban` — 칸반 보드 조회/관리 (`/kanban`, `/kanban list`, `/kanban add`, `/kanban start`, `/kanban done`)
- `vercel-deploy-optimize` — Vercel 배포 최적화
- `vercel-edge-function` — Edge Function 생성
- `vercel-env-sync` — 환경변수 동기화

---

## 칸반 기반 작업 관리

모든 작업은 **GitHub Projects 칸반 보드**를 통해 추적한다.

- **보드:** [Workspace Kanban](https://github.com/users/mqzkim/projects/1)
- **CLI:** `/kanban` 커맨드 또는 `gh project` 명령어
- **대시보드:** `bash scripts/kanban-status.sh`

### 작업 프로세스 (보드 자동 연동)
1. 이슈 생성 → 보드 Backlog에 자동 배치 (GitHub Actions)
2. **작업 시작** → `/kanban start #N` → 브랜치 생성 + 보드 **In Progress** 자동 이동
3. **작업 완료** → `/kanban done #N` → PR 생성 + 보드 **In Review** 자동 이동
4. **PR 머지** → 보드 **Done** 자동 이동 (GitHub Actions) + 이슈 자동 닫힘

### 개발 규칙
- 이슈 번호가 있는 작업 시작 시 **반드시 `/kanban start #N`** 사용
- 이슈 없이 작업하지 않음 — 먼저 `/kanban add`로 이슈 생성
- PR 생성 시 **반드시 `/kanban done #N`** 사용
- 커밋은 수동으로 완료한 후 `/kanban done` 실행

### 라벨 체계
- **프로젝트:** `project:agentops`, `project:shipkit`, `project:unity-game`, `project:infra`
- **우선순위:** `priority:critical/high/medium/low`
- **유형:** `type:feature/bugfix/chore/docs/refactor/test`

---

## Git 워크플로우

- **메인 브랜치**: `main`
- 커밋 메시지: conventional commits 권장 (feat/fix/chore/docs)
- **수동 커밋 전용** — 자동 커밋 훅 없음
- Co-Authored-By 태그 포함

---

## 공통 개발 원칙

### 데이터 & 보안
- MOCK/TEST 데이터 프로덕션 사용 금지
- API Key → 환경 변수 (.env)로만 관리
- 시크릿 하드코딩 절대 금지

### 코드 품질
- TypeScript strict mode 권장
- ESLint + Prettier 설정 후 준수
- 임시 파일, 테스트 더미 코드 금지

### 절대 금지 사항
- ❌ 계획 없이 대규모 변경 실행
- ❌ API Key 하드코딩
- ❌ 검증 없는 배포
- ❌ 사용자 승인 없는 파괴적 git 명령
