# Kanban 기반 프로젝트 모니터링 시스템 스펙 문서

> 작성일: 2026-03-02
> 목적: 워크스페이스 내 모든 프로젝트를 단일 Kanban 시스템으로 관리·모니터링

---

## 1. 현황 분석

### 1.1 관리 대상 프로젝트

| 프로젝트 | 유형 | 기술 스택 | 상태 |
|---------|------|----------|------|
| **claude-workspace** | SaaS 플랫폼 (AgentOps) | Next.js 15, Supabase, Stripe, tRPC | 활발 (16 스프린트 로드맵) |
| **shipkit** | SaaS 보일러플레이트 | Next.js 15, TypeScript, shadcn/ui | 활발 (claude-workspace 하위) |
| **unity-game** | 모바일 게임 | Unity, Firebase | 초기 단계 |
| **actions-runner** | CI/CD 인프라 | GitHub Actions Self-hosted | 운영 중 |

### 1.2 현재 프로젝트 관리 방식

- 계획 문서 기반 (`plans/` 디렉토리)
- TodoWrite (세션 내 한정)
- MEMORY.md (세션 간 학습만)
- **체계적 이슈 트래킹 부재** → 이번 시스템으로 해결

---

## 2. 도구 선정

### 2.1 비교 평가 결과

| 도구 | 무료 | CLI | API | MCP 서버 | Git 연동 | 총점 |
|------|------|-----|-----|---------|---------|------|
| **GitHub Projects** | ★★★ | ★★★ | ★★★ | ★★★ (공식) | ★★★ | **1위** |
| **Linear** | ★★ | ★★★ | ★★★ | ★★★ (공식) | ★★★ | 2위 |
| **Plane.so** | ★★★ | ★ | ★★ | ★★★ (공식) | ★★ | 3위 |
| Notion | ★★ | ★ | ★★ | ★★★ | ★ | 4위 |
| Trello | ★★ | ★★ | ★★ | ★★ | ★ | 5위 |
| kanban-md | ★★★ | ★★★ | N/A | 내장 | ★★★ | 특수용도 |

### 2.2 최종 선정: GitHub Projects + GitHub MCP Server

**선정 근거:**

1. **제로 추가 비용** — GitHub Free에 완전 포함, 무제한 프로젝트/이슈
2. **네이티브 Git 연동** — 이슈 ↔ 브랜치 ↔ PR ↔ 보드 한 곳에 통합
3. **공식 CLI (`gh`)** — `gh project` 명령어 GA, JSON 출력 지원
4. **공식 MCP 서버** — Claude Code에서 직접 프로젝트 읽기/쓰기 가능
5. **GitHub Actions 자동화** — 이슈 상태 자동 업데이트, 라벨링 등
6. **이미 GitHub 사용 중** — 추가 서비스 가입/관리 불필요

**차점자 Linear 미선정 사유:**
- 활성 이슈 250개 제한 (무료 티어)
- 별도 서비스 관리 필요 (이중화)
- 셀프호스팅 불가

---

## 3. 아키텍처 설계

### 3.1 전체 구성도

```
┌─────────────────────────────────────────────────────────┐
│                    GitHub Projects v2                    │
│  ┌─────────────┐ ┌──────────────┐ ┌──────────────────┐  │
│  │  Backlog     │ │  In Progress │ │  Done            │  │
│  │  ─────────   │ │  ──────────  │ │  ──────────────  │  │
│  │  #12 feat    │ │  #15 fix     │ │  #10 feat ✓     │  │
│  │  #13 chore   │ │  #16 feat    │ │  #11 fix ✓      │  │
│  │  #14 docs    │ │              │ │  #14 docs ✓     │  │
│  └─────────────┘ └──────────────┘ └──────────────────┘  │
└──────────────┬────────────────┬──────────────────────────┘
               │                │
    ┌──────────▼──────┐  ┌──────▼───────────┐
    │   gh CLI        │  │  GitHub MCP      │
    │   (터미널)      │  │  (Claude Code)   │
    │                 │  │                  │
    │  gh project ... │  │  projects_list   │
    │  gh issue ...   │  │  projects_get    │
    │                 │  │  projects_write  │
    └──────────┬──────┘  └──────┬───────────┘
               │                │
    ┌──────────▼────────────────▼───────────┐
    │         Claude Code 세션               │
    │  ┌──────────────────────────────────┐  │
    │  │  1. MCP로 보드 현황 조회         │  │
    │  │  2. 작업할 이슈 선택/시작        │  │
    │  │  3. 코드 작업 수행               │  │
    │  │  4. PR 생성 + 이슈 상태 업데이트 │  │
    │  │  5. 완료 시 Done으로 이동        │  │
    │  └──────────────────────────────────┘  │
    └───────────────────────────────────────┘
```

### 3.2 프로젝트 보드 구조

#### 메인 보드: `Workspace Kanban`

**컬럼 (Status 필드):**

| 컬럼 | 설명 | 자동화 |
|------|------|--------|
| **📋 Backlog** | 아이디어, 향후 작업 | 이슈 생성 시 기본 |
| **📌 Todo** | 이번 스프린트/주에 할 작업 | 수동 이동 |
| **🔨 In Progress** | 현재 작업 중 | 브랜치 생성 시 자동 이동 |
| **👀 In Review** | PR 리뷰 대기 | PR 생성 시 자동 이동 |
| **✅ Done** | 완료 | PR 머지 시 자동 이동 |

**커스텀 필드:**

| 필드 | 타입 | 값 |
|------|------|-----|
| **Project** | Single Select | `claude-workspace`, `shipkit`, `unity-game`, `infra` |
| **Priority** | Single Select | `🔴 P0 Critical`, `🟠 P1 High`, `🟡 P2 Medium`, `🟢 P3 Low` |
| **Type** | Single Select | `feat`, `fix`, `chore`, `docs`, `refactor`, `test` |
| **Sprint** | Iteration | 2주 단위 반복 |
| **Effort** | Number | 스토리 포인트 (1, 2, 3, 5, 8) |

### 3.3 라벨 체계

```
# 프로젝트별
project:agentops      — claude-workspace 메인
project:shipkit       — ShipKit 보일러플레이트
project:unity-game    — Unity 게임
project:infra         — 인프라/CI/CD

# 유형별
type:feature          — 새 기능
type:bugfix           — 버그 수정
type:refactor         — 리팩토링
type:docs             — 문서화
type:test             — 테스트

# 우선순위
priority:critical     — 즉시 처리
priority:high         — 이번 주 내
priority:medium       — 이번 스프린트 내
priority:low          — 여유 있을 때

# 상태 보조
blocked               — 외부 의존성으로 블록됨
needs-review          — 리뷰 필요
good-first-issue      — 쉬운 작업
```

---

## 4. 통합 구현 계획

### 4.1 GitHub MCP 서버 설정

```bash
# 방법 1: npx (권장)
claude mcp add github-mcp -- npx -y @anthropic-ai/github-mcp-server

# 방법 2: Docker
claude mcp add github -- docker run -i --rm \
  -e GITHUB_PERSONAL_ACCESS_TOKEN=ghp_xxxx \
  ghcr.io/github/github-mcp-server

# 환경 변수 (PAT에 필요한 스코프)
# - repo (이슈, PR 관리)
# - project (Projects v2 접근)
# - read:org (조직 프로젝트 읽기)
```

**MCP 서버 제공 도구:**

| 도구 | 기능 |
|------|------|
| `projects_list` | 프로젝트 목록 조회 |
| `projects_get` | 프로젝트 상세 (필드, 아이템 포함) |
| `projects_write` | 아이템 생성/수정/삭제/아카이브 |
| `create_issue` | 이슈 생성 |
| `update_issue` | 이슈 수정 |
| `search_issues` | 이슈 검색 |
| `list_issues` | 이슈 목록 |
| `create_pull_request` | PR 생성 |

### 4.2 gh CLI 설정

```bash
# 인증 (project 스코프 추가)
gh auth refresh -s project

# 프로젝트 생성
gh project create --owner <USERNAME> --title "Workspace Kanban"

# 프로젝트 번호 확인
gh project list --owner <USERNAME>

# 커스텀 필드 추가
gh project field-create <PROJECT_NUMBER> --owner <USERNAME> \
  --name "Project" --data-type "SINGLE_SELECT"

gh project field-create <PROJECT_NUMBER> --owner <USERNAME> \
  --name "Priority" --data-type "SINGLE_SELECT"

gh project field-create <PROJECT_NUMBER> --owner <USERNAME> \
  --name "Type" --data-type "SINGLE_SELECT"

gh project field-create <PROJECT_NUMBER> --owner <USERNAME> \
  --name "Effort" --data-type "NUMBER"
```

### 4.3 이슈 템플릿

```yaml
# .github/ISSUE_TEMPLATE/feature.yml
name: Feature Request
description: 새 기능 요청
labels: ["type:feature"]
body:
  - type: dropdown
    id: project
    attributes:
      label: Project
      options:
        - claude-workspace
        - shipkit
        - unity-game
        - infra
    validations:
      required: true
  - type: dropdown
    id: priority
    attributes:
      label: Priority
      options:
        - "🔴 P0 Critical"
        - "🟠 P1 High"
        - "🟡 P2 Medium"
        - "🟢 P3 Low"
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Description
      description: 구현할 기능 설명
    validations:
      required: true
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance Criteria
      description: 완료 기준
      value: |
        - [ ]
        - [ ]
```

```yaml
# .github/ISSUE_TEMPLATE/bugfix.yml
name: Bug Report
description: 버그 리포트
labels: ["type:bugfix"]
body:
  - type: dropdown
    id: project
    attributes:
      label: Project
      options:
        - claude-workspace
        - shipkit
        - unity-game
        - infra
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Bug Description
      description: 무엇이 잘못되었는지
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
      description: 재현 단계
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
      description: 기대 동작
```

### 4.4 GitHub Actions 자동화

```yaml
# .github/workflows/project-automation.yml
name: Project Automation

on:
  issues:
    types: [opened, labeled]
  pull_request:
    types: [opened, ready_for_review, closed]

jobs:
  add-to-project:
    name: Add to Kanban
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v1
        with:
          project-url: https://github.com/users/<USERNAME>/projects/<NUMBER>
          github-token: ${{ secrets.PROJECT_TOKEN }}

  auto-move-in-progress:
    name: Move to In Progress on branch creation
    if: github.event_name == 'create' && github.ref_type == 'branch'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PROJECT_TOKEN }}
          script: |
            // 브랜치명에서 이슈 번호 추출 후 상태 변경
            const branchName = context.ref.replace('refs/heads/', '');
            const issueMatch = branchName.match(/(\d+)/);
            if (issueMatch) {
              // GraphQL로 프로젝트 아이템 상태 업데이트
            }

  auto-move-on-pr:
    name: Move to In Review on PR
    if: github.event_name == 'pull_request' && github.event.action == 'opened'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PROJECT_TOKEN }}
          script: |
            // PR에 연결된 이슈를 In Review로 이동

  auto-close-on-merge:
    name: Move to Done on merge
    if: github.event_name == 'pull_request' && github.event.action == 'closed' && github.event.pull_request.merged
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PROJECT_TOKEN }}
          script: |
            // 머지된 PR의 이슈를 Done으로 이동
```

---

## 5. Claude Code 워크플로우

### 5.1 세션 시작 시 (모니터링)

```
사용자: "현재 프로젝트 상황 보여줘"

Claude Code 동작:
1. GitHub MCP → projects_get 호출
2. 보드 현황 요약:
   - Backlog: 12건
   - Todo: 5건
   - In Progress: 2건
   - In Review: 1건
   - Done (이번 주): 8건
3. 프로젝트별 분류 표시
4. P0/P1 이슈 하이라이트
```

### 5.2 작업 시작 시

```
사용자: "다음 작업 시작하자"

Claude Code 동작:
1. GitHub MCP → Todo 컬럼에서 우선순위 높은 이슈 조회
2. 이슈 목록 제시
3. 사용자 선택 후:
   a. 이슈 상태 → In Progress로 변경
   b. 브랜치 생성 (feat/#123-description)
   c. 작업 시작
```

### 5.3 작업 완료 시

```
사용자: "이 작업 완료, PR 올려줘"

Claude Code 동작:
1. 변경사항 커밋
2. gh pr create (이슈 번호 참조: Closes #123)
3. 이슈 상태 → In Review
4. PR 머지 후 → Done 자동 이동
```

### 5.4 CLI 빠른 참조

```bash
# ── 보드 조회 ──
gh project list --owner <USER>
gh project item-list <NUM> --owner <USER> --format json

# ── 이슈 관리 ──
gh issue create --title "feat: 새 기능" --label "type:feature,project:agentops"
gh issue list --label "project:agentops" --state open
gh issue list --label "priority:critical" --state open
gh issue view 123

# ── 프로젝트에 추가 ──
gh project item-add <PROJECT_NUM> --owner <USER> --url <ISSUE_URL>

# ── 상태 변경 ──
gh project field-list <NUM> --owner <USER> --format json  # 필드 ID 조회
gh project item-edit --id <ITEM_ID> --project-id <PROJECT_ID> \
  --field-id <STATUS_FIELD_ID> --single-select-option-id <TODO_OPTION_ID>

# ── PR 연동 ──
gh pr create --title "feat: 기능 추가" --body "Closes #123"
gh pr list --state open
gh pr merge <PR_NUM>

# ── 대시보드 (웹) ──
gh project view <NUM> --owner <USER> --web
```

---

## 6. 모니터링 대시보드

### 6.1 CLI 기반 대시보드 스크립트

```bash
#!/bin/bash
# scripts/kanban-status.sh — 프로젝트 현황 조회

OWNER="<USERNAME>"
PROJECT_NUM="<NUMBER>"

echo "═══════════════════════════════════════"
echo "  📊 Workspace Kanban Dashboard"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "═══════════════════════════════════════"

# 전체 아이템 조회
ITEMS=$(gh project item-list $PROJECT_NUM --owner $OWNER --format json)

echo ""
echo "📋 Backlog:      $(echo $ITEMS | jq '[.items[] | select(.status == "Backlog")] | length')"
echo "📌 Todo:         $(echo $ITEMS | jq '[.items[] | select(.status == "Todo")] | length')"
echo "🔨 In Progress:  $(echo $ITEMS | jq '[.items[] | select(.status == "In Progress")] | length')"
echo "👀 In Review:    $(echo $ITEMS | jq '[.items[] | select(.status == "In Review")] | length')"
echo "✅ Done:         $(echo $ITEMS | jq '[.items[] | select(.status == "Done")] | length')"

echo ""
echo "── 🔴 Critical Issues ──"
gh issue list --label "priority:critical" --state open --json number,title \
  --jq '.[] | "#\(.number) \(.title)"'

echo ""
echo "── 🔨 Currently In Progress ──"
echo $ITEMS | jq -r '.items[] | select(.status == "In Progress") | "  \(.title)"'

echo ""
echo "── 📊 By Project ──"
for proj in "agentops" "shipkit" "unity-game" "infra"; do
  count=$(gh issue list --label "project:$proj" --state open --json number --jq 'length')
  echo "  $proj: $count open issues"
done

echo "═══════════════════════════════════════"
```

### 6.2 Claude Code 내장 모니터링

Claude Code 세션에서 MCP를 통해 직접 호출:

```
"보드 현황" → projects_get → 요약 출력
"이번 주 완료 건" → search_issues(closed this week) → 목록
"블로킹 이슈" → search_issues(label:blocked) → 목록
"프로젝트별 현황" → 필터링된 이슈 카운트
```

---

## 7. 구현 로드맵

### Phase 1: 기반 구축 (Day 1)

| 단계 | 작업 | 소요 |
|------|------|------|
| 1-1 | GitHub PAT 생성 (repo + project 스코프) | 5분 |
| 1-2 | `gh auth refresh -s project` 인증 | 2분 |
| 1-3 | GitHub Project 생성 + 컬럼/필드 설정 | 15분 |
| 1-4 | 라벨 일괄 생성 | 10분 |
| 1-5 | GitHub MCP 서버 설치 + Claude Code 연결 | 10분 |

### Phase 2: 콘텐츠 이관 (Day 1-2)

| 단계 | 작업 | 소요 |
|------|------|------|
| 2-1 | 기존 `plans/` 로드맵에서 이슈 추출 | 30분 |
| 2-2 | 이슈 일괄 생성 (gh issue create 스크립트) | 20분 |
| 2-3 | 프로젝트 보드에 이슈 배치 | 15분 |
| 2-4 | 우선순위/라벨 지정 | 15분 |

### Phase 3: 자동화 (Day 2-3)

| 단계 | 작업 | 소요 |
|------|------|------|
| 3-1 | 이슈 템플릿 작성 (.github/ISSUE_TEMPLATE/) | 15분 |
| 3-2 | GitHub Actions 워크플로우 작성 | 30분 |
| 3-3 | 대시보드 스크립트 작성 | 20분 |
| 3-4 | Claude Code 워크플로우 테스트 | 15분 |

### Phase 4: 운영 안정화 (Week 1-2)

| 단계 | 작업 | 소요 |
|------|------|------|
| 4-1 | 실제 작업 사이클 2회 수행 | 지속 |
| 4-2 | 불편사항 수집 및 개선 | 필요시 |
| 4-3 | 자동화 규칙 튜닝 | 필요시 |
| 4-4 | CLAUDE.md에 칸반 워크플로우 추가 | 10분 |

---

## 8. 비용 분석

| 항목 | 비용 | 비고 |
|------|------|------|
| GitHub Free | $0/월 | 무제한 프로젝트, 이슈 |
| GitHub Actions | $0/월 | 공개 레포 무제한, 비공개 2000분/월 |
| GitHub MCP Server | $0 | 오픈소스 |
| gh CLI | $0 | 공식 무료 도구 |
| **총 비용** | **$0/월** | |

---

## 9. 대안 시나리오

### 9.1 GitHub Projects 불만족 시 → Linear 전환

**전환 트리거:**
- GitHub Projects UI가 복잡한 워크플로우에 부족함을 느낄 때
- Cycles, Roadmaps 등 고급 PM 기능이 필요할 때
- 팀 확장으로 협업 기능이 중요해질 때

**전환 비용:**
- Linear 무료 (250 활성 이슈 제한)
- Standard: $8/user/month (무제한)
- MCP 서버: `claude mcp add linear --url https://mcp.linear.app/sse`
- CLI: `npx jsr install @schpet/linear-cli`

### 9.2 AI 에이전트 집중 시 → kanban-md 보조 도입

**도입 트리거:**
- Claude Code 세션 내 세부 태스크 분해가 빈번할 때
- TodoWrite만으로 세션 간 태스크 추적이 부족할 때

**구성:**
- GitHub Projects (전략적 이슈 관리) + kanban-md (세션별 전술적 태스크)
- kanban-md 파일은 Git에 커밋 → 히스토리 추적

### 9.3 셀프호스팅 원할 시 → Plane.so

**도입 트리거:**
- 데이터 주권이 중요해질 때
- GitHub 외부 도구 선호 시

**구성:**
- Docker Compose로 로컬/VPS 배포
- 공식 MCP 서버 (55+ 도구)

---

## 10. 성공 기준

| 기준 | 측정 방법 |
|------|----------|
| 모든 작업이 이슈로 추적됨 | 이슈 없이 코드 변경 없음 |
| Claude Code에서 보드 조회 가능 | MCP로 실시간 현황 확인 |
| 이슈 → 브랜치 → PR → 완료 자동화 | 수동 상태 변경 최소화 |
| 프로젝트별 현황 한눈에 파악 | 대시보드 스크립트 또는 웹 보드 |
| 세션 시작 시 30초 내 현황 파악 | CLI/MCP 응답 속도 |

---

## 11. 참고 자료

### 공식 문서
- [GitHub Projects v2 Docs](https://docs.github.com/en/issues/planning-and-tracking-with-projects)
- [gh project CLI Manual](https://cli.github.com/manual/gh_project)
- [GitHub MCP Server](https://github.com/github/github-mcp-server)
- [GitHub Projects API (GraphQL)](https://docs.github.com/en/issues/planning-and-tracking-with-projects/automating-your-project/using-the-api-to-manage-projects)

### 대안 도구
- [Linear](https://linear.app) — 공식 MCP: `https://mcp.linear.app/sse`
- [Plane.so](https://plane.so) — 공식 MCP: `plane-mcp-server`
- [kanban-md](https://github.com/antopolskiy/kanban-md) — 파일 기반 칸반
- [Flux](https://github.com/sirsjg/flux) — Git-네이티브 칸반 + MCP

### MCP 서버 비교
- [GitHub MCP Server Changelog (2026-01)](https://github.blog/changelog/2026-01-28-github-mcp-server-new-projects-tools-oauth-scope-filtering-and-new-features/)
- [Linear MCP Changelog](https://linear.app/changelog/2025-05-01-mcp)
- [Plane MCP for Claude Code](https://developers.plane.so/dev-tools/mcp-server-claude-code)
