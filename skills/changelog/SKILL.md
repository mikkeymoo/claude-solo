---
name: changelog
description: "Generate changelog from conventional commits. Modes: --preview (stdout), --write (update CHANGELOG.md), --since <tag> (specific start). Follows Keep a Changelog format."
argument-hint: "[--preview|--write|--since <tag>]"
---

# /changelog — Generate Changelog from Commits

Parse conventional commits since the last tag and generate a markdown changelog.

## Modes

### `--preview` (default)

Output formatted changelog section to stdout only. Does not modify files.

```bash
python ~/.claude/skills/changelog/changelog_gen.py --preview
```

### `--write`

Update `CHANGELOG.md` with the unreleased section. Moves unreleased commits into a new version section (prompts for version if ambiguous).

```bash
python ~/.claude/skills/changelog/changelog_gen.py --write
```

### `--since <tag>`

Generate changelog starting from a specific tag instead of auto-detecting the last tag.

```bash
python ~/.claude/skills/changelog/changelog_gen.py --since v0.5.0
```

## Format

Output follows **Keep a Changelog** (https://keepachangelog.com) format:

```markdown
## [Unreleased]

### Added

- feat: description

### Changed

- refactor: description

### Fixed

- fix: description

### Security

- security: description

### Removed

- removed items

### Chore

- chore: maintenance items (collapsed section)
```

## Commit Type Mapping

Conventional commits are grouped by type:

| Type                           | Section       | Included        |
| ------------------------------ | ------------- | --------------- |
| `feat`                         | Added         | Yes             |
| `fix`                          | Fixed         | Yes             |
| `refactor`, `style`, `perf`    | Changed       | Yes             |
| `docs`                         | Documentation | Yes             |
| `security`                     | Security      | Yes             |
| `chore`, `test`, `build`, `ci` | Chore         | Yes (collapsed) |

## Parsing

Commits are parsed as `type(scope): description`:

- `type` determines the section
- `scope` is optional
- Multi-line body text is included as indented detail

## Helper script

Run the bundled script directly for advanced options:

```bash
python ~/.claude/skills/changelog/changelog_gen.py [--preview|--write] [--since TAG] [--format markdown|json] [--unreleased-only]
```

Flags:

- `--preview` — output to stdout only (default)
- `--write` — update CHANGELOG.md
- `--since TAG` — start from specific tag instead of last tag
- `--format markdown|json` — output format (default: markdown)
- `--unreleased-only` — show only unreleased commits
