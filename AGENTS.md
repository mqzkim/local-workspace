# AGENTS.md - Codex Workspace Execution Guide

## Status
- Codex canonical policy file for this repository.
- Migrated from Claude assets on 2026-03-02.
- Full mapping report: `.codex/MIGRATION_REPORT.md`.

## Language and Output
- Default response language: Korean.
- Keep responses concise and action-oriented.
- If the user requests another language, follow that request.
- Preferred concise style profile: `.codex/skills/output-style-korean-concise/SKILL.md`.

## Skill-First Routing
1. Search `.codex/skills/` for matching skills before implementation.
2. If one or more skills match, load the minimum relevant set and follow them.
3. If no skill matches and the task is reusable/repetitive, create or update a skill first.
4. Legacy Claude assets map as follows:
- Team agents -> `team-agent-*`
- Slash commands -> `command-*`
- Global rules -> `rule-*`
- Output style -> `output-style-korean-concise`

## Plan-First Protocol
Apply this protocol for any non-trivial code, infra, or deployment task.

1. Explore
- Read relevant code and docs first.
- Identify dependencies and blast radius.

2. Plan
- Create or update `plans/YYYY-MM-DD__<slug>.plan.md`.
- Include goal, scope (included/excluded), risks, rollback, validation steps.

3. Align
- Present the plan and wait for explicit approval before high-impact execution.
- Re-align if scope changes.

4. Implement
- Execute against the approved plan.
- Keep changes minimal and focused.

5. Validate
- Run targeted tests/typecheck/lint as relevant.
- Report what was executed and what could not be executed.

6. Retrospect
- Capture reusable lessons and update rules/skills when needed.

## Architecture Standard (MANDATORY)

> **모든 코드 작업 전 반드시 DDD 아키텍처 규칙을 확인한다. 예외 없음.**

- **DDD 규칙 (항상 로드됨)**: `.claude/rules/ddd.md`
- **DDD 전체 가이드**: `docs/DDD_GUIDE.md`
- 신규 기능 / 수정 / 리팩토링 전 해당 도메인의 `DOMAIN.md` 필독
- 레이어 의존성 방향 위반 시 즉시 거부: `presentation → application → domain ← infrastructure`
- 바운디드 컨텍스트 간 직접 import 금지 — 도메인 이벤트만 허용

## Engineering Rules
- Prefer the smallest correct change.
- Prefer editing existing files over creating new files.
- Avoid premature abstractions.
- Validate external inputs at system boundaries.
- Fail fast with descriptive errors.
- Never hardcode secrets/tokens/passwords.

## Git and Safety
- Never run destructive git commands without explicit user approval.
- Stage specific files; avoid blind bulk staging.
- Do not force-push or amend published commits unless explicitly requested.
- Never commit `.env` or credentials.

## Migration Notes
- Claude source assets are preserved in `.claude/` for reference.
- Codex-ready skills are generated in `.codex/skills/`.
- Regenerate migration outputs with:

```powershell
./scripts/migrate-claude-to-codex.ps1
```
