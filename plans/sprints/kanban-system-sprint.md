# Kanban 모니터링 시스템 — 스프린트 실행 계획

> 생성일: 2026-03-02 | PM Agent (0-4)
> 원본 스펙: `docs/kanban-monitoring-spec.md`
> 프로젝트 유형: 내부 인프라 (수익 없음, 생산성 도구)

---

## 프로젝트 메타데이터

- **코드명:** `kanban-ops`
- **목표:** 워크스페이스 전체 프로젝트를 GitHub Projects 칸반으로 통합 관리
- **총 소요:** 3일 (Sprint 1~3) + 2주 안정화 (Sprint 4)
- **비용:** $0/월
- **성공 기준:** 세션 시작 30초 내 전체 프로젝트 현황 파악 가능

---

## 의존성 그래프

```
Sprint 1: 기반 구축 (인증 + 프로젝트 + MCP)
    │
    ├── Sprint 2: 콘텐츠 구축 (라벨 + 이슈 + 템플릿)
    │       │
    │       └── Sprint 3: 자동화 (Actions + 대시보드 + 스킬)
    │               │
    │               └── Sprint 4: 안정화 (실사용 + 튜닝)
    │
    └── [병렬 가능] MCP 서버 테스트
```

---

## Sprint 1: 기반 구축

> **기간:** Day 1 전반 (~1시간)
> **목표:** GitHub Projects 보드 생성 + MCP 연결 + gh CLI 인증 완료

### 태스크

| # | 태스크 | 담당 에이전트 | 소요 | 완료 기준 |
|---|--------|-------------|------|----------|
| 1-1 | GitHub PAT 생성 (repo + project + read:org 스코프) | **사용자** (수동) | 5분 | PAT 토큰 발급 확인 |
| 1-2 | `gh auth refresh -s project` 인증 | fullstack-developer | 2분 | `gh auth status`에 project 스코프 표시 |
| 1-3 | GitHub Project 생성: "Workspace Kanban" | fullstack-developer | 5분 | `gh project list`에 표시 |
| 1-4 | Status 컬럼 설정 (Backlog → Todo → In Progress → In Review → Done) | fullstack-developer | 5분 | 웹에서 5개 컬럼 확인 |
| 1-5 | 커스텀 필드 생성 (Project, Priority, Type, Effort) | fullstack-developer | 10분 | `gh project field-list`에 4개 필드 표시 |
| 1-6 | GitHub MCP 서버 설치 + Claude Code 연결 | fullstack-developer | 10분 | MCP 서버 도구 목록 조회 성공 |
| 1-7 | MCP 연동 테스트 (projects_list 호출) | fullstack-developer | 5분 | 프로젝트 목록 반환 확인 |

### 실행 명령어 (참조)

```bash
# 1-2: 인증
gh auth refresh -s project

# 1-3: 프로젝트 생성
gh project create --owner <USERNAME> --title "Workspace Kanban"

# 1-5: 필드 생성
PROJECT_NUM=$(gh project list --owner <USERNAME> --format json --jq '.projects[0].number')

gh project field-create $PROJECT_NUM --owner <USERNAME> \
  --name "Project" --data-type "SINGLE_SELECT"
gh project field-create $PROJECT_NUM --owner <USERNAME> \
  --name "Priority" --data-type "SINGLE_SELECT"
gh project field-create $PROJECT_NUM --owner <USERNAME> \
  --name "Type" --data-type "SINGLE_SELECT"
gh project field-create $PROJECT_NUM --owner <USERNAME> \
  --name "Effort" --data-type "NUMBER"

# 1-6: MCP 서버 설치
claude mcp add github-mcp -- npx -y @anthropic-ai/github-mcp-server
```

### Sprint 1 완료 조건
- [ ] `gh project list`에 "Workspace Kanban" 표시
- [ ] 5개 Status 컬럼 + 4개 커스텀 필드 생성 완료
- [ ] Claude Code에서 MCP를 통해 프로젝트 조회 가능

---

## Sprint 2: 콘텐츠 구축

> **기간:** Day 1 후반 ~ Day 2 전반 (~2시간)
> **목표:** 라벨 체계 생성 + 이슈 템플릿 + 초기 이슈 등록
> **의존:** Sprint 1 완료

### 태스크

| # | 태스크 | 담당 에이전트 | 소요 | 완료 기준 |
|---|--------|-------------|------|----------|
| 2-1 | 라벨 일괄 생성 스크립트 작성 + 실행 | fullstack-developer | 15분 | 16개 라벨 생성 확인 |
| 2-2 | 이슈 템플릿 작성 (feature.yml, bugfix.yml, chore.yml) | technical-writer | 15분 | `.github/ISSUE_TEMPLATE/` 3개 파일 |
| 2-3 | 이슈 템플릿 config.yml 작성 (빈 이슈 방지) | technical-writer | 5분 | config.yml 생성 |
| 2-4 | 초기 이슈 일괄 등록 스크립트 작성 | fullstack-developer | 20분 | 스크립트 파일 생성 |
| 2-5 | 프로젝트별 초기 이슈 등록 실행 | fullstack-developer | 15분 | 프로젝트 보드에 이슈 배치 |
| 2-6 | 이슈에 우선순위/프로젝트 라벨 지정 | fullstack-developer | 15분 | 모든 이슈에 라벨 부착 |

### 라벨 목록 (2-1)

```bash
#!/bin/bash
# scripts/create-labels.sh

REPO="<OWNER>/<REPO>"

# 프로젝트별 (파랑 계열)
gh label create "project:agentops"    --repo $REPO --color "1d76db" --description "AgentOps 플랫폼"
gh label create "project:shipkit"     --repo $REPO --color "0075ca" --description "ShipKit 보일러플레이트"
gh label create "project:unity-game"  --repo $REPO --color "0052cc" --description "Unity 모바일 게임"
gh label create "project:infra"       --repo $REPO --color "003d99" --description "인프라/CI/CD"

# 유형별 (초록 계열)
gh label create "type:feature"   --repo $REPO --color "0e8a16" --description "새 기능"
gh label create "type:bugfix"    --repo $REPO --color "d93f0b" --description "버그 수정"
gh label create "type:refactor"  --repo $REPO --color "fbca04" --description "리팩토링"
gh label create "type:docs"      --repo $REPO --color "0075ca" --description "문서화"
gh label create "type:test"      --repo $REPO --color "bfd4f2" --description "테스트"
gh label create "type:chore"     --repo $REPO --color "ededed" --description "잡무/설정"

# 우선순위 (빨-주-노-초)
gh label create "priority:critical" --repo $REPO --color "b60205" --description "즉시 처리"
gh label create "priority:high"     --repo $REPO --color "d93f0b" --description "이번 주 내"
gh label create "priority:medium"   --repo $REPO --color "fbca04" --description "이번 스프린트 내"
gh label create "priority:low"      --repo $REPO --color "0e8a16" --description "여유 있을 때"

# 상태 보조
gh label create "blocked"          --repo $REPO --color "000000" --description "외부 의존성으로 블록됨"
gh label create "needs-review"     --repo $REPO --color "7057ff" --description "리뷰 필요"
```

### 이슈 템플릿 (2-2, 2-3)

**파일:** `.github/ISSUE_TEMPLATE/feature.yml`
```yaml
name: Feature Request
description: 새 기능 요청
labels: ["type:feature"]
body:
  - type: dropdown
    id: project
    attributes:
      label: Project
      options:
        - agentops
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
        - "critical"
        - "high"
        - "medium"
        - "low"
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Description
    validations:
      required: true
  - type: textarea
    id: acceptance
    attributes:
      label: Acceptance Criteria
      value: |
        - [ ]
```

**파일:** `.github/ISSUE_TEMPLATE/bugfix.yml`
```yaml
name: Bug Report
description: 버그 리포트
labels: ["type:bugfix"]
body:
  - type: dropdown
    id: project
    attributes:
      label: Project
      options:
        - agentops
        - shipkit
        - unity-game
        - infra
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Bug Description
    validations:
      required: true
  - type: textarea
    id: steps
    attributes:
      label: Steps to Reproduce
  - type: textarea
    id: expected
    attributes:
      label: Expected Behavior
```

**파일:** `.github/ISSUE_TEMPLATE/chore.yml`
```yaml
name: Chore / Task
description: 설정, 리팩토링, 유지보수 작업
labels: ["type:chore"]
body:
  - type: dropdown
    id: project
    attributes:
      label: Project
      options:
        - agentops
        - shipkit
        - unity-game
        - infra
    validations:
      required: true
  - type: textarea
    id: description
    attributes:
      label: Task Description
    validations:
      required: true
```

**파일:** `.github/ISSUE_TEMPLATE/config.yml`
```yaml
blank_issues_enabled: false
contact_links:
  - name: General Discussion
    url: https://github.com/<OWNER>/<REPO>/discussions
    about: 일반 논의는 Discussions에서
```

### Sprint 2 완료 조건
- [ ] 16개 라벨 생성 (`gh label list`로 확인)
- [ ] 3개 이슈 템플릿 + config.yml 생성
- [ ] 최소 10개 초기 이슈가 보드에 배치됨
- [ ] 모든 이슈에 project/priority 라벨 부착

---

## Sprint 3: 자동화 & 모니터링

> **기간:** Day 2 후반 ~ Day 3 (~2시간)
> **목표:** GitHub Actions 자동화 + 대시보드 스크립트 + Claude Code 스킬
> **의존:** Sprint 2 완료

### 태스크

| # | 태스크 | 담당 에이전트 | 소요 | 완료 기준 |
|---|--------|-------------|------|----------|
| 3-1 | GitHub Actions: 이슈 → 프로젝트 자동 추가 | fullstack-developer | 15분 | 이슈 생성 시 보드에 자동 추가 |
| 3-2 | GitHub Actions: PR 이벤트 → 상태 자동 이동 | fullstack-developer | 20min | PR 생성→In Review, 머지→Done |
| 3-3 | 대시보드 스크립트 (`scripts/kanban-status.sh`) | fullstack-developer | 20분 | 터미널에서 현황 출력 |
| 3-4 | Claude Code 칸반 스킬 작성 (`/kanban`) | fullstack-developer | 30분 | `/kanban` 명령으로 보드 조회 |
| 3-5 | CLAUDE.md에 칸반 워크플로우 섹션 추가 | technical-writer | 10분 | 워크플로우 문서화 |
| 3-6 | 통합 테스트 (이슈 생성 → 보드 확인 → 상태 이동) | fullstack-developer | 15분 | E2E 플로우 검증 |

### GitHub Actions (3-1, 3-2)

**파일:** `.github/workflows/project-automation.yml`
```yaml
name: Project Kanban Automation

on:
  issues:
    types: [opened]
  pull_request:
    types: [opened, closed]

env:
  PROJECT_URL: https://github.com/users/<USERNAME>/projects/<NUMBER>

jobs:
  add-issue-to-project:
    name: Add issue to Kanban
    if: github.event_name == 'issues'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/add-to-project@v1
        with:
          project-url: ${{ env.PROJECT_URL }}
          github-token: ${{ secrets.PROJECT_TOKEN }}

  move-pr-to-review:
    name: Move linked issue to In Review
    if: github.event_name == 'pull_request' && github.event.action == 'opened'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PROJECT_TOKEN }}
          script: |
            const body = context.payload.pull_request.body || '';
            const issueNumbers = [...body.matchAll(/(closes?|fixes?|resolves?)\s+#(\d+)/gi)]
              .map(m => parseInt(m[2]));

            if (issueNumbers.length > 0) {
              console.log(`Found linked issues: ${issueNumbers.join(', ')}`);
              // Note: Status change requires GraphQL mutation
              // which is set up in the project's built-in automation
            }

  close-issue-on-merge:
    name: Auto-close on merge
    if: >
      github.event_name == 'pull_request' &&
      github.event.action == 'closed' &&
      github.event.pull_request.merged
    runs-on: ubuntu-latest
    steps:
      - uses: actions/github-script@v7
        with:
          github-token: ${{ secrets.PROJECT_TOKEN }}
          script: |
            console.log('PR merged — linked issues will auto-close via GitHub');
            // GitHub의 built-in "Closes #N" 기능이 자동 처리
```

### 대시보드 스크립트 (3-3)

**파일:** `scripts/kanban-status.sh`
```bash
#!/bin/bash
# kanban-status.sh — 프로젝트 현황 대시보드
set -euo pipefail

OWNER="${GH_OWNER:-<USERNAME>}"
PROJECT_NUM="${GH_PROJECT_NUM:-1}"

echo ""
echo "  Workspace Kanban Dashboard"
echo "  $(date '+%Y-%m-%d %H:%M')"
echo "  ─────────────────────────────"

# 전체 이슈 현황
OPEN=$(gh issue list --state open --json number --jq 'length' 2>/dev/null || echo "?")
CLOSED=$(gh issue list --state closed --json number --jq 'length' 2>/dev/null || echo "?")

echo ""
echo "  Open: $OPEN | Closed: $CLOSED"
echo ""

# 프로젝트별
echo "  -- By Project --"
for proj in "agentops" "shipkit" "unity-game" "infra"; do
  count=$(gh issue list --label "project:$proj" --state open --json number --jq 'length' 2>/dev/null || echo "0")
  printf "  %-15s %s open\n" "$proj" "$count"
done

echo ""

# 우선순위별
echo "  -- By Priority --"
for pri in "critical" "high" "medium" "low"; do
  count=$(gh issue list --label "priority:$pri" --state open --json number --jq 'length' 2>/dev/null || echo "0")
  printf "  %-15s %s\n" "$pri" "$count"
done

echo ""

# Critical 이슈 상세
CRITICAL=$(gh issue list --label "priority:critical" --state open --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null || echo "")
if [ -n "$CRITICAL" ]; then
  echo "  -- Critical Issues --"
  echo "$CRITICAL" | while read line; do
    echo "  $line"
  done
  echo ""
fi

echo "  ─────────────────────────────"
echo "  Web: gh project view $PROJECT_NUM --owner $OWNER --web"
echo ""
```

### Claude Code 칸반 스킬 (3-4)

**파일:** `.claude/commands/kanban.md`
```markdown
# /kanban — 프로젝트 칸반 보드 관리

GitHub Projects 칸반 보드를 CLI에서 관리합니다.

## 사용법

- `/kanban` — 전체 현황 대시보드
- `/kanban list [project]` — 프로젝트별 이슈 목록
- `/kanban add <title> --project <name> --priority <level>` — 이슈 생성
- `/kanban start <issue-number>` — 이슈 작업 시작 (브랜치 생성)
- `/kanban done <issue-number>` — 이슈 완료 처리

## 실행

$ARGUMENTS 를 파싱합니다:

### 인자 없음 (대시보드)
1. `scripts/kanban-status.sh` 실행
2. 또는 `gh project item-list <NUM> --owner <OWNER> --format json`으로 보드 조회
3. 컬럼별 아이템 수 + Critical 이슈 + 프로젝트별 현황 요약 출력

### `list [project]`
1. `gh issue list --label "project:<project>" --state open --json number,title,labels`
2. 우선순위별 정렬하여 출력

### `add <title> --project <name> --priority <level>`
1. `gh issue create --title "<title>" --label "project:<name>,priority:<level>"`
2. 생성된 이슈 URL 출력

### `start <issue-number>`
1. `gh issue view <number>` 로 이슈 정보 확인
2. 이슈 제목에서 브랜치명 생성: `feat/#<number>-<slug>`
3. `git checkout -b <branch-name>`
4. 이슈에 "작업 시작" 코멘트 추가

### `done <issue-number>`
1. 현재 브랜치 확인
2. `gh pr create --title "<이슈 제목>" --body "Closes #<number>"`
3. PR URL 출력
```

### Sprint 3 완료 조건
- [ ] 이슈 생성 시 프로젝트 보드에 자동 추가됨
- [ ] `scripts/kanban-status.sh` 실행 시 현황 출력
- [ ] `/kanban` 커맨드 동작 확인
- [ ] CLAUDE.md에 칸반 워크플로우 섹션 추가됨
- [ ] E2E 테스트 통과 (이슈 생성 → 보드 확인)

---

## Sprint 4: 운영 안정화

> **기간:** Week 1~2 (지속)
> **목표:** 실사용 피드백 반영 + 워크플로우 튜닝
> **의존:** Sprint 3 완료

### 태스크

| # | 태스크 | 담당 에이전트 | 소요 | 완료 기준 |
|---|--------|-------------|------|----------|
| 4-1 | 실제 코딩 세션에서 칸반 워크플로우 2회 수행 | fullstack-developer | 지속 | 이슈→브랜치→PR→Done 사이클 완료 |
| 4-2 | Actions 자동화 오류 수정 | fullstack-developer | 필요시 | 에러 없음 |
| 4-3 | 대시보드 스크립트 개선 | fullstack-developer | 필요시 | 사용자 피드백 반영 |
| 4-4 | 메모리에 칸반 운영 패턴 기록 | technical-writer | 10분 | MEMORY.md 업데이트 |
| 4-5 | 불필요한 자동화 규칙 제거/단순화 | fullstack-developer | 필요시 | 규칙 최적화 |

### Sprint 4 완료 조건
- [ ] 2회 이상 완전한 이슈-PR 사이클 수행
- [ ] 세션 시작 30초 내 현황 파악 가능
- [ ] 팀 에이전트들이 이슈 기반으로 작업 수행 가능

---

## 에이전트 매핑 요약

| Sprint | 주 담당 에이전트 | 보조 에이전트 | 사용자 개입 |
|--------|----------------|-------------|-----------|
| Sprint 1 | fullstack-developer | - | PAT 생성 (수동) |
| Sprint 2 | fullstack-developer | technical-writer | 초기 이슈 내용 검토 |
| Sprint 3 | fullstack-developer | technical-writer | Actions secret 설정 |
| Sprint 4 | fullstack-developer | technical-writer | 피드백 제공 |

### 에이전트 호출 시퀀스

```
[PM Agent] ─── 이 스프린트 계획 생성 (완료)
     │
     ▼
[fullstack-developer] ─── Sprint 1: 기반 구축
     │                     gh CLI + MCP 서버 설정
     │
     ├─▶ [fullstack-developer] ─── Sprint 2: 콘텐츠
     │    │                        라벨 + 이슈 생성 스크립트
     │    │
     │    └─▶ [technical-writer] ─── 이슈 템플릿 작성
     │
     ├─▶ [fullstack-developer] ─── Sprint 3: 자동화
     │    │                        Actions + 대시보드 + 스킬
     │    │
     │    └─▶ [technical-writer] ─── CLAUDE.md 업데이트
     │
     └─▶ [fullstack-developer] ─── Sprint 4: 안정화
          │
          └─▶ [technical-writer] ─── MEMORY.md 기록
```

---

## 리스크 & 완화

| 리스크 | 확률 | 영향 | 완화 전략 |
|--------|------|------|-----------|
| GitHub MCP 서버 설치 실패 | 중 | 높음 | `gh` CLI 직접 사용으로 대체 |
| PAT 스코프 부족 | 낮음 | 중 | `gh auth refresh -s project` 재실행 |
| Actions 자동화 복잡성 과다 | 중 | 중 | 최소한의 자동화만 적용, 점진적 추가 |
| 이슈 관리 오버헤드 | 중 | 중 | 규모에 맞게 단순하게 운영 |

---

## 즉시 실행 가능 액션

```
1. [사용자] GitHub PAT 생성 (Settings → Developer settings → PAT)
   - 스코프: repo, project, read:org

2. [Claude Code] Sprint 1 실행 시작
   - gh auth + 프로젝트 생성 + MCP 설치

3. [Claude Code] Sprint 2~3 순차 실행
```

이 계획을 승인하시면 Sprint 1부터 즉시 실행하겠습니다.
