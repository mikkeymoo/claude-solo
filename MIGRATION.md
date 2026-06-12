# Migrating from ≤0.8.x (bare-file install) to v1.0 (plugin)

v1.0 converts claude-solo from copied files into a Claude Code plugin. Skills, agents,
and hooks now load directly from the cloned repo via `~/.claude/skills/claude-solo`;
only the settings layer (deny rules, env, statusline, CLAUDE.md) is still installed
into `~/.claude/`.

## TL;DR

```bash
cd claude-solo && git pull
bash install.sh
# restart your Claude Code session
```

The installer handles the whole migration. Specifically it:

1. **Links the plugin** — junction/symlink at `~/.claude/skills/claude-solo` pointing
   at the repo, then `claude plugin enable claude-solo@skills-dir`.
2. **De-wires legacy hooks** from `~/.claude/settings.json` — every 0.8.x hook entry
   (including ones pruned in 0.8.1: `lint-fix`, `test-fix`, `large-file`,
   `gitignore-check`, `stop-gate`) is removed so nothing double-fires with the
   plugin's `hooks/hooks.json`.
3. **Removes superseded copies** (each backed up to `~/.claude/.claude-solo-backup/` first):
   - bare skill dirs in `~/.claude/skills/` that match repo skills
   - `ult-*` agent files in `~/.claude/agents/` — the plugin ships them unprefixed

## What changed for you

| ≤0.8.x | v1.0 |
| --- | --- |
| Skills copied to `~/.claude/skills/<name>/` | Served from the repo via the plugin link |
| Agents installed as `ult-code-reviewer` etc. | Plugin agents: `code-reviewer`, `researcher`, `refactor-agent`, `db-reader`, `deploy-guard` |
| Hooks wired in `~/.claude/settings.json` | Wired in the plugin's `hooks/hooks.json` (paths via `${CLAUDE_PLUGIN_ROOT}`) |
| Updates: re-run `install.sh` | Updates: `git pull` (re-run `install.sh` only when the settings template changes) |
| Morae/eDiscovery skills bundled | Split to a separate personal plugin — see "Layering personal plugins" in README |

If anything references the old agent names (saved prompts, scripts, muscle memory),
switch `ult-<name>` → `<name>`.

## Verify after migrating

```bash
claude plugin list                  # claude-solo@skills-dir … loaded
claude plugin details claude-solo   # 47 skills, 5 agents, 14 hook events
bash install.sh --dry-run           # smoke checks all green
```

In a fresh session: `/hud` should show the plugin's SessionStart hooks fired, and
`/agents` should list the five unprefixed agents.

## Rollback

Backups are kept at `~/.claude/.claude-solo-backup/<timestamp>/` (last 5 retained).
To roll back: `claude plugin disable claude-solo@skills-dir`, delete the
`~/.claude/skills/claude-solo` link, and restore files from the newest backup,
then check out the v0.8.2 tag of this repo and run `bash install.sh`.
