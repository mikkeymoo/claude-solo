# claude-solo Master Plan

> Unified analysis from two independent research passes (2026-04-09)
> Sources: Claude Code official docs, 90+ community repos, full project audit, correctness audit

---

## Table of Contents

1. [Verdict](#verdict)
2. [P0: Things That Are Broken Right Now](#p0-things-that-are-broken-right-now)
3. [Strategic Gaps](#strategic-gaps)
4. [What to Add](#what-to-add)
5. [What to Remove or Simplify](#what-to-remove-or-simplify)
6. [Community Landscape](#community-landscape)
7. [Unified Roadmap](#unified-roadmap)
8. [Reference: Claude Code Complete Feature Matrix](#reference-claude-code-complete-feature-matrix)

---

## Verdict

claude-solo is in the top tier of Claude Code setup repos. 29 agents, 43 skills, 23 hooks, 7-stage sprint pipeline, swarm support, Codex compatibility -- more comprehensive than 95% of what exists. The comparable projects are superpowers (143K stars) and gstack (68K stars).

**But the repo has correctness problems that undermine credibility before anything else matters.**

Four shipped hooks are broken (CommonJS in ESM context). The README claims 18 wired hooks but settings.json only wires 14. The statusline doesn't actually install correctly. The default permission posture auto-approves everything. These must be fixed before adding anything new.

After correctness, the biggest gaps are:

1. **Agent frontmatter** -- only 2 of 15+ fields used (no model, tools, memory, maxTurns, effort)
2. **Skills use legacy format** -- should be SKILL.md directories with full frontmatter
3. **No plugin packaging** -- the #1 missing product surface
4. **No permission rules** in settings.json
5. **8 hook events unused** out of 26 available
6. **No pre-built rules** in `.claude/rules/`
7. **Hook architecture is command-only** -- no prompt/agent/http hook examples
8. **MCP docs are just a server list** -- missing resources, prompts, policies, scoping

---

## P0: Things That Are Broken Right Now

These are bugs, not feature requests. Fix before anything else.

### 1. Four hook files crash on execution

The installer copies `src/hooks/package.json` containing `{ "type": "module" }`, but four hooks use CommonJS (`require()`):

| File | Problem |
|------|---------|
| `src/hooks/build-checker.js` | `require()` in ESM context |
| `src/hooks/context-recovery.js` | `require()` in ESM context |
| `src/hooks/error-handling-reminder.js` | `require()` in ESM context |
| `src/hooks/stop-event.js` | `require()` in ESM context |

Running any of them produces: `ReferenceError: require is not defined in ES module scope`

**Fix**: Convert to ESM (`import`/`export`) or rename to `.cjs`. Add a CI smoke test that executes every hook once under installed packaging.

### 2. README claims 18 wired hooks but settings.json only wires 14

`README.md` advertises 18 core hooks. `src/settings/settings.json` actually registers these events:

| # | Event in settings.json | Hook Script |
|---|----------------------|-------------|
| 1 | SessionStart | session-start.js |
| 2 | PreToolUse | pre-tool-use.js |
| 3 | PostToolUse | post-tool-use.js |
| 4 | UserPromptSubmit | prompt-submit.js |
| 5 | PermissionRequest | permission-request.js |
| 6 | PreCompact | pre-compact.js |
| 7 | SubagentStop | subagent-stop.js |
| 8 | Stop | session-end.js |
| 9 | PostCompact | post-compact.js |
| 10 | WorktreeCreate | worktree-create.js |
| 11 | PostToolUseFailure | post-tool-use-failure.js |
| 12 | FileChanged | file-changed.js |
| 13 | ConfigChange | config-change.js |
| 14 | InstructionsLoaded | instructions-loaded.js |

**Not wired** (files exist but settings.json doesn't reference them):
- `build-checker.js`
- `context-recovery.js`
- `error-handling-reminder.js`
- `stop-event.js`

**Fix**: Either wire them into settings.json or remove the claims from README. Do not ship "installed hook" claims that are aspirational.

### 3. Status line doesn't actually install

`src/settings/statusline.json` has a valid `statusLine` object and `statusline.sh` exists, but:
- The installer copies `statusline.json` as a standalone file
- The installer does NOT merge `statusLine` into `settings.json`
- The installer does NOT copy `statusline.sh`

**Fix**: Merge `statusLine` config into `settings.json` during install, and copy `statusline.sh` to `~/.claude/hooks/`.

### 4. Default permission posture auto-approves everything

`src/hooks/permission-request.js` defaults to `const ALLOW_ALL = true;`, which auto-approves almost everything. For a public repo that others will install, this is too permissive as the default.

**Fix**: Default to conservative mode (read-only auto-approve). Provide documented opt-in for permissive mode. Also add a `permissions` block to `settings.json` with deny rules for destructive commands.

---

## Strategic Gaps

### Gap 1: Agent Frontmatter (Highest Impact)

All 24 agents use only `name` and `description`. Claude Code supports 15+ fields. This is the single highest-impact improvement available.

**What to add to every agent:**

| Field | What It Does | How to Apply |
|-------|-------------|-------------|
| `model` | Override model per agent | Opus for judgment-heavy agents (senior-reviewer, security-auditor, root-cause-analyst, system-architect, performance-optimizer). Sonnet for execution agents (planner, debugger, test-writer, ci-engineer). Haiku for quick lookups. |
| `tools` / `disallowedTools` | Restrict tool access | Read-only agents (root-cause-analyst, requirements-analyst): block Edit, Write. Review agents: block Write. Implementation agents: full access. |
| `memory` | Agent-scoped persistent memory | `project` scope for most agents. Agents learn from past invocations. Stored at `.claude/agent-memory/<name>/`. |
| `maxTurns` | Prevent runaway agents | 50 for complex agents, 30 for focused ones, 100 for swarm-lead. |
| `effort` | Effort level | `high` for security-auditor, senior-reviewer, root-cause-analyst. `medium` for most others. |

**Example upgraded agent:**

```yaml
---
name: senior-reviewer
description: Staff-engineer code reviewer...
model: opus
tools: [Read, Grep, Glob, Bash, Edit, Agent]
disallowedTools: [Write, NotebookEdit]
memory: project
maxTurns: 50
effort: high
---
```

**Swarm agents also need upgrades:**

```yaml
# swarm-lead: model opus, effort high, maxTurns 100, memory project
# swarm-researcher: disallowedTools [Edit, Write, NotebookEdit], memory project
# swarm-implementer: isolation worktree, maxTurns 50
# swarm-reviewer: model opus, effort high, disallowedTools [Write]
# swarm-tester: maxTurns 40
```

---

### Gap 2: Skills Use Legacy Format

claude-solo installs to `.claude/commands/mm/<name>.md` (legacy flat files). Claude Code's current primary abstraction is skills with `SKILL.md` directories:

| Feature | Legacy Commands (current) | Skills (target) |
|---------|--------------------------|-----------------|
| File format | Single `.md` file | Directory with `SKILL.md` + supporting files |
| Install path | `.claude/commands/` | `.claude/skills/` |
| Supporting files | No | Yes (templates, scripts, examples) |
| Auto-activation by file path | No | Yes (`paths` frontmatter) |
| Fork to subagent | No | Yes (`context: fork`) |
| Subagent type selection | No | Yes (`agent: debugger`) |
| Tool restrictions | No | Yes (`allowed-tools`) |
| Shell selection | No | Yes (`shell: bash\|powershell`) |
| Dynamic context injection | No | Yes (`!command` syntax) |

**New frontmatter to use after migration:**

```yaml
---
name: mm:review
description: "Staff-engineer code review..."
argument-hint: "[file-or-commit]"
allowed-tools: [Read, Grep, Glob, Bash, Edit, Agent]
context: fork                    # Isolate in subagent
agent: senior-reviewer           # Use the review agent
paths: ["**/*.ts", "**/*.py"]    # Auto-suggest on code files
shell: bash
---
```

**Skills that should fork to subagent** (long-running, self-contained):
- `/mm:review` -> `senior-reviewer` agent
- `/mm:security` -> `security-auditor` agent
- `/mm:adversarial` -> `security-auditor` agent
- `/mm:test` -> `test-writer` agent
- `/mm:explain` -> `general-purpose` agent
- `/mm:deepsearch` -> `general-purpose` agent
- `/mm:compliance` -> `security-auditor` agent

**Skills that should use dynamic context injection:**

```markdown
# In /mm:doctor SKILL.md:
Current state:
!`git status --short`
!`git log --oneline -5`
!`cat package.json 2>/dev/null || echo "No package.json"`
Now analyze project health...
```

**Skills that should auto-activate via `paths`:**
- `/mm:migrate` -> `paths: ["**/migrations/**"]`
- `/mm:test` -> `paths: ["**/*.test.*", "**/*.spec.*"]`
- `/mm:ci` -> `paths: [".github/workflows/**"]`

**Migration strategy**: Dual-emit during transition (both commands and skills), then drop commands once confirmed working.

---

### Gap 3: No Plugin Packaging

This is the biggest missing product surface. Claude Code now has a full plugin system. claude-solo should be packageable as a plugin for:
- One-command install: `claude plugin add claude-solo`
- Automatic updates via marketplace
- Namespaced skills (no conflicts with user skills)
- Submission to official marketplace at `claude.ai/settings/plugins/submit`
- Submission to `anthropics/claude-plugins-official` (16K stars)

**Target plugin structure:**

```
claude-solo-plugin/
  .claude-plugin/
    plugin.json               # Manifest
  skills/
    mm-build/SKILL.md
    mm-review/SKILL.md
    ...43 skills
  agents/
    senior-reviewer.md
    debugger.md
    ...24+ agents
  hooks/
    hooks.json                # Hook registrations
  settings.json               # Default settings
```

**Keep standalone installer for now** (it's what users know), but design the directory structure to be plugin-compatible so migration is smooth.

---

### Gap 4: No Permission Rules in Settings

`settings.json` has no `permissions` block. This should ship with safe defaults:

```json
{
  "permissions": {
    "allow": [
      "Read", "Glob", "Grep",
      "Bash(git status *)", "Bash(git log *)", "Bash(git diff *)",
      "Bash(git branch *)", "Bash(rtk *)", "Bash(ls *)",
      "Bash(node --version)", "Bash(npm --version)",
      "Bash(cat package.json)"
    ],
    "deny": [
      "Bash(rm -rf /)", "Bash(git push --force *)",
      "Bash(npm publish *)", "Bash(curl * | bash)",
      "Bash(chmod -R 777 *)", "Bash(dd if=*)"
    ]
  }
}
```

This replaces the advisory-only approach in `pre-tool-use.js` with actual enforcement for the most dangerous patterns.

---

### Gap 5: 8 Hook Events Unused

Claude Code has 26 hook events. claude-solo covers 18 (but only wires 14 -- see P0 #2). Add the highest-value missing ones:

| Event | Priority | What to Build |
|-------|----------|--------------|
| `PermissionDenied` | **HIGH** | Log denied ops, suggest alternatives, detect friction patterns |
| `CwdChanged` | **MEDIUM** | Re-inject project context on directory change, detect monorepo navigation |
| `SessionEnd` | **MEDIUM** | Currently only using `Stop`; `SessionEnd` also fires on `clear`, `resume`, `logout` |
| `Notification` (idle) | **MEDIUM** | Auto-save checkpoint when Claude goes idle; prevent context loss |
| `WorktreeRemove` | LOW | Cleanup tracking |
| `StopFailure` | LOW | Diagnostic logging |
| `Elicitation` / `ElicitationResult` | LOW | Only matters for interactive MCP servers |

---

### Gap 6: No Pre-Built Rules

`.claude/rules/` is empty. Ship 8 starter rules for common file patterns:

| Rule File | Path Pattern | Key Rules |
|-----------|-------------|-----------|
| `migrations.md` | `**/migrations/**` | Never auto-run. Check data loss. Verify rollback. Check table locks. |
| `tests.md` | `**/*.test.*`, `**/*.spec.*` | Deterministic. No network without mocks. Assert specific values. |
| `ci-workflows.md` | `.github/workflows/**` | Pin action versions to SHA. Never expose secrets in logs. |
| `env-files.md` | `.env*`, `**/secrets.*` | Never commit real secrets. Document all required vars. |
| `api-routes.md` | `**/routes/**`, `**/api/**` | Validate input. Consistent error shapes. Rate limit public endpoints. |
| `security-sensitive.md` | `**/auth/**`, `**/middleware/**` | Never log credentials. Constant-time comparison. Hash with bcrypt/argon2. |
| `config-files.md` | `**/*.config.*`, `**/tsconfig.*` | Explain non-obvious options. Validate syntax before saving. |
| `documentation.md` | `**/*.md`, `**/docs/**` | Keep concise. Use concrete examples. Update code refs when code changes. |

---

### Gap 7: Hook Architecture is Command-Only

All 23 hooks use `type: "command"`. Claude Code also supports:

| Type | What It Does | Best For |
|------|-------------|----------|
| `command` | Shell script (current) | Logging, file ops, tool wrapping |
| `http` | Webhook endpoint | External integrations, team dashboards |
| `prompt` | LLM-evaluated policy check | Security gates, quality gates |
| `agent` | Full agent evaluation | Complex verification, multi-step checks |

**Recommended additions:**
- One `prompt` hook for a stop/review gate (is the task actually done?)
- One `prompt` hook for post-write verification (does this code look safe?)
- Document `http` hooks for team dashboard integration

Also missing hook features on existing hooks:
- `timeout` on long-running hooks (build-checker, worktree-create)
- `statusMessage` on hooks that take >1s ("Injecting sprint context...")
- `once: true` on session-start to prevent duplicate injection on resume

---

### Gap 8: MCP Docs Are Just a Server List

Current `docs/recommended-mcps.md` lists 7 servers with install snippets. Claude Code MCP is broader:

| MCP Feature | Documented? | What's Missing |
|-------------|-------------|---------------|
| Tools | Yes | -- |
| Resources | **No** | MCP servers can expose resources (files, data) Claude can read |
| Prompts | **No** | MCP servers can provide prompt templates |
| Remote HTTP servers | **No** | OAuth-backed cloud MCP servers |
| Policy controls | **No** | `allowedMcpServers`, `deniedMcpServers`, `allowManagedMcpServersOnly` |
| Scoping (local vs project vs user) | **No** | Where MCP config lives and who sees it |
| Per-agent MCP | **No** | Agents can have scoped MCP access via frontmatter |

**Fix**: Upgrade from "here are 7 servers" to "here is the Claude Code MCP mental model" with examples for all of the above.

---

### Gap 9: No GitHub Actions Examples

The repo has `/mm:ci` and `/mm:github-setup` skills, but ships no actual workflow files. Claude Code now has official actions:

- `anthropics/claude-code-action@v1` -- high-level PR review, issue handling
- `anthropics/claude-code-base-action` -- lower-level, customizable

**Ship ready-made workflow examples:**
- PR review on every push
- Issue triage on new issues
- Automated code review with custom prompts
- Security scan on PRs touching auth code

---

### Gap 10: Missing Settings Features

| Setting | Currently Used? | What It Does |
|---------|----------------|-------------|
| `permissions` | No | Tool allow/deny rules |
| `worktree.symlinkDirectories` | No | Symlink node_modules etc. instead of copying (saves disk/time) |
| `worktree.sparsePaths` | No | Sparse checkout for monorepos |
| `sandbox` | No | Filesystem/network sandboxing |
| `outputStyle` | No | Customize Claude's output behavior |
| `modelOverrides` | No | Different models for planning vs execution |
| `effortLevel` | No | Default effort level |

**Recommended additions to settings.json:**

```json
{
  "effortLevel": "medium",
  "worktree": {
    "symlinkDirectories": ["node_modules", ".next", "dist", "build", "__pycache__"]
  }
}
```

---

## What to Add

### New Agents (4 High Priority)

| Agent | Purpose | Model | Why Missing Hurts |
|-------|---------|-------|-------------------|
| **migration-specialist** | Database migration safety: review for data loss, locking, rollback | opus | #1 requested agent type in community; migrations are the most dangerous code changes |
| **dependency-auditor** | Vulnerabilities, license issues, outdated packages, bloat | sonnet | Supply chain security is critical and `npm audit` output needs expert interpretation |
| **accessibility-auditor** | WCAG 2.1 AA/AAA, ARIA, keyboard nav, screen reader, color contrast | sonnet | Accessibility needs dedicated focus beyond frontend-architect |
| **devops-engineer** | IaC (Terraform, Pulumi), Docker, K8s, AWS/Azure/GCP, networking | opus | Infrastructure expertise completely absent from current roster |

**Medium priority (4 more):** mobile-developer, monorepo-specialist, data-engineer, regex-specialist

---

### New Skills (6 High Priority)

| Skill | What It Does | Why |
|-------|-------------|-----|
| `/mm:map` | Spawn parallel Explore agents to map codebase structure. Write `.planning/CODEBASE-MAP.md` | Cartographer pattern (537 stars). Essential for onboarding. |
| `/mm:deps` | Audit dependencies: vulnerabilities, outdated, license, unused, duplicates | Supply chain security. Pairs with dependency-auditor agent. |
| `/mm:a11y` | WCAG audit: compliance, ARIA, keyboard nav, color contrast | Pairs with accessibility-auditor agent. |
| `/mm:migrate` | Generate, review, test database migrations. Check data loss, locks, rollback | Pairs with migration-specialist agent. |
| `/mm:onboard` | Generate onboarding docs: architecture overview, key files, setup, glossary | Reduces time-to-productivity for new team members. |
| `/mm:stale` | Detect stale branches, PRs, issues, TODO comments | Housekeeping. Prevents drift. |

**Medium priority (6 more):** `/mm:benchmark`, `/mm:env`, `/mm:cross-check`, `/mm:cleanup`, `/mm:self-audit`, `/mm:diagram`

---

### New Hooks (4 Recommended)

| Event | Script | Purpose | Priority |
|-------|--------|---------|----------|
| `PermissionDenied` | `permission-denied.js` | Log denials, suggest alternatives, detect friction | HIGH |
| `CwdChanged` | `cwd-changed.js` | Re-inject context on directory change | MEDIUM |
| `SessionEnd` | Register existing `session-end.js` | Catch `clear`/`resume`/`logout` exits too | MEDIUM |
| `Notification` (idle) | `notification-idle.js` | Auto-checkpoint on idle | MEDIUM |

---

## What to Remove or Simplify

### Remove or Fix

| Item | Issue | Action |
|------|-------|--------|
| **4 broken CJS hooks** | Crash on execution | Convert to ESM or rename to `.cjs` |
| **README hook count claims** | Says 18, wires 14 | Fix settings.json or fix README |
| **Standalone statusline.json** | Not installed correctly | Merge into settings.json, copy statusline.sh |
| **`ALLOW_ALL = true` default** | Too permissive for public repo | Default conservative, opt-in permissive |

### Merge Overlapping Hooks

| Hook A | Hook B | Action |
|--------|--------|--------|
| `stop-event.js` (Stop) | `session-end.js` (Stop) | **Merge** -- both fire on Stop; combine risky-pattern scan + session summary into one |
| `context-recovery.js` (SessionStart) | `session-start.js` (SessionStart) | **Merge** -- both fire on SessionStart and inject context |

This reduces hook count from 18 to 16 and eliminates double-firing.

### Evaluate for Removal

| Item | Question | Recommendation |
|------|----------|---------------|
| **Codex support** (72 files) | Is anyone using the Codex output? | If unused, remove `src/codex/`, `setup-codex.*`, `setup-all.*`, and Codex rendering in `render-providers.mjs`. Saves ~70 files and simplifies the build pipeline. |
| **`error-handling-reminder.js`** | Is "empty catch block" noise for experienced devs? | Gate behind `CLAUDE_SOLO_ERROR_REMINDERS=1` env var (off by default) |
| **`build-checker.js` registration** | Registered under PostToolUse/Bash but checks file edits | Move to `FileChanged` event or re-register under `PostToolUse` with `Edit\|Write` matcher |
| **`/mm:dev-docs` + `/mm:dev-docs-update`** | Two skills for one concept | Consider merging into single `/mm:dev-docs` with auto-detect create vs update |

### Skills/Commands Vocabulary

The repo markets "skills" but installs to `.claude/commands/`. This creates confusion.

**Resolution options:**
1. Keep `.claude/commands` and document why (backward compatibility)
2. Dual-emit both commands and skills during migration
3. Migrate fully to `.claude/skills/` (recommended long-term)

---

## Community Landscape

### Top-Tier Repos (10K+ stars)

| Repo | Stars | What It Is | Relevance to claude-solo |
|------|-------|-----------|-------------------------|
| [obra/superpowers](https://github.com/obra/superpowers) | 143K | Skills framework + methodology | Dominant competitor. Study the composable skills model. |
| [anthropics/claude-code](https://github.com/anthropics/claude-code) | 112K | Official repo | Source of truth for features |
| [garrytan/gstack](https://github.com/garrytan/gstack) | 68K | Role-based agent personas | Already a claude-solo influence |
| [thedotmack/claude-mem](https://github.com/thedotmack/claude-mem) | 47K | Auto session memory capture | **Adopt pattern**: auto-capture session context for future sessions |
| [hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code) | 38K | Curated list | **Submit claude-solo here** |
| [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates) | 24K | CLI config tool | Study CLI patterns |
| [OthmanAdi/planning-with-files](https://github.com/OthmanAdi/planning-with-files) | 18K | Manus-style file planning | claude-solo already does this |
| [jarrodwatts/claude-hud](https://github.com/jarrodwatts/claude-hud) | 18K | Real-time context/agent HUD | **Adopt pattern**: enhanced statusline |
| [VoltAgent/awesome-claude-code-subagents](https://github.com/VoltAgent/awesome-claude-code-subagents) | 17K | 100+ subagents | Compare agent definitions |
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | 16K | Official plugin directory | **Submit claude-solo plugin here** |
| [VoltAgent/awesome-agent-skills](https://github.com/VoltAgent/awesome-agent-skills) | 15K | 1000+ cross-platform skills | **Submit skills here** |
| [travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills) | 11K | Curated skills list | **Submit here** |
| [alirezarezvani/claude-skills](https://github.com/alirezarezvani/claude-skills) | 10K | 220+ skills across domains | Compare skill coverage |

### High-Impact Repos (1K-10K stars)

| Repo | Stars | Key Pattern |
|------|-------|-------------|
| [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman) | 8.6K | Token savings via communication style (complements RTK) |
| [trailofbits/skills](https://github.com/trailofbits/skills) | 4.4K | Security skills from a top firm |
| [parcadei/Continuous-Claude-v3](https://github.com/parcadei/Continuous-Claude-v3) | 3.7K | Ledger-based state management across sessions |
| [disler/claude-code-hooks-mastery](https://github.com/disler/claude-code-hooks-mastery) | 3.5K | Definitive hooks reference |
| [nyldn/claude-octopus](https://github.com/nyldn/claude-octopus) | 2.5K | Multi-model verification before shipping |
| [lackeyjb/playwright-skill](https://github.com/lackeyjb/playwright-skill) | 2.4K | Browser automation skill |
| [centminmod/my-claude-code-setup](https://github.com/centminmod/my-claude-code-setup) | 2.2K | Memory bank pattern |
| [steipete/claude-code-mcp](https://github.com/steipete/claude-code-mcp) | 1.2K | Claude Code as MCP server (agent-in-agent) |
| [rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit) | 1.2K | 135 agents, 35 skills, 42 commands, 176 plugins |
| [Dicklesworthstone/claude_code_agent_farm](https://github.com/Dicklesworthstone/claude_code_agent_farm) | 779 | 20+ parallel agents with lock coordination |
| [kingbootoshi/cartographer](https://github.com/kingbootoshi/cartographer) | 537 | Automated codebase mapping via parallel subagents |
| [sandroandric/AgentHandover](https://github.com/sandroandric/AgentHandover) | 498 | Agent that learns from your patterns and generates skills |

### Community Patterns Worth Adopting

| Pattern | Source | Stars | How to Adopt |
|---------|--------|-------|-------------|
| **Session memory capture** | claude-mem | 47K | Enhance session-end.js to auto-compress and store session summaries. Enhance session-start.js to inject relevant past sessions. |
| **HUD / observability** | claude-hud | 18K | Enhance statusline to show context budget, active agent count, sprint stage. |
| **Codebase cartography** | cartographer | 537 | New `/mm:map` skill spawning parallel Explore agents. |
| **Security guard packs** | secure-claude-code | 86 | Pluggable guard packs for pre-tool-use: secrets, exfiltration, injection. |
| **Post-compaction rules reminder** | post_compact_reminder | 38 | Already have post-compact hook; ensure it re-injects critical rules (not just checkpoint). |
| **Self-improving config** | awesome-claude-code-config | 215 | New `/mm:self-audit` skill analyzing hook/skill usage patterns. |

### Where to Submit claude-solo

1. `hesreallyhim/awesome-claude-code` (38K stars) -- primary ecosystem list
2. `anthropics/claude-plugins-official` (16K) -- official plugin directory (once plugin packaged)
3. `VoltAgent/awesome-agent-skills` (15K) -- skill catalog
4. `travisvn/awesome-claude-skills` (11K) -- skill list
5. `VoltAgent/awesome-claude-code-subagents` (17K) -- agent catalog
6. `rohitg00/awesome-claude-code-toolkit` (1.2K) -- toolkit list
7. `ccplugins/awesome-claude-code-plugins` (676) -- plugin list

---

## Unified Roadmap

### Phase 1: Fix What's Broken (v0.3.0, ~1 week)

**Correctness (P0):**
- [ ] Convert 4 CJS hooks to ESM (build-checker, context-recovery, error-handling-reminder, stop-event)
- [ ] Wire all 18 hooks in settings.json (or adjust README to match reality)
- [ ] Fix statusline installation: merge into settings.json, install statusline.sh
- [ ] Flip `ALLOW_ALL` to `false` in permission-request.js
- [ ] Add `permissions` block (allow/deny) to settings.json
- [ ] Add CI smoke test executing every hook under installed packaging

**Quick cleanup:**
- [ ] Merge stop-event.js into session-end.js (both fire on Stop)
- [ ] Merge context-recovery.js into session-start.js (both fire on SessionStart)
- [ ] Gate error-handling-reminder.js behind env var (off by default)
- [ ] Fix build-checker.js registration (PostToolUse/Bash -> Edit|Write or FileChanged)

### Phase 2: Agent & Hook Hardening (v0.4.0, ~2 weeks)

**Agent frontmatter (highest impact):**
- [ ] Add `model` to all 24 agents (opus for judgment, sonnet for execution)
- [ ] Add `tools`/`disallowedTools` by role (read-only, review, implementation)
- [ ] Add `memory: project` to all agents
- [ ] Add `maxTurns` to all agents (30-100 based on role)
- [ ] Add `effort` to all agents (high for auditors, medium for others)
- [ ] Upgrade 5 swarm agent frontmatter

**New hooks:**
- [ ] Add `PermissionDenied` hook
- [ ] Add `CwdChanged` hook
- [ ] Register session-end.js under `SessionEnd` too (not just `Stop`)
- [ ] Add `Notification` (idle) hook
- [ ] Add `timeout` to long-running hooks
- [ ] Add `statusMessage` to hooks taking >1s
- [ ] Add `once: true` to session-start.js

**New rules (ship 8 starters):**
- [ ] migrations.md, tests.md, ci-workflows.md, env-files.md
- [ ] api-routes.md, security-sensitive.md, config-files.md, documentation.md

**Settings:**
- [ ] Add `worktree.symlinkDirectories` (node_modules, .next, dist, build)
- [ ] Add `effortLevel: "medium"` default

### Phase 3: Skills Migration (v0.5.0, ~2-3 weeks)

- [ ] Migrate 43 skills from `.claude/commands/mm/<name>.md` to `.claude/skills/mm-<name>/SKILL.md`
- [ ] Add full frontmatter: `allowed-tools`, `paths`, `shell`, `argument-hint`
- [ ] Add `context: fork` + `agent` type to 7 long-running skills
- [ ] Add dynamic context injection (`!command`) to doctor, ready, verify
- [ ] Dual-emit commands + skills during transition
- [ ] Update render pipeline for new format
- [ ] Add one `prompt` hook example (review gate)
- [ ] Add one `agent` hook example (security verification)

### Phase 4: Expand Coverage (v0.6.0, ~2-3 weeks)

**New agents (4 high priority):**
- [ ] migration-specialist, dependency-auditor, accessibility-auditor, devops-engineer
- [ ] Consider: mobile-developer, monorepo-specialist, data-engineer, regex-specialist

**New skills (6 high priority):**
- [ ] /mm:map, /mm:deps, /mm:a11y, /mm:migrate, /mm:onboard, /mm:stale
- [ ] Consider: /mm:benchmark, /mm:env, /mm:cross-check, /mm:cleanup, /mm:self-audit, /mm:diagram

**Docs upgrade:**
- [ ] Upgrade MCP docs: resources, prompts, policies, scoping, per-agent MCP
- [ ] Add GitHub Actions workflow examples (PR review, issue triage, security scan)
- [ ] Document CLAUDE.md imports (`@path/to/file`), CLAUDE.local.md, rules layering
- [ ] Add hook event policy doc (which events we support and why)

**Community patterns:**
- [ ] Session memory capture (auto-compress/inject past sessions)
- [ ] Enhanced statusline (context budget, agent count, sprint stage)

### Phase 5: Plugin Packaging (v1.0.0, ~2-3 weeks)

- [ ] Create `.claude-plugin/plugin.json` manifest
- [ ] Restructure for plugin directory layout
- [ ] Test plugin install/uninstall flow
- [ ] Submit to `anthropics/claude-plugins-official`
- [ ] Submit to awesome-claude-code, awesome-agent-skills, awesome-claude-skills
- [ ] Migration guide from standalone install to plugin
- [ ] Comprehensive test suite for all agents, skills, hooks
- [ ] Decide on Codex support (keep, simplify, or remove)
- [ ] Consider: output style examples, LSP server examples

---

## Reference: Claude Code Complete Feature Matrix

### All 26 Hook Events

| # | Event | Blocks? | claude-solo | Target |
|---|-------|---------|-------------|--------|
| 1 | SessionStart | No | **Wired** | Keep |
| 2 | UserPromptSubmit | Yes | **Wired** | Keep |
| 3 | PreToolUse | Yes | **Wired** | Keep |
| 4 | PermissionRequest | Yes | **Wired** | Keep |
| 5 | PermissionDenied | No | Missing | **Add** |
| 6 | PostToolUse | No | **Wired** | Keep |
| 7 | PostToolUseFailure | No | **Wired** | Keep |
| 8 | Notification | No | Missing | **Add** |
| 9 | SubagentStart | No | Swarm only | Keep |
| 10 | SubagentStop | Yes | **Wired** | Keep |
| 11 | TaskCreated | Yes | Swarm only | Keep |
| 12 | TaskCompleted | Yes | Swarm only | Keep |
| 13 | Stop | Yes | **Wired** | Keep |
| 14 | StopFailure | No | Missing | Skip |
| 15 | TeammateIdle | Yes | Swarm only | Keep |
| 16 | InstructionsLoaded | No | **Wired** | Keep |
| 17 | ConfigChange | Yes | **Wired** | Keep |
| 18 | CwdChanged | No | Missing | **Add** |
| 19 | FileChanged | No | **Wired** | Keep |
| 20 | WorktreeCreate | Yes | **Wired** | Keep |
| 21 | WorktreeRemove | No | Missing | Skip |
| 22 | PreCompact | No | **Wired** | Keep |
| 23 | PostCompact | No | **Wired** | Keep |
| 24 | Elicitation | Yes | Missing | Skip |
| 25 | ElicitationResult | Yes | Missing | Skip |
| 26 | SessionEnd | No | Missing | **Add** |

**Current: 18/26 -> Target: 22/26 (85%)**

### All Agent Frontmatter Fields

| Field | Type | Current Usage | Target |
|-------|------|---------------|--------|
| `name` | string | All agents | Keep |
| `description` | string | All agents | Keep |
| `model` | string | None | **Add to all** |
| `tools` | string[] | None | **Add to restricted agents** |
| `disallowedTools` | string[] | None | **Add to read-only/review agents** |
| `permissionMode` | string | None | Consider for read-only agents |
| `maxTurns` | number | None | **Add to all** |
| `skills` | string[] | None | Consider after skills migration |
| `mcpServers` | string[] | None | Low priority |
| `hooks` | object | None | Low priority |
| `memory` | string | None | **Add to all** |
| `effort` | string | None | **Add to all** |
| `color` | string | None | Nice to have |
| `initialPrompt` | string | None | Consider for complex agents |
| `background` | boolean | None | Low priority |
| `isolation` | string | None | Already in swarm-implementer body |

### All Skill Frontmatter Fields

| Field | Type | Current Usage | Target |
|-------|------|---------------|--------|
| `name` | string | All skills | Keep |
| `description` | string | All skills | Keep |
| `argument-hint` | string | None | **Add where applicable** |
| `user-invocable` | boolean | None | Default true (keep) |
| `disable-model-invocation` | boolean | None | Consider for dangerous skills |
| `allowed-tools` | string[] | None | **Add to all** |
| `model` | string | None | Consider for specific skills |
| `effort` | string | None | Consider |
| `context` | string | None | **Add `fork` to 7 long-running skills** |
| `agent` | string | None | **Add agent type when forked** |
| `hooks` | object | None | Low priority |
| `paths` | string[] | None | **Add for auto-activation** |
| `shell` | string | None | Add where cross-platform matters |

### Hook Handler Features

| Feature | Current Usage | Target |
|---------|---------------|--------|
| `type: "command"` | All hooks | Keep |
| `type: "http"` | None | Document, don't ship |
| `type: "prompt"` | None | **Add 1-2 examples** |
| `type: "agent"` | None | **Add 1 example** |
| `timeout` | None | **Add to long-running hooks** |
| `if` | None | Consider |
| `statusMessage` | None | **Add to slow hooks** |
| `once` | None | **Add to session-start** |

### Settings Fields

| Setting | Current | Target |
|---------|---------|--------|
| `model` | Yes | Keep |
| `maxTurns` | Yes | Keep |
| `hooks` | Yes (14 events) | Expand to 22 |
| `permissions` | No | **Add** |
| `worktree` | No | **Add symlinkDirectories** |
| `effortLevel` | No | **Add** |
| `sandbox` | No | Ship as template/docs only |
| `outputStyle` | No | Low priority |
| `modelOverrides` | No | Document |
| `statusLine` | Broken install | **Fix** |

---

## Sources

### Official Anthropic Documentation
- Settings: https://code.claude.com/docs/en/settings
- Memory: https://code.claude.com/docs/en/memory
- Skills: https://code.claude.com/docs/en/slash-commands
- Subagents: https://code.claude.com/docs/en/sub-agents
- Hooks: https://code.claude.com/docs/en/hooks
- MCP: https://code.claude.com/docs/en/mcp
- Plugins: https://code.claude.com/docs/en/plugins
- Plugin marketplaces: https://code.claude.com/docs/en/plugin-marketplaces
- GitHub Actions: https://code.claude.com/docs/en/github-actions

### Official GitHub Repos
- https://github.com/anthropics/claude-code (112K stars)
- https://github.com/anthropics/claude-code-action
- https://github.com/anthropics/claude-code-base-action
- https://github.com/anthropics/claude-plugins-official (16K stars)

### Research Inputs
- `docs/claude-code-research-and-recommendations.md` -- correctness audit, drift analysis
- `RESEARCH-AND-RECOMMENDATIONS.md` -- ecosystem survey (90+ repos), feature gap analysis
