# multi-ai-orchestration

Gemini CLI + Claude Code + Codex CLI를 최적 역할에 따라 조합하여 Multi-AI-Agent 워크플로우를 실행하는 오케스트레이션 가이드.

## 역할

Multi-AI 오케스트레이터 — 각 AI CLI 도구의 강점을 분석하여 작업 유형에 맞게 배분하고, 통합 도구(MCO / Claude Octopus / Ruflo)를 활용해 병렬·순차·계층형 워크플로우를 설계·실행한다.

## 수행 가능 작업

### 1. 도구별 최적 역할 선택
작업 유형을 분류하고 Gemini CLI / Claude Code / Codex CLI 중 최적 도구를 결정한다.

### 2. 통합 도구 실행
MCO, Claude Octopus, Ruflo를 사용해 멀티 에이전트 워크플로우를 실행한다.

### 3. 오케스트레이션 패턴 적용
작업 구조에 따라 Sequential / Parallel / Hierarchical / Debate / Iterative 패턴 중 하나를 선택하여 적용한다.

### 4. 연구 기반 의사결정
AFlow, ACL 2025, LLM Survey 등 최신 연구 결과를 근거로 에이전트 수, 투표 방식, 워크플로우 구조를 결정한다.

---

## 도구별 최적 역할

### Gemini CLI

| 항목 | 내용 |
|------|------|
| 컨텍스트 | 1M 토큰 (Claude/Codex 대비 5~10배) |
| 가격 | 무료 (1,000 req/일) |
| 설치 | `npx @google/gemini-cli` (설치 없음) |
| 특징 | Google Search 그라운딩 내장, PTY 지원 (`vim`/`git rebase` 등), 멀티모달 (이미지/PDF/영상/Google Docs) |

**최적 용도**: 리서치, 대용량 코드베이스 전체 분석, 기술 문서 요약, 최신 정보 조사, 경쟁사/생태계 조사

**선택 기준**: 입력 토큰이 많거나(50K+), 최신 웹 정보가 필요하거나, 비용을 절감해야 할 때

---

### Claude Code

| 항목 | 내용 |
|------|------|
| 코드 정확도 | ~95% (생성 코드의 95%가 수정 없이 작동) |
| 통합 | MCP(Model Context Protocol)로 테스트 러너/DB/API 연결 |
| 병렬 실행 | Agent Teams (실험적) — 다중 인스턴스 병렬 실행 지원 |
| 강점 | 자율 멀티파일 리팩토링, 정밀 구현 |

**최적 용도**: 정밀 코드 구현, 오케스트레이터 역할, 멀티파일 동시 변경, 최종 검증 및 통합

**선택 기준**: 코드 정확도가 중요하거나, 여러 파일을 일관성 있게 수정하거나, 최종 의사결정이 필요할 때

---

### Codex CLI

| 항목 | 내용 |
|------|------|
| 구현 | Rust 기반 고성능 (속도 최적화) |
| 샌드박스 | 3단계: Read-only → Auto → Full Access |
| CI/CD | GitHub Actions 네이티브: `openai/codex-action@v1` |
| 자동화 | PR/Issue에서 `@codex` 멘션으로 작업 자동 트리거 |

**최적 용도**: CI/CD 자동화, 보안 격리 실행, 반복 테스트 수정, PR 기반 자동 작업

**선택 기준**: 격리된 환경에서 반복 실행이 필요하거나, GitHub Actions 파이프라인에 통합해야 할 때

---

## 핵심 통합 도구 3선

### MCO (Multi-CLI Orchestrator)

- **저장소**: https://github.com/mco-org/mco
- **설치**: `npm i -g @tt-a1i/mco`

**핵심 장점**:
- wait-all 시맨틱으로 세 CLI를 동시 병렬 실행 — 총 실행시간 = 가장 느린 에이전트 시간 (직렬 대비 최대 3배 단축)
- 교차 에이전트 중복 이슈 제거 + `detected_by` 필드로 발견 주체 추적
- 출력 형식 선택: `report` / `markdown-pr` / `sarif` / `json`

**핵심 명령**:
```bash
# 세 에이전트 동시 보안 검토
mco review --repo . --prompt "보안 검토" --providers claude,codex,gemini

# 합성 결과 생성
mco review --providers claude,codex,gemini --synthesize

# 아키텍처 분석 병렬 실행
mco run --providers claude,gemini --prompt "아키텍처 분석"

# PR용 마크다운 출력
mco review --providers claude,codex,gemini --synthesize --format markdown-pr
```

---

### Claude Octopus

- **저장소**: https://github.com/nyldn/claude-octopus
- **추가 비용**: 없음 (기존 구독 OAuth 활용)

**핵심 장점**:
- Double Diamond 4단계 구조: Discover → Define → Develop → Deliver
- 75% 합의 게이트: 2/3 에이전트 동의해야 다음 단계 진행
- 역할 최적 분담: Codex(구현 깊이) + Gemini(생태계 폭) + Claude(오케스트레이터)

**핵심 명령**:
```
/octo:embrace    # 전체 4단계 Double Diamond 워크플로우
/octo:debate     # 3자 합의 기반 토론 (경쟁 의견 수렴)
/octo:review     # 다각 관점 코드 검토
/octo:security   # OWASP 기반 취약점 스캔
/octo:research   # 다중 소스 합성 리서치
```

---

### Ruflo (Swarm Intelligence)

- **저장소**: https://github.com/ruvnet/ruflo

**핵심 장점**:
- Q-Learning 자기학습 라우터 — 사용할수록 최적 에이전트 선택 능력 향상
- 60+ 전문화 에이전트 (Researcher / Coder / Analyst / Tester / Architect 등)
- Agent Booster (WASM): 단순 변환 작업 <1ms, LLM 대비 352배 빠름
- 토큰 30~50% 절감
- Byzantine 내결함성 투표: `f < n/3` 조건으로 신뢰성 보장

**아키텍처**:
```
User → CLI/MCP → Q-Learning Router → Swarm → 60+ Agents → LLM Providers
                       ^
                  자기학습 피드백 루프 (작업 결과 → 라우터 가중치 갱신)
```

---

## 연구 인사이트

### AFlow (ICLR 2025 Oral, 상위 1.8%)

- **방법**: Monte Carlo Tree Search로 워크플로우 공간 자동 탐색
- **성과**: 6개 벤치마크 평균 5.7% SOTA 대비 향상 / GPT-4o 비용의 4.55%로 소형 모델이 GPT-4o 능가
- **핵심 교훈**: 워크플로우 설계 자체를 최적화하라. 에이전트 품질보다 워크플로우 구조가 더 큰 성과 차이를 만든다.

### Voting vs Consensus (ACL 2025)

| 작업 유형 | 권장 방식 | 효과 |
|-----------|-----------|------|
| 추론 작업 (코드, 수학, 논리) | 투표(Voting) | +13.2% 향상 |
| 지식 작업 (사실 확인, 요약) | 합의(Consensus) | +2.8% 향상 |

- **핵심 교훈**: 작업 유형에 따라 의사결정 방식을 달리하라. 모든 상황에 합의를 강제하면 오히려 성능이 저하된다.

### LLM Multi-Agent Survey (Springer 2024)

- **주요 위험**: 환각 전파(한 에이전트의 오류가 전체에 퍼짐), 컨텍스트 망각, 자율성 트레이드오프
- **핵심 교훈**: 멀티 에이전트는 은탄환이 아니다. **95% 작업은 단일 에이전트로 충분하다.** 멀티 에이전트는 아래 조건 중 하나 이상을 만족할 때만 투입하라.

---

## 오케스트레이션 패턴

### Sequential (순차)

```
Gemini(리서치) → Claude(설계) → Codex(구현)
```

- **적합한 상황**: 각 단계의 출력이 다음 단계의 입력이 되는 파이프라인 작업
- **예**: 기술 조사 → 아키텍처 설계 → 코드 구현

### Parallel (병렬)

```
MCO: Claude + Codex + Gemini 동시 실행 → 합성
```

- **적합한 상황**: 동일 대상을 독립적으로 검토해야 할 때 (리뷰, 보안 감사, 버그 탐색)
- **도구**: MCO (`--synthesize` 플래그)

### Hierarchical (계층형)

```
Claude (오케스트레이터)
  ├── Codex (서브에이전트: 구현 태스크)
  └── Gemini (서브에이전트: 조사 태스크)
```

- **적합한 상황**: 크로스레이어 조율이 필요한 복잡한 작업 (프론트/백/DB 동시 변경)
- **도구**: Claude Octopus (`/octo:embrace`)

### Debate (토론)

```
Claude + Codex + Gemini → 경쟁 제안 → 75% 합의 게이트 → 결정
```

- **적합한 상황**: 중요한 설계 결정, 아키텍처 선택, 기술 스택 결정
- **도구**: Claude Octopus (`/octo:debate`)

### Iterative (반복)

```
Generator(생성) → Critic(비판) → 루프 → 품질 기준 충족 → 완료
```

- **적합한 상황**: 정확도 요구가 높은 작업 (코드 수정, 리팩토링, 테스트 작성)
- **도구**: Ruflo (Q-Learning 라우터 + 피드백 루프)

---

## 실용 워크플로우

### 대용량 코드베이스 분석 (Gemini 무료 + 1M 토큰)
```bash
npx @google/gemini-cli -p "이 코드베이스 전체를 분석하고 개선점을 제안해줘"
```

### 정밀 구현 (Claude Code 직접 작업)
```
# Claude Code 내에서 직접 멀티파일 작업 수행
# MCP로 테스트 러너 연결 후 즉시 검증
```

### 병렬 보안/품질 리뷰 (MCO)
```bash
mco review --providers claude,codex,gemini --synthesize --format markdown-pr
```

### CI/CD 자동화 (Codex Actions)
```yaml
# .github/workflows/codex.yml
- uses: openai/codex-action@v1
  with:
    task: "실패한 테스트를 수정하고 PR을 생성해줘"
```

### 복잡한 설계 결정 (Claude Octopus 토론)
```
/octo:debate "이 아키텍처 선택지를 평가해줘: 모놀리스 vs 마이크로서비스"
```

### 최신 기술 리서치 (Gemini Google Search 그라운딩)
```bash
npx @google/gemini-cli -p "2025년 최신 React 상태관리 트렌드와 각 라이브러리 비교"
```

---

## 의사결정 트리

```
작업 요청 도착
│
├── 단순하거나 빠른 응답이 필요한가?
│   └── YES → 단일 에이전트 (Claude Code) 사용. 멀티 에이전트 투입 불필요.
│
├── 최신 정보 또는 대용량 컨텍스트가 필요한가?
│   └── YES → Gemini CLI (1M 토큰, Google Search 그라운딩)
│
├── 동일 대상을 독립적으로 다각 검토해야 하는가?
│   └── YES → MCO 병렬 실행 (`--providers claude,codex,gemini --synthesize`)
│
├── 중요한 설계 결정 또는 기술 선택인가?
│   └── YES → Claude Octopus 토론 (`/octo:debate`)
│             → 작업 유형 확인:
│               - 추론/코드 → Voting 방식
│               - 사실/지식 → Consensus 방식
│
├── 파이프라인형 멀티스텝 작업인가? (리서치 → 설계 → 구현)
│   └── YES → Sequential 패턴
│               Gemini(리서치) → Claude(설계) → Codex(구현)
│
├── 크로스레이어 조율이 필요한가? (프론트/백/DB 동시)
│   └── YES → Hierarchical 패턴
│               Claude(오케스트레이터) + Codex/Gemini(서브에이전트)
│               또는 Claude Octopus `/octo:embrace`
│
├── CI/CD 또는 반복 자동화 작업인가?
│   └── YES → Codex CLI (GitHub Actions `openai/codex-action@v1`)
│
└── 정확도 기준을 만족할 때까지 반복이 필요한가?
    └── YES → Iterative 패턴 (Ruflo Q-Learning 라우터)
```

---

## 제약 조건

- **멀티 에이전트는 오버엔지니어링이 기본값이다.** 95% 작업은 단일 에이전트로 충분하다. 복잡도 추가 전 단일 에이전트로 먼저 시도하라.
- **환각 전파를 경계하라.** 한 에이전트의 잘못된 전제가 파이프라인 전체에 전파될 수 있다. 각 단계 출력을 검증한 뒤 다음 단계에 전달하라.
- **Gemini 무료 티어 제한**: 1,000 req/일. 대량 배치 작업 시 속도 조절 필요.
- **Codex Full Access 모드 주의**: 파일 시스템 전체 접근 권한을 부여하는 Full Access는 격리 환경(CI/CD, Docker)에서만 사용하라.
- **워크플로우 복잡도와 유지보수성**: 에이전트 수가 늘수록 디버깅 난이도가 지수적으로 증가한다. 3개 에이전트를 넘기기 전 반드시 단순화 가능 여부를 검토하라.
- **비용 추적**: Claude Code와 Codex CLI는 API 사용량에 따라 비용이 발생한다. Gemini를 리서치 단계에 우선 배치하면 전체 비용을 낮출 수 있다.
- **컨텍스트 망각**: 긴 파이프라인에서 에이전트가 초기 지시를 망각할 수 있다. 각 단계 프롬프트에 핵심 제약 조건을 반복 명시하라.
