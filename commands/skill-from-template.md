---
name: mm:skill-from-template
description: Scaffold a new Claude Code skill under ~/.claude/skills/<name>/SKILL.md with proper frontmatter, trigger keywords, and usage guidance. Inspired by the forge skill-creation pattern.
---

# /mm:skill-from-template — Create a New Skill

Generate a well-structured skill scaffold that Claude Code will auto-discover.

## Usage

```
/mm:skill-from-template <name> [description] [trigger-keywords]
```

Example:

```
/mm:skill-from-template sql-helper "Query SQL Server databases safely" "sql, query, sqlcmd, database"
```

## What this does

1. Validates the skill name (lowercase, hyphens only, no spaces)
2. Creates `~/.claude/skills/<name>/SKILL.md` with:
   - Proper YAML frontmatter (`name`, `description`)
   - A "When to use" section with the trigger keywords
   - A placeholder usage section
   - A placeholder implementation section
3. Confirms the skill is discoverable (top-level `~/.claude/skills/<name>/SKILL.md`)
4. Prints the path and suggested invocation

## Scaffold template

```markdown
---
name: <name>
description: <description>. Use when: <trigger-keywords>.
---

# /<name>

<one-sentence description of what this skill does>

## When to use

Trigger keywords: <trigger-keywords>

Use this skill when the user asks about: <list scenarios>

## Usage

\`\`\`
/<name> [arguments]
\`\`\`

## What it does

1. Step one
2. Step two
3. Step three

## Notes

- Add any caveats, prerequisites, or limitations here
```

## Validation rules (enforce before writing)

- Name must match `^[a-z][a-z0-9-]*$` — lowercase letters, digits, hyphens only
- Name must not conflict with existing skills in `~/.claude/skills/`
- Description must include "Use when:" clause (prompts user if missing)
- Skill file must be at exactly `~/.claude/skills/<name>/SKILL.md` — nested subdirs are NOT auto-discovered

## After creating

Tell the user:

- Full path written
- How to invoke: `/<name>`
- Reminder: restart Claude Code session for new skills to appear in `/skills`
