---
name: mm-changelog
description: "Generate CHANGELOG entries from git history since last release tag. Groups by type: features, fixes, breaking changes."
---

# mm-changelog

Generate CHANGELOG entries from git history since last release tag. Groups by type: features, fixes, breaking changes.

## Instructions
Generate a CHANGELOG entry from git history since the last release tag.

1. **Find the last tag**:
```bash
rtk git describe --tags --abbrev=0 2>/dev/null || echo "No tags found"
rtk git log [last-tag]..HEAD --oneline --no-merges
```
If no tags: use all commits, ask what version this will be.

2. **Categorize commits** by conventional commit prefix:
- `feat:` → Added
- `fix:` → Fixed
- `security:` → Security
- `refactor:` → Changed
- `chore:` / `docs:` → skip (or lump into Internal)
- Breaking changes (with `!` or `BREAKING CHANGE:`) → separate section at top

3. **Write the entry** in Keep a Changelog format:

```markdown
## [x.y.z] - YYYY-MM-DD

### Breaking Changes
- [only if any — migration instructions]

### Added
- [user-facing feature descriptions, not commit messages verbatim]

### Fixed
- [bug descriptions — what was wrong, not just "fixed X"]

### Security
- [any security fixes]

### Changed
- [behavior changes that aren't new features]
```

Rules:
- Rewrite commit messages into user-facing language ("Add export to CSV" not "feat: add csv export handler")
- Group related commits into one entry
- Skip: merge commits, WIP commits, version bumps, typo fixes

4. **Prepend** to `CHANGELOG.md` (create it if missing, using keepachangelog.com format).

5. **Ask**: "Tag this release as vX.Y.Z?" — if yes:
```bash
rtk git tag -a vX.Y.Z -m "Release vX.Y.Z"
rtk git push origin vX.Y.Z
```
