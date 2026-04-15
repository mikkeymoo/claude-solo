---
name: mm-release
description: "Full release workflow: changelog from git history, version bump, release notes, PR creation, tag, rollout checklist, and rollback docs."
---

# mm-release

Full release workflow: changelog from git history, version bump, release notes, PR creation, tag, rollout checklist, and rollback docs.

## Instructions
Full release workflow — takes you from "code is done" to "version is shipped and documented."

**1. Pre-flight**
Run `/mm:verify` or confirm it passed recently. If not: "Run /mm:verify first."

**2. Changelog from git history**

Find last tag and categorize commits:
```bash
rtk git describe --tags --abbrev=0 2>/dev/null || echo "No tags found"
rtk git log [last-tag]..HEAD --oneline --no-merges
```

Categorize: `feat:` → Added | `fix:` → Fixed | `security:` → Security | `refactor:` → Changed | breaking changes (`!`) → top section. Skip: chore/docs/WIP commits.

Write entry in Keep a Changelog format. Rewrite commit messages into user-facing language. Prepend to `CHANGELOG.md`.

**3. Version bump**

Detect versioning file (package.json, pyproject.toml, Cargo.toml, etc.).
Ask: patch (bug fixes), minor (new features), or major (breaking changes)?
Bump version in all relevant files.

**4. Release notes**

Write human-readable notes: what's new, what's fixed, migration steps if breaking.
Save to `.planning/RELEASE-NOTES.md`.

**5. Create PR**

```bash
rtk git log main..HEAD --oneline && rtk git diff main..HEAD --stat
```

Draft PR — title: `chore: release vX.Y.Z`, body: what changed, how to test, breaking changes, security notes, checklist.
```bash
rtk gh pr create --title "chore: release vX.Y.Z" --body "[body]" --draft
```
Show PR URL. Ask: "Ready to mark ready for review?"

**6. Tag and commit**
```bash
rtk git add -A && rtk git commit -m "chore: release vX.Y.Z"
rtk git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

**7. Rollout checklist**
- [ ] CI/CD pipeline passes on release commit
- [ ] Deployed to staging/preview (if applicable)
- [ ] Smoke test on staging passes
- [ ] Deployed to production (if applicable)
- [ ] Monitoring checked — no new errors in first 15 minutes
- [ ] Release notes shared with stakeholders

**8. Rollback notes**
Document: previous version tag, revert command, data migrations needing reversal.

End with: "Release vX.Y.Z prepared. Push when ready: `rtk git push && rtk git push --tags`"
