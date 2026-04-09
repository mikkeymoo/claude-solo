# claude-solo: Research And Recommendations

Generated: 2026-04-09

## Executive Summary

`claude-solo` already has strong breadth for a Claude Code setup repo:

- 29 Claude agents in `src/agents/`
- 43 Claude commands in `src/commands/mm/`
- 43 generated Codex skills in `src/codex/skills/`
- 18 core hooks plus 5 swarm hooks in `src/hooks/`
- a provider-render pipeline
- worktree support
- swarm / team support
- Codex compatibility

The repo does not need a larger command list. It needs tighter correctness and better alignment with current Claude Code capabilities.

The most important findings are:

1. The README claims more installed hooks than `settings.json` actually wires.
2. Several shipped hook files are broken under the repo's own ESM packaging.
3. Status line installation is packaged incorrectly for current Claude Code settings.
4. Default permission behavior is too permissive for a public setup repo.
5. The repo still leans on legacy command layout for Claude and does not yet offer plugin / marketplace packaging.
6. There is room to adopt newer Claude Code surfaces: richer skill frontmatter, more hook types, plugin packaging, better MCP guidance, and official GitHub automation examples.

## What You Have Today

| Category | Current state |
|---|---|
| Claude commands | 43 in `src/commands/mm/` |
| Shared source commands | 43 in `src/shared/commands/mm/` |
| Claude agents | 29 in `src/agents/` |
| Codex skills | 43 in `src/codex/skills/` |
| Codex agents | 24 in `src/codex/agents/` |
| Core hooks | 18 files in `src/hooks/` |
| Swarm hooks | 5 files in `src/hooks/swarm/` |
| Main settings | `src/settings/settings.json`, `src/settings/settings-swarm.json` |
| MCP templates | `src/mcp.json`, `src/codex/mcp.json` |
| Provider generation | `scripts/render-providers.mjs` |

Strategically, these are good choices:

- shared-source generation for multiple providers
- preserving user `CLAUDE.md`
- preserving existing `settings.json`
- MCP templates disabled by default
- explicit swarm / parallel workflow concepts
- separate docs for usage and swarm flows

## Current Claude Code Surface Area You Should Design For

Based on current official Anthropic documentation, the relevant Claude Code capability surface is broader than older setup repos usually assume.

### Skills and commands

Claude currently centers custom extensions around skills under:

- `~/.claude/skills/<skill-name>/SKILL.md`
- `.claude/skills/<skill-name>/SKILL.md`
- plugin-provided skill directories

Important current skill features include:

- `argument-hint`
- `allowed-tools`
- `disable-model-invocation`
- `user-invocable`
- support files alongside `SKILL.md`

Claude still supports `.claude/commands/`, but the skill model is now the primary abstraction.

### Subagents

Current subagent capabilities worth using intentionally:

- explicit tool restrictions
- model selection
- memory scope
- turn limits
- role-specific specialization

### Hooks

Current hook system supports:

- `command`
- `http`
- `prompt`
- `agent`

Relevant modern events include:

- `SessionStart`
- `PreToolUse`
- `PostToolUse`
- `PostToolUseFailure`
- `PermissionRequest`
- `PermissionDenied`
- `UserPromptSubmit`
- `SubagentStart`
- `SubagentStop`
- `TaskCreated`
- `TaskCompleted`
- `TeammateIdle`
- `Stop`
- `StopFailure`
- `WorktreeCreate`
- `WorktreeRemove`
- `PreCompact`
- `PostCompact`
- `SessionEnd`
- `Notification`
- `ConfigChange`
- `InstructionsLoaded`
- `CwdChanged`
- `FileChanged`
- `Elicitation`
- `ElicitationResult`

Important hook features you can design around now:

- async hooks
- HTTP hooks
- prompt and agent validation hooks
- per-hook URL and env allowlists
- MCP tool hook integration

### Memory and instruction layering

Important current surfaces:

- `CLAUDE.md`
- `CLAUDE.md` imports via `@path/to/file`
- shared project settings
- local project settings
- path-specific rules
- local-only instruction layering patterns

### MCP

Current MCP surface is more than just local tool servers. It includes:

- tools
- resources
- prompts
- project-scoped configuration
- remote HTTP servers
- OAuth-backed servers
- policy controls like allowed and denied servers

### Plugins and marketplaces

This is the largest missing strategic surface in this repo.

Current Claude Code supports:

- plugins
- plugin marketplaces
- plugin installation scopes
- namespaced plugin skills
- plugin-provided agents, hooks, MCP servers, output styles, and LSP server config
- official marketplace submission flow

### Output and UI customization

Relevant current surfaces:

- `statusLine`
- output styles
- spinner customization
- IDE connectivity settings

### Automation outside the local session

Official Anthropic automation surfaces now include:

- Claude Code SDK
- `anthropics/claude-code-action`
- `anthropics/claude-code-base-action`

### Parallelism models

There are at least three distinct patterns to support cleanly:

- ordinary subagents
- agent teams / task lifecycle hooks
- external automation via SDK or CI

## Concrete Problems In This Repo

### P0: README hook claims do not match actual installed settings

The README presents 18 core hooks as installed, including:

- `stop-event`
- `build-checker`
- `context-recovery`
- `error-handling-reminder`

But `src/settings/settings.json` does not wire those files.

Evidence:

- `README.md:193-210`
- `src/settings/settings.json:4-148`

Recommendation:

- Either wire those hooks in `src/settings/settings.json`, or remove the claim that they are installed automatically.

### P0: Four shipped hooks are broken under ESM packaging

The repo marks the hooks directory as ESM via `src/hooks/package.json`:

```json
{ "type": "module" }
```

But these files still use CommonJS syntax:

- `src/hooks/build-checker.js`
- `src/hooks/context-recovery.js`
- `src/hooks/error-handling-reminder.js`
- `src/hooks/stop-event.js`

This is an actual runtime failure. Running `node src/hooks/stop-event.js` fails because `require` is not available in ESM scope.

Recommendation:

- Convert those files to ESM, or rename them to `.cjs` and install them consistently.
- Add a smoke test that executes every shipped hook once under the installed runtime mode.

### P0: Status line installation is wrong for current Claude Code settings

The repo ships `src/settings/statusline.json`, but the installers copy it as a standalone file and do not merge `statusLine` into `settings.json`. They also do not appear to install `src/settings/statusline.sh`.

Evidence:

- `src/settings/statusline.json:1-7`
- `setup.sh:186-214`
- `setup.ps1:155-188`

Recommendation:

- Treat `statusLine` as a normal settings field and merge it into `settings.json`.
- Install `statusline.sh` together with that setting.
- Remove the implication that `~/.claude/statusline.json` is a first-class standalone config location.

### P0: Default permission posture is too permissive

`src/hooks/permission-request.js` defaults to `ALLOW_ALL = true`, which auto-approves almost everything except a few catastrophic patterns.

Recommendation:

- Make the safe mode the default.
- Offer the current behavior as an explicit opt-in fast mode.
- Add `permissions.deny` examples for obvious sensitive files and destructive shell patterns.

### P1: Claude install path still uses legacy command layout

The repo markets skills, but the Claude installer still writes commands into `.claude/commands/mm/*.md` rather than `.claude/skills/<name>/SKILL.md`.

This is still compatible, but it underuses the modern skill model.

Recommendation:

- Either document this as an intentional compatibility choice, or start a migration plan.
- Best path: dual-emit commands and skills during transition, then simplify later.

### P1: No plugin or marketplace packaging

The repo has no plugin packaging surface yet:

- no `.claude-plugin/plugin.json`
- no marketplace manifest
- no plugin directories
- no plugin settings examples

Recommendation:

- Add a plugin distribution path for `claude-solo-core`.
- Keep standalone `.claude/` install for local iteration, but use plugins as the long-term distribution model.

### P1: Hook architecture is command-only

Current official Claude Code supports `command`, `http`, `prompt`, and `agent` hooks, but this repo only ships command hooks.

Recommendation:

- Keep command hooks for simple automation.
- Add at least one strong prompt or agent hook example for validation or safety gating.

### P1: Several modern hook events are unused

Not currently covered in shipped settings:

- `PermissionDenied`
- `CwdChanged`
- `Notification`
- `WorktreeRemove`
- `StopFailure`
- `Elicitation`
- `ElicitationResult`
- likely incomplete `SessionEnd` coverage because `session-end.js` is wired under `Stop`

Recommendation:

- Add `PermissionDenied`, `CwdChanged`, `Notification`, and better `SessionEnd` coverage first.
- Treat the rest as optional unless your MCP story depends on them.

### P1: MCP docs are too server-template oriented

Current docs and templates focus on server snippets. Current Claude Code MCP value is broader:

- resources
- prompts
- remote HTTP servers
- OAuth
- project vs local policy
- allowed / denied server controls

Recommendation:

- Rework MCP docs around the Claude Code MCP mental model, not just a list of example servers.

## Community Patterns Worth Adopting

These ideas from the broader ecosystem are worth considering, independent of any single repo's hype.

### 1. Automatic session memory capture

You already have `/mm:handoff` and `/mm:pause`, but they are manual.

Recommendation:

- auto-capture compressed session summaries on exit
- auto-inject recent relevant summaries on session start
- store them under a project-local session state directory

### 2. Better observability / HUD behavior

Users consistently want to know:

- context usage
- current stage
- active agents
- whether they are close to compression or rate limits

Recommendation:

- improve the status line once installation is fixed
- include current sprint stage and active-agent count if available

### 3. Codebase mapping skill

Recommendation:

- add `/mm:map`
- use parallel exploration to generate `.planning/CODEBASE-MAP.md`
- target onboarding and large-repo orientation

### 4. Pluggable security guard packs

Recommendation:

- make `pre-tool-use` extensible
- ship default packs for secrets, exfiltration patterns, and unsafe command construction

### 5. Self-audit capability

Recommendation:

- add `/mm:self-audit`
- inspect logs, hook usage, agent usage, and failure patterns
- output concrete configuration improvements

## What Could Be Removed Or Simplified

### 1. Reconcile or remove non-installed hook claims

This is the simplest cleanup and should happen immediately.

### 2. Merge overlapping hook responsibilities

Potential consolidation points:

- `stop-event.js` and `session-end.js`
- `context-recovery.js` and `session-start.js`
- checkpoint logic spread across `pre-compact`, `post-compact`, and context recovery

Recommendation:

- consolidate only after the runtime defects are fixed
- keep the behavior explicit and testable

### 3. Re-evaluate overlap between similar skills

Worth reviewing:

- `/mm:pause` vs `/mm:handoff`
- `/mm:dev-docs` vs `/mm:dev-docs-update`

Recommendation:

- keep both only if the distinction is obvious and documented

### 4. Consider whether the Codex output is still worth the maintenance cost

This repo carries a non-trivial `src/codex/` surface and provider rendering logic.

Recommendation:

- keep it if it is actively used
- otherwise it is a real simplification candidate

## New Agents To Add

### High priority

- `migration-specialist`
  - database migration safety, rollback analysis, lock risk, data loss review
- `dependency-auditor`
  - vulnerabilities, outdated packages, license issues, bloat, unused deps
- `accessibility-auditor`
  - WCAG, ARIA, keyboard navigation, screen reader compatibility
- `devops-engineer`
  - Docker, IaC, CI/CD, cloud infra, networking

### Medium priority

- `mobile-developer`
- `monorepo-specialist`
- `data-engineer`

### Lower priority

- `i18n-specialist`
- `seo-specialist`
- `game-developer`

## New Skills To Add

### High priority

- `/mm:map`
  - generate a codebase map
- `/mm:deps`
  - audit dependencies and interpret results
- `/mm:a11y`
  - run an accessibility audit
- `/mm:migrate`
  - generate and review migrations safely
- `/mm:onboard`
  - produce onboarding documentation for a repo
- `/mm:stale`
  - inspect stale branches, PRs, issues, and TODOs

### Medium priority

- `/mm:benchmark`
- `/mm:env`
- `/mm:cross-check`
- `/mm:cleanup`
- `/mm:self-audit`
- `/mm:diagram`

## New Hooks To Add

Recommended additions:

- `PermissionDenied`
  - log denied operations and suggest alternatives
- `CwdChanged`
  - refresh project context when moving across directories or monorepo packages
- `Notification`
  - auto-save checkpoint on idle prompts
- better `SessionEnd` registration
  - ensure state capture also happens on clear, resume, and logout flows

Recommended upgrades to existing hooks:

- add `timeout` to long-running hooks
- add `statusMessage` where hooks take noticeable time
- use async hooks for post-edit validation or longer-running checks

## Starter Rules To Ship

The repo already teaches users how to create `.claude/rules/`, but it ships no starter rules. That is a gap.

Recommended starter rules:

1. `migrations.md`
   - migration safety and rollback expectations
2. `tests.md`
   - deterministic test rules and anti-flake guidance
3. `ci-workflows.md`
   - workflow pinning, secret handling, fail-fast expectations
4. `env-files.md`
   - no real secrets, placeholder values only, validate against examples
5. `api-routes.md`
   - input validation, error shapes, status code consistency
6. `security-sensitive.md`
   - auth, crypto, middleware, credential handling
7. `config-files.md`
   - preserve syntax, comments, and non-obvious config rationale
8. `documentation.md`
   - concise docs, concrete examples, keep references current

## Agent Frontmatter Upgrades

This is one of the highest-value improvements.

Current agents underuse available frontmatter. Add, at minimum:

- `model`
- `tools` or `disallowedTools`
- `memory`
- `maxTurns`
- effort / reasoning configuration where supported

Recommended role patterns:

- read-only analysts and researchers should not have edit tools
- reviewers should have constrained tool access
- high-stakes reviewers should get higher-effort model settings
- swarm roles should declare clearer runtime constraints

## Skill Format Migration

Recommended target:

- move toward `src/shared/skills/<skill-name>/SKILL.md`
- allow support files like templates and scripts
- use richer frontmatter consistently

High-value frontmatter to adopt:

- `argument-hint`
- `allowed-tools`
- `disable-model-invocation`
- `user-invocable`

Potential advanced uses worth adopting carefully:

- forked execution for long-running review or audit skills
- dynamic context injection where it clearly reduces setup friction

## Settings Enhancements

Recommended additions or improvements:

- `permissions` block with safe defaults
- documented optional sandbox examples
- explicit status line installation through `settings.json`
- model override guidance if you want role-specific model policy
- project-safe default `additionalDirectories` examples only where needed
- plugin-related settings examples once plugin packaging exists

## Plugin Opportunity

Long-term, `claude-solo` should probably exist in two forms:

1. standalone `.claude/` installer for fast local iteration
2. plugin / marketplace package for clean distribution and updates

Recommended plugin structure:

- `.claude-plugin/plugin.json`
- `commands/` or `skills/`
- `agents/`
- `hooks/`
- optional `mcp.json`
- optional output styles and LSP config

Benefits:

- versioned updates
- shareable installation
- cleaner team rollout
- alignment with current Claude Code distribution model

## Best Repos To Watch

Official / highest-signal:

1. `anthropics/claude-code-action`
   - official GitHub automation reference
   - https://github.com/anthropics/claude-code-action
2. `anthropics/claude-code-base-action`
   - lower-level automation reference
   - https://github.com/anthropics/claude-code-base-action
3. `hesreallyhim/awesome-claude-code`
   - broad ecosystem index for hooks, commands, plugins, and examples
   - https://github.com/hesreallyhim/awesome-claude-code
4. `shanraisshan/claude-code-best-practice`
   - broad practice and orchestration examples
   - https://github.com/shanraisshan/claude-code-best-practice
5. `davila7/claude-code-templates`
   - reusable setup and template patterns
   - https://github.com/davila7/claude-code-templates
6. `ChrisWiles/claude-code-showcase`
   - smaller example-oriented reference
   - https://github.com/ChrisWiles/claude-code-showcase

## Priority Roadmap

### Phase 1: Correctness and trust

- fix the four broken ESM/CommonJS hooks
- reconcile README hook claims with installed settings
- fix status line installation
- flip permission defaults to safe-by-default

### Phase 2: Modern Claude Code alignment

- add richer skill frontmatter
- add agent frontmatter upgrades
- ship starter rules
- add modern hook coverage for the highest-value missing events
- improve MCP docs around resources, prompts, and policy

### Phase 3: Product expansion

- add new agents and skills only where they fill real gaps
- add official GitHub Actions examples
- add self-audit and codebase-map capabilities

### Phase 4: Distribution modernization

- add plugin packaging
- add marketplace manifest
- document team rollout and update strategy

## Recommended Immediate Next Actions

If you want the highest leverage sequence, do this next:

1. Fix hook/runtime correctness.
2. Fix install/docs drift.
3. Add safe default permissions.
4. Add starter rules.
5. Add plugin packaging.
6. Then add new skills and agents.

## Sources

### Official Claude Code docs

- Setup: https://docs.anthropic.com/en/docs/claude-code/setup
- Settings: https://code.claude.com/docs/en/settings
- Memory: https://code.claude.com/docs/en/memory
- Skills / slash commands: https://code.claude.com/docs/en/slash-commands
- Subagents: https://code.claude.com/docs/en/sub-agents
- Hooks: https://code.claude.com/docs/en/hooks
- MCP: https://code.claude.com/docs/en/mcp
- Plugins: https://code.claude.com/docs/en/plugins
- Plugin marketplaces: https://code.claude.com/docs/en/plugin-marketplaces
- Plugins reference: https://code.claude.com/docs/en/plugins-reference
- SDK: https://docs.anthropic.com/en/docs/claude-code/sdk
- GitHub Actions: https://code.claude.com/docs/en/github-actions

### GitHub repos

- https://github.com/anthropics/claude-code-action
- https://github.com/anthropics/claude-code-base-action
- https://github.com/hesreallyhim/awesome-claude-code
- https://github.com/shanraisshan/claude-code-best-practice
- https://github.com/davila7/claude-code-templates
- https://github.com/ChrisWiles/claude-code-showcase
