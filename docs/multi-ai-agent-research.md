# Multi-AI-Agent 리서치: Gemini CLI + Claude Code + OpenAI Codex CLI

> 작성일: 2026-03-03
> 목적: 세 AI CLI 도구를 활용한 멀티 에이전트 시스템 구축 방법 조사

---

## 1. 각 CLI 도구 특성 비교

| 항목 | Claude Code | Gemini CLI | Codex CLI |
|------|------------|-----------|-----------|
| 핵심 모델 | Claude Opus/Sonnet 4.6 | Gemini 2.5 Pro/Flash | GPT-5-Codex |
| 컨텍스트 창 | 200K (베타 1M) | **1M 토큰** | 192K |
| 무료 사용 | X | **O (1K req/일)** | X |
| 코드 정확도 | **~95%** | 85-88% | 88-92% |
| 멀티모달 | 제한적 | O (이미지/PDF/영상) | O (이미지) |
| 보안 샌드박스 | 기본 | 기본 | **3단계 고급** |
| 멀티 에이전트 | O (실험적) | 제한 | 제한 |
| 오픈소스 | X | **O (Apache 2.0)** | **O (Apache 2.0)** |
| GitHub Stars | - | 활발 | **62.7k** |
| 언어 | TypeScript | TypeScript | Rust + TS |

### 1.1 Claude Code - 강점
- 코드 정확도 1위, 멀티파일 자율 리팩토링
- MCP(Model Context Protocol)로 외부 시스템 연결
- **Agent Teams** (실험): 다중 인스턴스 병렬 실행
  ```json
  { "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": true }
  ```

### 1.2 Gemini CLI - 강점
- 1M 토큰으로 대형 코드베이스 전체 처리
- 무료 (개인 Google 계정, 설치 없이 `npx @google/gemini-cli`)
- Google Search 그라운딩 내장 (실시간 최신 정보)
- PTY 지원으로 `vim`, `git rebase` 같은 인터랙티브 명령 실행
  ```bash
  gemini -p "분석해줘" --output-format stream-json
  ```

### 1.3 Codex CLI - 강점
- Rust 기반 고성능, 3단계 샌드박스 보안
- CI/CD 네이티브 통합 (`openai/codex-action@v1`)
- GitHub PR/Issue `@codex` 멘션으로 자동 작업
  ```yaml
  # .github/workflows/codex.yml
  - uses: openai/codex-action@v1
    with:
      prompt: "Fix failing tests"
  ```

---

## 2. Multi-AI-Agent 관련 핵심 연구 (2024-2025)

### 2.1 AFlow: Automating Agentic Workflow Generation
- **출처**: ICLR 2025 Oral (상위 1.8%)
- **저장소**: https://github.com/FoundationAgents/AFlow
- **핵심**: 워크플로우를 코드로 표현된 검색 문제로 재정식화
  - Monte Carlo Tree Search로 워크플로우 공간 탐색
  - 6개 벤치마크 평균 5.7% SOTA 대비 향상
  - GPT-4o 비용 4.55%로 소형 모델이 GPT-4o 능가

### 2.2 Voting or Consensus? Decision-Making in Multi-Agent Debate
- **출처**: ACL 2025 Findings
- **핵심 발견**:
  - 투표(Voting): 추론 작업에서 13.2% 향상
  - 합의(Consensus): 지식 작업에서 2.8% 향상
  - 멀티 에이전트 이득 대부분이 단순 다수결에서 기인

### 2.3 LLM-based Multi-Agent Systems Survey
- **출처**: Springer Nature (2024)
- **5대 구성요소**: 프로파일, 인식, 자기 행동, 상호 상호작용, 진화
- **도전 과제**:
  - 환각(Hallucination) 전파 위험
  - 긴 컨텍스트에서 정보 망각
  - 결정론적 행동 vs 자율성 트레이드오프

### 2.4 참고 자료
- IJCAI 2024 LLM Multi-Agents Survey: https://github.com/taichengguo/LLM_MultiAgents_Survey_Papers
- 에이전트 논문 일일 업데이트: https://github.com/tmgthb/Autonomous-Agents
- Awesome Agent Papers: https://github.com/luo-junyu/Awesome-Agent-Papers

---

## 3. 실제 구현 도구: 세 CLI 통합 프레임워크

### 3.1 MCO (Multi-CLI Orchestrator) ★★★ 추천
> "AI 코딩 에이전트를 위한 중립적 오케스트레이션 레이어"

- **저장소**: https://github.com/mco-org/mco
- **패키지**: `npm i -g @tt-a1i/mco`
- **지원**: Claude, Codex, Gemini, OpenCode, Qwen Code 동시 병렬 실행

**핵심 아키텍처**:
- `wait-all` 시맨틱으로 모든 에이전트 동시 실행
- 총 실행시간 = 가장 느린 에이전트 시간
- 교차 에이전트 중복 제거 + `detected_by` 필드 추적

```bash
# 병렬 보안 리뷰
mco review \
  --repo . \
  --prompt "Review for security issues" \
  --providers claude,codex,gemini

# 합성 결과 출력
mco review --providers claude,codex,gemini --synthesize

# 출력 형식
--format report        # 터미널 (기본)
--format markdown-pr   # GitHub PR 댓글
--format sarif         # 코드 스캔 업로드
--json                 # 자동화 처리
```

---

### 3.2 Claude Octopus ★★★
> Double Diamond 구조 + 75% 합의 게이트

- **저장소**: https://github.com/nyldn/claude-octopus
- **구조**: Claude Code 플러그인

**AI 역할 분담**:
```
Codex   → 구현 깊이: 코드 패턴, 기술 분석, 아키텍처
Gemini  → 생태계 폭: 대안 검토, 보안 검증, 리서치
Claude  → 오케스트레이터: 품질 게이트, 합의, 최종 종합
```

**Double Diamond 4단계**:
1. **Discover**: 광범위 탐색 + 다중 AI 리서치
2. **Define**: 요구사항 명확화 + 합의 형성
3. **Develop**: 품질 게이트 적용 구현
4. **Deliver**: 대립적 검토 + 최종 평가

**핵심 명령어**:
```
/octo:embrace    # 전체 4단계 워크플로우 자동 실행
/octo:factory    # 명세→소프트웨어 자동 파이프라인
/octo:debate     # 3자 합의 기반 토론
/octo:review     # 다각 관점 코드 검토
/octo:security   # OWASP 기반 취약점 스캔
/octo:tdd        # TDD 기반 개발
/octo:research   # 다중 소스 합성 리서치
```

---

### 3.3 Claude Code Bridge (CCB) ★★
> 분할 창 터미널 기반 다중 AI 협업

- **저장소**: https://github.com/bfly123/claude_code_bridge
- **특징**: TmuxBackend/WeztermBackend 자동 감지, 경량 토큰 오버헤드

```bash
/ask gemini "이 함수 최적화해줘"   # 비동기 요청
/ask codex "테스트 작성해줘"
/pend gemini                        # 응답 조회
/continue                           # 컨텍스트 계속성 유지
```

---

### 3.4 Parallel Code ★★
> 각 AI CLI에 독립 git worktree 부여

- **저장소**: https://github.com/johannesjo/parallel-code
- **특징**: 에이전트 간 코드 덮어쓰기 충돌 방지, 각자 독립 브랜치

---

### 3.5 Ruflo ★★★ (고급)
> Claude Code용 Swarm Intelligence 플랫폼

- **저장소**: https://github.com/ruvnet/ruflo
- **아키텍처**: Q-Learning Router → Swarm → 60+ Agents → LLM Providers
- **합의**: Raft 리더십 선출 + Byzantine 내결함성 투표 (f < n/3)
- **Agent Booster** (WASM): 단순 변환 <1ms, LLM 대비 352배 빠름, 토큰 30-50% 절감

---

### 3.6 myclaude (오케스트레이터/실행자 분리 패턴)
- **저장소**: https://github.com/cexll/myclaude
- **패턴**: Claude Code(오케스트레이터) + codeagent-wrapper(실행자)
- CLI 플래그 추상화:
  ```
  Codex:  codex e --json -C resume
  Claude: --output-format stream-json -r
  Gemini: -o stream-json -y -r
  ```

---

## 4. 오케스트레이션 아키텍처 패턴

### 4.1 Sequential (순차)
```
Input → Gemini(리서치) → Claude(설계) → Codex(구현) → Result
```
- **사용**: 명확한 선형 의존성의 다단계 처리

### 4.2 Parallel (병렬 앙상블)
```
           ┌→ Codex  (구현 분석)  ─┐
Input ─────┤→ Gemini (보안 리서치) ─┼→ 합성 → Result
           └→ Claude (설계 리뷰)  ─┘
```
- **사용**: 독립적 관점이 필요한 동일 작업 (리뷰, 브레인스토밍)
- **도구**: MCO `--providers claude,codex,gemini`

### 4.3 Hierarchical (계층적)
```
Orchestrator (Claude - 계획/검증)
    ├── Codex  (구현)
    ├── Gemini (리서치/대용량 분석)
    └── Specialist (도메인 전문)
```
- **사용**: 크로스 도메인 복잡 작업
- **도구**: Claude Octopus `/octo:embrace`

### 4.4 Debate (그룹 토론)
```
Chat Manager ─ 공유 스레드
    ├── Agent A (관점 A)
    ├── Agent B (관점 B)  ←→ 누적 컨텍스트
    └── Agent C (관점 C)
```
- **도구**: Claude Octopus `/octo:debate`

### 4.5 Loop/Iterative (반복 개선)
```
Generator → Critic → (미달?) → Generator (루프)
                         ↓ (합격)
                       Result
```
- **도구**: Google ADK `LoopAgent`, `max_iterations` 설정

---

## 5. Skill 기반 통합 설계 (현재 워크스페이스 적용)

현재 `.claude/skills/` + Hub 구조에 통합 가능한 패턴:

### 5.1 Provider Abstraction Skill
```markdown
# multi-ai-provider.md
## 라우팅 기준
- 코드 정밀 작업 → Claude Code
- 대용량 컨텍스트/리서치 → Gemini CLI (무료, 1M 토큰)
- CI/CD/보안 샌드박스 → Codex CLI
```

### 5.2 Role-Based Routing (권장)
```
리서치/대용량 분석    → Gemini  (1M 토큰 + Google Search, 무료)
구현 정밀도 중요      → Claude  (~95% 정확도)
반복 자동화/CI        → Codex   (Rust 고성능 + 샌드박스)
멀티관점 리뷰         → MCO     (세 CLI 병렬 + 합성)
```

### 5.3 실용 워크플로우 예시
```bash
# 1. 리서치는 Gemini (무료 + 큰 컨텍스트)
gemini -p "이 라이브러리 전체 분석해줘"

# 2. 코드 구현은 Claude
claude "위 분석을 바탕으로 모듈 구현해줘"

# 3. 보안/품질 리뷰는 MCO 병렬
mco review --providers claude,codex,gemini --synthesize

# 4. CI/CD는 Codex Actions
# .github/workflows/codex.yml
```

---

## 6. Best Practices

### 비용 최적화
- **Gemini 우선**: 리서치, 대용량 분석 → 무료 (1K req/일)
- **모델 분리**: Orchestrator는 Opus, Sub-agent는 Sonnet/Flash
- **Codex 번들**: 반복 CI 작업 → ChatGPT 구독 내 포함

### 보안
- Codex 샌드박스 단계적 적용: `Read-only → Auto → Full Access`
- 병렬 실행 시 각 에이전트에 독립 git worktree 부여 (parallel-code 패턴)
- MCP 인증 네임스페이스별 권한 분리

### 언제 멀티 에이전트가 필요한가
> "95%의 작업은 단일 에이전트로 충분" — Shipyard.build 가이드

멀티 에이전트가 실질적 가치를 제공하는 경우:
- 독립적 병렬 탐색 (리서치, 코드 리뷰)
- 경쟁 가설 기반 디버깅
- 크로스 레이어 조율 (프론트/백/DB)
- 30분 이상 소요되는 장기 작업

---

## 7. 참고 저장소 목록

| 저장소 | 설명 | 추천도 |
|--------|------|-------|
| [mco-org/mco](https://github.com/mco-org/mco) | 중립 오케스트레이션 레이어 | ★★★ |
| [nyldn/claude-octopus](https://github.com/nyldn/claude-octopus) | Double Diamond + 합의 | ★★★ |
| [ruvnet/ruflo](https://github.com/ruvnet/ruflo) | Swarm Intelligence | ★★★ |
| [bfly123/claude_code_bridge](https://github.com/bfly123/claude_code_bridge) | 터미널 분할 협업 | ★★ |
| [johannesjo/parallel-code](https://github.com/johannesjo/parallel-code) | Git worktree 병렬 | ★★ |
| [catlog22/Claude-Code-Workflow](https://github.com/catlog22/Claude-Code-Workflow) | JSON 팀 프레임워크 | ★★ |
| [cexll/myclaude](https://github.com/cexll/myclaude) | 오케스트레이터 분리 | ★★ |
| [openai/codex](https://github.com/openai/codex) | Codex CLI 공식 (62.7k★) | 참조 |
| [google-gemini/gemini-cli](https://github.com/google-gemini/gemini-cli) | Gemini CLI 공식 | 참조 |
| [FoundationAgents/AFlow](https://github.com/FoundationAgents/AFlow) | ICLR 2025 워크플로우 자동화 | 연구 |
| [FoundationAgents/MetaGPT](https://github.com/FoundationAgents/MetaGPT) | 소프트웨어 팀 에뮬레이션 (44k★) | 연구 |

---

*Sources: CodeAnt.ai, Shipyard.build, InventiveHQ, ACL 2025, ICLR 2025, Microsoft Azure AI Docs, Google ADK Docs*
