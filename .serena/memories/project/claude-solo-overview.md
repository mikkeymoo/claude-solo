# Claude Solo Project Overview

## Purpose
Claude Code configuration for solo developers. Provides hooks, agents, skills, and rules for efficient development.

## Tech Stack
- TypeScript (main codebase)
- Python (bundled skill scripts)
- Bash (hooks and installation)
- Git-based development

## Project Structure
- `skills/` - Agent skills with SKILL.md + optional Python scripts
- `hooks/` - Git and lifecycle hooks
- `agents/` - Specialist subagents (ult-* prefix)
- `rules/` - Engineering rules (auto-loaded)

## Skill Pattern
Each skill has:
1. `skills/<name>/SKILL.md` - YAML frontmatter (name, description, argument-hint) + markdown instructions
2. Optional: `skills/<name>/<script>.py` - bundled Python script for helper logic

YAML format:
```yaml
---
name: skill-name
description: "Description for /skill-name"
argument-hint: "Optional hint for arguments"
---
```

## Python Script Pattern
- Shebang: `#!/usr/bin/env python3`
- Docstring with usage examples
- Standalone CLI tool with argparse or simple sys.argv
- Used via `python ~/.claude/skills/<name>/<script>.py [args]`
