# Changelog

All notable changes to claude-solo are documented here.

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/)
Versioning: [Semantic Versioning](https://semver.org/)

---

## [0.4.3] - 2026-04-29

### Changed

- **lean-ctx hooks are now opt-in** — installer installs the binary but no longer calls `lean-ctx init --agent claude-code` automatically. The init wires PreToolUse hooks that intercept every Read/Grep/Bash call, which was too noisy as a default. To enable: `lean-ctx init --agent claude-code`
- README hooks table corrected: removed lean-ctx PreToolUse rows and MCP row; count updated to 16; added missing `enforce-lsp-navigation.sh` row

---

## [0.4.2] - 2026-04-29

### Added

- **lean-ctx MCP server** — wired into `~/.claude/settings.json` `mcpServers`; provides 48 MCP tools for cached reads, shell compression, and AST navigation
- **`lean-ctx init --agent claude-code`** — now called automatically by `install_optional_tools()` after cargo install; hooks + rules deployed in one step

### Fixed

- **`install_optional_tools()` lean-ctx** — installer now downloads pre-built binary from `yvgude/lean-ctx` GitHub releases (cross-platform: Windows zip, macOS/Linux tgz); `cargo install lean-ctx` retained as fallback (~15 min compile eliminated for most installs)
- **Removed non-existent `lean-ctx-bin` npm attempt**
- **`Setup-WindowsEncoding.ps1:46`** — replaced invalid `$env:($kv.Key)` dynamic property syntax with `[System.Environment]::SetEnvironmentVariable($kv.Key, $kv.Value, 'Process')`

---

## [0.4.1] - 2026-04-29

### Added

- **`install_cache_fix()`** — auto-installs `claude-code-cache-fix` npm package; patches `ANTHROPIC_BASE_URL=http://127.0.0.1:9801` and `ENABLE_PROMPT_CACHING_1H=1` into `settings.json`; skips gracefully if npm/node unavailable
- **`scripts/start-cache-proxy.sh`** — SessionStart hook (runs first, before all others) that starts the cache proxy if not already listening on `:9801`; idempotent curl check prevents double-start
- **`install_optional_tools()`** — auto-installs `lean-ctx` (cargo only; wires via `lean-ctx init --agent claude-code`) and `BurntToast` PowerShell module (Windows only, PSGallery trust, idempotent check)
- **`setup_windows_encoding()`** — auto-runs `Setup-WindowsEncoding.ps1` via `pwsh`/`powershell.exe` on Windows during install
- **`_patch_settings_env(key, value)`** — surgical jq-based env var injection into `settings.json` with idempotency check, conflict warning, and `--dry-run` support
- **`is_windows()` / `find_pwsh()`** — cross-platform helpers for PowerShell detection (covers Git Bash, MSYS2, Cygwin)
- **Smoke test expanded** — now validates 15 wired hooks, verifies cache-fix proxy, `lean-ctx`, and `BurntToast`

### Fixed

- **Hook execution order** — `start-cache-proxy` wired last in `ensure_hooks_wired()` (prepend semantics make it run first); other SessionStart hooks reordered to match documented execution sequence
- **`grep -P` on Git Bash** — replaced Perl-compatible regex patterns with POSIX ERE (`grep -E`) throughout installer; fixes "supports only unibyte and UTF-8 locales" error on Windows

---

## [0.4.0] - 2026-04-29

### Changed

- **Unified flat repo** — removed `Original/`, `Ultimate-Linux/`, `Ultimate-Windows/` variant directories. All content now lives at repo root: `agents/`, `commands/`, `skills/`, `scripts/`, `rules/`
- **Single installer** — `install.sh` no longer presents a variant selection menu. One command (`bash install.sh`) installs everything. Removed `--original`, `--linux`, `--windows` flags
- **`/mm:` prefix on all commands and skills** — every slash command and skill is now invoked as `/mm:name` (e.g. `/mm:brief`, `/mm:cost`, `/mm:hud`). Frontmatter `name:` fields preserved as-is during install
- **Scripts at `~/.claude/scripts/`** — hook scripts moved from `~/.claude/ultimate-windows/scripts/` to `~/.claude/scripts/`. `ensure_hooks_wired()` updated accordingly
- **Manifest at `~/.claude/.claude-solo-manifest`** — unified manifest replaces per-variant manifests
- **Version file at `~/.claude/.claude-solo-version`** — used by `update-check.sh`
- **`install_rules()`** — new function installs `rules/*.md` to `~/.claude/rules/` for auto-loading
- **30 commands, 25 skills** — merged best of Original (11 unique commands), Ultimate-Windows (19 commands, 8 skills), and community skills (17)

### Removed

- `Original/` directory (content merged into root `commands/`)
- `Ultimate-Linux/` directory
- `Ultimate-Windows/` directory
- Interactive variant selection menu from `install.sh`
- `run_original()`, `run_linux()`, `run_windows()` functions
- `--original`, `--linux`, `--windows` CLI flags

---

## [0.3.0] - 2026-04-29

### Added

**Windows Encoding Hardening (Tier 1)**

- `bootstrap-windows-encoding.sh` SessionStart hook — exports `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1` to `$CLAUDE_ENV_FILE` before any tool runs; prevents `charmap` codec errors on Windows
- `validate-utf8-source.sh` PreToolUse hook — detects mojibake sequences (`â€"`, `â€™`, `Â `, `Ã©`, `Ã¨`, etc.) in Edit/Write/MultiEdit content; blocks writes and suggests re-encoding with helpful message; warns on UTF-8 BOM without blocking
- `Setup-WindowsEncoding.ps1` — pure-ASCII PowerShell script for one-shot encoding fix: sets User-scope env vars, patches PowerShell profile with `chcp 65001`, merges into `settings.json` with cascading parse fallback (UTF-8 → cp1252 recovery → ASCII-strip); backs up before touching anything
- `settings.json` env block: added `PYTHONIOENCODING=utf-8`, `PYTHONUTF8=1`, `CLAUDE_CODE_USE_POWERSHELL_TOOL=1`

**Cost & Quota Observability (Tier 2)**

- `cost-summary.sh` SessionStart hook — parses today's JSONL files, sums token buckets (cache reads/writes/direct/output), computes hit ratio, estimates cost at Sonnet 4.6 rates; emits `[cost] today: 142k reads, 38k 5m-writes (78% hit) ~$1.84`; throttled at 5min; warns when hit ratio < 60%
- `quota-warmup-warn.sh` SessionStart hook — reads 5h usage window from JSONL, emits `[quota] 5h window started HH:MM (Xm ago), Xk tokens used`; visibility only, no quota manipulation
- `COST-OPTIMIZATION.md` — documents cache TTL regression (CC v2.1.81+), cache-fix-wrapper, lean-ctx integration, session hygiene tips, and cost rate table
- `/mm:cost` command — rich cost report with today/week/month tabs, per-project and per-model breakdown, top 5 most expensive sessions, optimization suggestions
- `check_prereqs_ultimate()`: warns when `cache-fix-wrapper` is missing and CC version >= 2.1.81 (advisory only)
- `check_prereqs_ultimate()`: detects `lean-ctx` and logs its availability; warns with install suggestion if missing

**LSP Enforcement & Navigation (Tier 3)**

- `enforce-lsp-navigation.sh` PreToolUse hook — detects code-symbol patterns in Grep/Glob queries; nudges agent to prefer `mcp__serena__find_symbol` when LSP server is registered; advisory (exit 0), never blocks
- `/lsp-status` skill — diagnoses LSP MCP server registration, runs sample queries, reports what's working and what isn't

**Plan-First / HUD Observability (Tier 4)**

- `session-hud.sh` SessionStart hook — emits compact "you are here" panel: branch + dirty count, active sprint, last checkpoint timestamp, top 3 modified files in last 24h, pending TODO count; throttled at 10min
- `CLAUDE.md`: added "Plan before code" section for tasks touching >2 files
- `/hud` skill — full HUD with token usage ASCII bar chart, recent tool call distribution, active hooks list, sprint context, open TODOs

**Skill Library (Tier 5)**

- `rules/karpathy-pitfalls.md` — engineering pitfalls from Karpathy: don't hallucinate libraries, prefer existing codebase patterns, don't invent test cases, be explicit about uncertainty, small targeted edits
- `/mm:skill-from-template` command — scaffolds a new skill under `~/.claude/skills/<name>/SKILL.md` with proper frontmatter, trigger keywords, and validation (name format, no nested subdirs)
- `RECOMMENDED-SKILLS.md` — curated external skills with install commands, integration notes, and "evaluated but rejected" table with rationale

**Morae / eDiscovery Domain Skills (Tier 6)**

- `morae-context.sh` SessionStart hook — injects environment reminders (Zurich/US, Custom Pages DLL version, RabbitMQ pin) when CWD matches Morae/Relativity/Nuix/Prudential patterns; silent no-op otherwise
- `morae-powerbi-validate.sh` PostToolUse hook — validates PBIP/PBIR/TMDL/JSON files; checks JSON validity and Morae brand palette (`#FF6900` orange, `#EDE5DE` off-white); gated on `MORAE_POWERBI_VALIDATION=1`
- `/nuix-binary-store` skill — encapsulates three-phase Prudential binary store audit: Phase 1 case scan, Phase 2 MD5 extraction (9.2 vs 9.10 routing), Phase 3 orphan detection
- `/relativity-sql` skill — verified SQL bundle (domain dedup, processing exceptions, saved-search sizes, multi-object field population) with `Invoke-RelativityQuery` PowerShell wrapper and CSV/Parquet output formatters

**Polish & DX (Tier 7)**

- `update-check.sh` SessionStart hook — once per 24h checks for new commits at `mikkeymoo/claude-solo` HEAD; prints one-line update notice with short SHAs; network-failure-tolerant, never blocks startup
- `notify-desktop.sh`: added `pwsh`/`pwsh.exe` detection (PowerShell 7+) before falling back to `powershell.exe`; upgraded Windows Forms fallback to `MessageBox.Show` (proper modal dialog)
- `smoke_test_ultimate()` enhanced: mojibake detection in settings.json, verify all 13 critical hook entries wired, run each hook script with `--smoke-test` flag for self-validation, cleaner pass/fail summary
- `run_windows()`: copies `COST-OPTIMIZATION.md` to `~/.claude/` for reference by hooks; writes installed SHA to `~/.claude/.ultimate-windows-version` for update-check

**Settings**

- `settings.json` hooks now cover 13 events (was 5): 7 SessionStart hooks, 3 PreToolUse hooks, 3 PostToolUse hooks, Notification, PreCompact

### Fixed

- `ensure_hooks_wired()`: corrected compress-lsp-output matcher from `mcp__cclsp__.*` to `mcp__serena__.*` to match actual installed MCP server name

### Documentation

- `COST-OPTIMIZATION.md` — new file, cost/cache reference guide
- `RECOMMENDED-SKILLS.md` — new file, curated external tool evaluation
- `rules/karpathy-pitfalls.md` — new rules file
- `README.md` — new top-level README with variant overview, quickstart, feature highlights
- `CLAUDE.md` — added "Plan before code" section

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

[0.3.0]: https://github.com/mikkeymoo/claude-solo/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/mikkeymoo/claude-solo/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/mikkeymoo/claude-solo/releases/tag/v0.1.0
