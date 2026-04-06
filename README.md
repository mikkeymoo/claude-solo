# claude-solo

Best-of Claude Code config — 7-stage pipeline, smart agents, hooks, and skills in one install.

Combines the best patterns from gstack, GSD, and SuperClaude. No domain lock-in.

## Install

**Windows (PowerShell):**
```powershell
git clone https://github.com/yourusername/claude-solo.git
cd claude-solo

.\setup.ps1              # Install globally (all projects)
.\setup.ps1 --project    # Install into current project only
.\setup.ps1 --both       # Install globally AND into current project
```

**Linux / WSL / macOS:**
```bash
git clone https://github.com/yourusername/claude-solo.git
cd claude-solo

bash setup.sh             # Install globally (all projects)
bash setup.sh --project   # Install into current project only
bash setup.sh --both      # Install globally AND into current project
```

**Uninstall:**
```powershell
.\setup.ps1 --uninstall           # Remove from global
.\setup.ps1 --uninstall --project # Remove from project
```

Open Claude Code and you're done. Your commands are prefixed with `mm:` so they don't collide with other skill sets.

---

## What Gets Installed

### Skills (Slash Commands)
| Command | What it does | Time |
|---------|-------------|------|
| `/mm:brief` | Define scope + acceptance criteria | 15 min |
| `/mm:plan` | Atomic tasks, architecture, test matrix | 30 min |
| `/mm:build` | Implement in waves, atomic commits | 60-120 min |
| `/mm:review` | Staff-engineer review, auto-fixes | 30 min |
| `/mm:test` | Unit + integration + cross-platform | 30-45 min |
| `/mm:ship` | Merge, verify deploy, monitor | 15-30 min |
| `/mm:retro` | What shipped, what to fix, next sprint | 15 min |

### Agents
| Agent | Role |
|-------|------|
| `senior-reviewer` | Specific, prioritized code reviews (🔴/🟡/🔵) |
| `planner` | Turns vague requirements into executable atomic tasks |
| `debugger` | Systematic root-cause analysis, never guesses |
| `test-writer` | Tests that catch real bugs, not coverage theater |

### Hooks
| Hook | What it does |
|------|-------------|
| `pre-tool-use` | Blocks dangerous commands before they run |
| `post-tool-use` | Logs commands, nudges RTK usage for token savings |
| `prompt-submit` | Auto-injects sprint context (BRIEF.md, PLAN.md) into every prompt |

### CLAUDE.md (appended, never overwrites)
- 7-stage sprint rules and order
- RTK token optimization command examples
- Cross-platform coding rules (Windows + Linux)
- Atomic git commit workflow
- Code quality principles (no premature abstraction, etc.)

---

## The 7-Stage Sprint

Every feature, every fix — follow the pipeline in order:

```
/mm:brief    →  scope it          (15 min)
/mm:plan     →  plan it           (30 min)
/mm:build    →  build it          (60-120 min)
/mm:review   →  review it         (30 min)
/mm:test     →  test it           (30-45 min)
/mm:ship     →  ship it           (15-30 min)
/mm:retro    →  learn from it     (15 min)
```

**Total: 4-6 hours for a well-scoped feature.**

---

## Global vs Project Install

| Scope | Where | When to use |
|-------|-------|-------------|
| `global` (default) | `~/.claude/` | Your config for all projects |
| `--project` | `./.claude/` | Project-specific overrides |
| `--both` | Both | Override global with project-specific customization |

**Tip**: Install globally first, then use `--project` to override agents or skills per-project.

---

## Safe to Install

- **CLAUDE.md**: appended inside markers, never overwrites your content
- **settings.json**: hooks are merged, your existing settings preserved
- **agents/skills**: only adds files, doesn't touch what you already have
- **Uninstall**: removes only what it installed, leaves your config intact

---

## What This Doesn't Include

- No domain-specific tools
- No openclaw (ever)
- No premium tier, no telemetry, no accounts

MIT licensed.
