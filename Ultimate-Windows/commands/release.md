---
name: mm:release
description: "Cut a release: version bump, changelog update, git tag, and push."
argument-hint: "[patch|minor|major] or explicit version"
---

Cut a release.

1. **Check state** — all tests pass? Nothing uncommitted? CI green?
2. **Version** — bump version in `package.json` / `Cargo.toml` / `pyproject.toml` etc. per semver:
   - `patch` — bug fixes only
   - `minor` — new features, backwards-compatible
   - `major` — breaking changes
3. **Changelog** — update `CHANGELOG.md`: move `[Unreleased]` items under the new version with today's date
4. **Commit** — `chore(release): v<version>`
5. **Tag** — `git tag v<version>`
6. **Push** — `git push && git push --tags`

Don't publish packages — that's a human step. Just cut the tag and let CI/CD handle the rest.
