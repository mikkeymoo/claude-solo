# Changelog

All notable changes to claude-solo are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/)

---

## [0.2.0] - 2026-04-08

### Added

**New Hooks (6)**
- `PostCompact` — auto-restores `.planning/CHECKPOINT.md` into context after compaction; no more manual `/mm:resume` after context compression
- `WorktreeCreate` — copies `.env` and other gitignored files into new agent worktrees via `.claude/worktree-copy-list`; agents can run the app immediately
- `PostToolUseFailure` — injects structured triage hints when tools fail: exit code classification (127, 126, 128), ENOENT, EACCES, port-in-use, timeout, Node/Python module-not-found, syntax errors, Edit old_string mismatches
- `FileChanged` — warns when `package.json`, `pyproject.toml`, `requirements.txt`, `Cargo.toml`, `go.mod`, or `.env.example` change mid-session; prevents stale dependency advice
- `ConfigChange` — detects if claude-solo hooks are removed from `settings.json` and warns; advisory only, never blocks
- `InstructionsLoaded` — logs which `CLAUDE.md` and `.claude/rules/*.md` files are active; makes multi-project rule debugging visible

**New Skills (3)**
- `/mm:github-setup` — interactive setup for Claude Code GitHub App (PR `@claude` mentions, issue-to-PR) or GitHub Actions CI workflow generation using `anthropics/claude-code-action@v1`
- `/mm:schedule` — CRUD interface for Claude Code's built-in cron scheduling; pre-built templates for daily health check, weekly PR review, nightly test run, weekly dependency audit
- `/mm:rules` — create and manage `.claude/rules/*.md` path-specific instruction files with glob matching; show which rules apply to a given file path

**Extended Warning Patterns in `PreToolUse` (14 new)**
- `pkill -9` / `kill -9` / `killall -9` — SIGKILL without cleanup
- `chmod -R 777` / `chmod 777 /` — world-writable permissions
- `curl ... | bash` / `wget ... | sh` / `curl ... | node` — remote code execution pipe
- `dd if=` — direct disk write
- `npm publish` / `cargo publish` — registry publish without `--dry-run`
- `git push --force` / `git push -f` — force push to any branch
- `git clean -f` — untracked file removal
- `drop database` — full database drop
- Excludes `--dry-run` variants from force-push and publish warnings

**Settings**
- `settings.json` now registers 14 hook events (was 8)

### Fixed

- `post-tool-use-failure`: `String()` coerce on error object prevents `TypeError` when error is non-string; `Number()` coerce on exit code handles string `'127'`; `tool_name` defaults to `'unknown'`
- `worktree-create`: path traversal guard — entries with `..` or absolute paths in `worktree-copy-list` are rejected with a warning; rename `clauDeDir` → `claudeDir`
- `settings.json`: `FileChanged` matcher corrected to `.env.example` (was `\.env\.example`, which matched no files)
- `instructions-loaded`: home directory shortening uses `startsWith`+slice to handle Windows mixed separators; categorization simplified to 3 non-overlapping buckets (Global/Rules/Project)
- `config-change`: uses `path.basename()` instead of `endsWith()` for settings file detection
- `pre-tool-use`: `git clean` regex simplified to negative-lookahead pattern; `DELETE without WHERE` regex updated to match SQL embedded in `psql -c "..."` commands; redundant `/i` flags removed from already-lowercased patterns
- `file-changed`: removed dead `pnpm-lock.yaml` and `package-lock.json` entries that were unreachable via the matcher

### Tests

- 92 unit/integration tests (up from 0 formal tests)
- Full coverage of all 6 new hooks, extended pre-tool-use patterns, and render pipeline output
- Cross-platform path handling verified (Windows backslash paths)

---

## [0.1.0] - 2026-03-xx (initial)

### Added

- 7-stage sprint pipeline: `/mm:brief` → `/mm:plan` → `/mm:build` → `/mm:review` → `/mm:test` → `/mm:verify` → `/mm:ship` → `/mm:retro`
- 8 lifecycle hooks: `SessionStart`, `PreToolUse`, `PostToolUse`, `UserPromptSubmit`, `PermissionRequest`, `PreCompact`, `SubagentStop`, `Stop`
- 24 specialized agents including swarm agents (`swarm-lead`, `swarm-implementer`, `swarm-researcher`, `swarm-reviewer`, `swarm-tester`)
- 40 skills covering sprint pipeline, research, session management, release, incident, enterprise review, and CI/CD
- Agent swarm mode with isolated git worktrees, shared task queues, and quality-gate hooks
- Autonomous/Ralph mode (`run-auto.sh`) for hands-off task execution
- RTK token optimization integration (60–90% token savings on common commands)
- Source-agnostic render pipeline — single canonical source generates Claude Code and Codex artifacts
- Cross-platform install scripts (`setup.sh` / `setup.ps1`)
- Brownfield-safe installer: never overwrites user customizations outside claude-solo markers
- Custom statusline with One Dark Pro theme
- MCP server template bundle

---

[0.2.0]: https://github.com/mikkeymoo/claude-solo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mikkeymoo/claude-solo/releases/tag/v0.1.0
