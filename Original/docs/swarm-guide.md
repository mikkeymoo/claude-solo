# Swarm Coding Sessions

Run multiple Claude Code agents in parallel on the same codebase — coordinated through shared task lists, inter-agent messaging, and quality gate hooks.

## Quick Start

```bash
# Interactive swarm session
bash run-swarm.sh

# Swarm with a specific task
bash run-swarm.sh "Refactor the auth module — split into JWT validation, session management, and password hashing"

# Windows
.\run-swarm.ps1 "Refactor the auth module"
```

## What's Included

### Swarm Hooks (5)

Quality gates that enforce standards across all teammates:

| Hook | Event | What it does |
|------|-------|-------------|
| `subagent-start.js` | SubagentStart | Injects project context (git state, sprint docs, coordination rules) into every spawned agent |
| `teammate-idle.js` | TeammateIdle | Blocks teammates from going idle if work isn't committed/documented |
| `task-created.js` | TaskCreated | Blocks vague or oversized tasks — forces atomic decomposition |
| `task-completed.js` | TaskCompleted | Verifies actual evidence of completion (git changes, test files, docs) |
| `stop-gate.js` | Stop | Prevents lead from stopping while teammates are still active (opt-in) |

### Swarm Agents (5)

Specialized agents designed to work as teammates in agent teams:

| Agent | Role | Model | Key Feature |
|-------|------|-------|-------------|
| `swarm-lead` | Team coordinator | Opus | Decomposes tasks, spawns teammates, synthesizes results. Has project memory |
| `swarm-implementer` | Code writer | Sonnet | Runs in isolated git worktree to prevent file conflicts |
| `swarm-researcher` | Read-only investigator | Sonnet | Explores codebase, APIs, and docs. Cannot modify files |
| `swarm-reviewer` | Senior code reviewer | Opus | Three-pass review (defects, edge cases, acceptance). Auto-fixes RED issues |
| `swarm-tester` | Test specialist | Sonnet | Runs existing tests first, writes new ones, reports coverage |

## Installation

The swarm components are installed automatically by `setup.sh`. To add them to an existing claude-solo install:

```bash
# Copy hooks
cp -r src/hooks/swarm/ ~/.claude/hooks/swarm/

# Copy agents
cp src/agents/swarm-*.md ~/.claude/agents/

# Merge swarm settings into your settings.json
# (or manually add the hooks from src/settings/settings-swarm.json)
```

To enable agent teams (required):

```json
// In ~/.claude/settings.json
{
  "env": {
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  }
}
```

## How It Works

### Architecture

```
You (user)
 └─> Swarm Lead (team coordinator)
      ├─> Researcher (explores codebase, gathers context)
      ├─> Implementer A (writes code in worktree A)
      ├─> Implementer B (writes code in worktree B)
      ├─> Tester (runs tests, writes new tests)
      └─> Reviewer (reviews all changes last)
```

### Communication Flow

1. **Lead decomposes** the task into 3-6 independent work items
2. **Lead spawns teammates** with specific prompts and file assignments
3. **Teammates work independently**, each in their own context window
4. **Teammates message each other** to share findings and coordinate
5. **Quality hooks fire** when tasks are created/completed and teammates go idle
6. **Lead synthesizes** results and presents the final deliverable

### Quality Gates

The swarm hooks enforce quality at every stage:

**Task Creation** — `task-created.js` blocks:
- Titles shorter than 10 characters
- Obviously vague tasks ("do stuff", "fix it")
- Compound tasks with multiple "and" conjunctions

**Task Completion** — `task-completed.js` verifies:
- Code tasks actually have git modifications
- Test tasks actually modified test files
- Documentation tasks actually touched .md/.rst files

**Teammate Idle** — `teammate-idle.js` checks:
- Implementers committed their changes
- Testers produced test output
- Reviewers documented their findings

**Stop Gate** (opt-in) — `stop-gate.js` prevents:
- Lead from stopping while teammates are still active
- Lead from stopping while tasks are pending/in-progress

## Usage Patterns

### Pattern 1: Feature Implementation

```bash
bash run-swarm.sh "Implement user profile page with avatar upload, bio editing, and activity feed"
```

The lead will typically:
1. Spawn a researcher to analyze the existing user model and API
2. Spawn 2-3 implementers for avatar, bio, and feed components
3. Spawn a tester to write integration tests
4. Spawn a reviewer to check everything after implementation

### Pattern 2: Parallel Investigation

```bash
bash run-swarm.sh "Users report the app crashes after login. Investigate from 3 angles: auth flow, session management, and frontend state"
```

The lead spawns 3 researchers, each investigating a different hypothesis. They message each other to challenge findings and converge on the root cause.

### Pattern 3: Codebase Refactor

```bash
bash run-swarm.sh "Refactor the monolithic routes.ts into separate route modules by domain" --teammates 4
```

Each implementer owns a different domain's routes. The researcher maps dependencies first. The reviewer checks for broken imports after.

### Pattern 4: Review Swarm

```bash
bash run-swarm.sh "Review PR #142 from three angles: security, performance, and test coverage" --teammates 3
```

Three specialized reviewers examine the same PR through different lenses. The lead synthesizes findings.

### Pattern 5: Using swarm-lead as the main agent

```bash
bash run-swarm.sh --agent swarm-lead "Build the notification system"
```

This runs the swarm-lead agent definition as the main session, giving it the coordinator prompt and project memory from the start.

## Configuration

### Enable the stop gate

The stop gate prevents the lead from stopping prematurely. Off by default:

```bash
# Via flag
bash run-swarm.sh --gate "your task"

# Via environment
export CLAUDE_SOLO_SWARM_GATE=1
```

### Display modes

```bash
# Split panes (requires tmux)
bash run-swarm.sh --split "your task"

# In-process (default — use Shift+Down to cycle teammates)
bash run-swarm.sh --in-process "your task"
```

### Customizing agents

Edit the agent files in `~/.claude/agents/` (or `.claude/agents/` for project-specific):

- Change `model` to use different Claude models
- Adjust `tools` to restrict what agents can do
- Modify `permissionMode` for different safety levels
- Add `hooks` for agent-specific behavior
- Set `memory: project` or `memory: user` for persistent learning

### Adding your own swarm agents

Create a new file in `src/agents/` following the pattern:

```markdown
---
name: swarm-your-role
description: When to use this agent (Claude reads this to decide delegation)
model: sonnet
memory: project
color: yellow
---

Your system prompt here. Tell the agent:
1. What its role is
2. How to coordinate with teammates
3. Where to save outputs
4. What rules to follow
```

## Comparison: Subagents vs Agent Teams

| | Subagents (existing) | Agent Teams (swarm) |
|---|---|---|
| **When to use** | Quick, focused tasks | Complex parallel work |
| **Communication** | Results back to caller only | Teammates message each other |
| **Context** | Shares parent context | Fully independent |
| **Coordination** | Parent manages all work | Shared task list, self-claiming |
| **Token cost** | Lower | Higher (each teammate = separate session) |
| **Best for** | Research, validation, review | Features, refactors, investigations |

**Rule of thumb:** If workers need to talk to each other, use agent teams. If they just need to report back, use subagents.

## Limitations

Agent teams are experimental. Current limitations:

- No session resumption with in-process teammates
- Task status can lag (teammates may forget to mark tasks done)
- One team per session
- No nested teams (teammates can't spawn their own teams)
- Split panes require tmux or iTerm2
- Higher token usage (each teammate has its own context window)

## Files Reference

```
src/
├── hooks/swarm/
│   ├── subagent-start.js      # Context injection for all agents
│   ├── teammate-idle.js       # Quality gate when teammate finishes
│   ├── task-created.js        # Task quality validation
│   ├── task-completed.js      # Completion evidence checking
│   └── stop-gate.js           # Prevents premature shutdown
├── agents/
│   ├── swarm-lead.md          # Team coordinator
│   ├── swarm-implementer.md   # Code writer (isolated worktree)
│   ├── swarm-researcher.md    # Read-only investigator
│   ├── swarm-reviewer.md      # Senior code reviewer
│   └── swarm-tester.md        # Test specialist
├── settings/
│   └── settings-swarm.json    # Swarm hook configuration
run-swarm.sh                   # Linux/macOS launcher
run-swarm.ps1                  # Windows launcher
docs/
└── swarm-guide.md             # This file
```
