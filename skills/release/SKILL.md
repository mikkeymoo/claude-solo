---
name: release
description: "Cut a release: version bump, changelog update, git tag, and push. Use when ready to tag and ship a version."
argument-hint: "[patch|minor|major] or explicit version"
---

# /release — Cut a Release

1. **Check state** — all tests pass? Nothing uncommitted? CI green?
2. **Version** — bump in `package.json` / `Cargo.toml` / `pyproject.toml` per semver:
   - `patch` — bug fixes only
   - `minor` — new features, backwards-compatible
   - `major` — breaking changes
3. **Changelog** — move `[Unreleased]` items under new version with today's date
4. **Commit** — `chore(release): v<version>`
5. **Tag** — `git tag v<version>`
6. **Push** — `git push && git push --tags`

Don't publish packages — that's a human step.

## Helper script

Run `python ~/.claude/skills/release/release_bump.py [patch|minor|major|X.Y.Z]` for steps 2-3.
Flags: `--current` (print version only), `--dry-run` (preview). Supports `package.json`, `Cargo.toml`, `pyproject.toml`, `VERSION`.
