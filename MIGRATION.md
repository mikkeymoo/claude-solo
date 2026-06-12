# Migrating to v2.0 — `/mm-*` commands

v2.0 renames every claude-solo skill command from the colon-namespaced
`/claude-solo:<skill>` to a dash-prefixed `/mm-<skill>` (e.g. `/mm-fix`,
`/mm-riper`, `/mm-quality`).

## Why the form changed

Plugin skills are _always_ colon-namespaced by Claude Code (`/plugin-name:skill`),
so a plugin can only ever produce `/claude-solo:fix` or `/mm:fix` — never a dash.
A leading-dash command requires a **standalone** skill (a `SKILL.md` directory in
`~/.claude/skills/` with no plugin manifest), whose directory name becomes the
command verbatim. v2.0 therefore installs the 48 skills as standalone
`~/.claude/skills/mm-<name>/` directories. The plugin stays (same name) but now
ships only the 5 agents and the hooks.

## TL;DR

```bash
npx github:mikkeymoo/claude-solo install     # or: cd claude-solo && git pull && bash install.sh
# restart your Claude Code session
```

The installer does the whole migration idempotently:

1. **Installs standalone `/mm-*` skills** into `~/.claude/skills/mm-<name>/`.
2. **Drops the old colon commands** — the plugin no longer serves skills, so
   `/claude-solo:*` simply stops existing after the plugin reloads.
3. **Removes legacy un-prefixed skill copies** (`~/.claude/skills/<name>/` left by
   ≤0.8.x installs), each backed up to `~/.claude/.claude-solo-backup/<timestamp>/` first.
4. **Re-points a stale plugin link** so the agents + hooks load from the new code.

## Command map (old → new)

| Old (v1.x)                | New (v2.0)       |
| ------------------------- | ---------------- |
| `/claude-solo:brief`      | `/mm-brief`      |
| `/claude-solo:riper`      | `/mm-riper`      |
| `/claude-solo:fix`        | `/mm-fix`        |
| `/claude-solo:quality`    | `/mm-quality`    |
| `/claude-solo:ship`       | `/mm-ship`       |
| `/claude-solo:<anything>` | `/mm-<anything>` |

Every skill follows the same rule: replace the `claude-solo:` namespace with the
`mm-` prefix. The full skill list is in the README.

## Aliases — not provided (by design)

Claude Code has **no alias mechanism** for skills/commands: a skill answers to
exactly one name (its directory). Shipping 48 old-name stub skills purely to
forward to the new ones would double the skill listing and its token budget, so
v2.0 does **not** keep `/claude-solo:*` aliases. The old colon commands stop
resolving after you re-run the installer — update saved prompts and muscle memory
to the `/mm-*` form.

## Verify after migrating

```bash
ls ~/.claude/skills | grep '^mm-' | wc -l   # 48 standalone skills
claude plugin list                           # claude-solo@skills-dir … loaded (agents + hooks)
bash install.sh --dry-run                    # smoke checks all green
```

In a fresh session, `/mm-hud` should render and `/agents` should still list the
five agents (`code-reviewer`, `researcher`, `refactor-agent`, `db-reader`,
`deploy-guard`).

## Rollback

```bash
npx github:mikkeymoo/claude-solo#pre-mm-rename install
```

That re-installs the pre-rename (v1.0, colon-command) layout from the
`pre-mm-rename` tag. Backups are also kept at
`~/.claude/.claude-solo-backup/<timestamp>/` (last 5 retained).

---

### Earlier migration (≤0.8.x bare-file → v1.0 plugin)

v1.0 converted claude-solo from copied files into a plugin (agents + hooks load
from the cloned repo; the installer de-wires legacy `settings.json` hook entries
and removes `ult-*` agent copies). If you are coming straight from a ≤0.8.x
install, the v2.0 installer performs that migration too in the same run. See the
v1.0.0 entry in `CHANGELOG.md` for the detail.
