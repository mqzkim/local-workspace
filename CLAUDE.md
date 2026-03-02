# CLAUDE.md (Legacy Compatibility)

This workspace has been migrated to Codex-native operation.

## Canonical Files
- Execution policy: `AGENTS.md`
- Migrated skills/agents/commands/rules: `.codex/skills/`
- Migration mapping report: `.codex/MIGRATION_REPORT.md`
- Pre-migration CLAUDE backup: `.codex/legacy/CLAUDE.pre-codex-migration.md`

## Regeneration Command
If `.claude/` assets change, regenerate Codex assets with:

```powershell
./scripts/migrate-claude-to-codex.ps1
```

## Legacy Note
This file remains as a compatibility pointer for Claude-oriented workflows.
For active behavior in this repository, treat `AGENTS.md` as the source of truth.
