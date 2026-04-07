---
name: mm-release
description: "Structured release workflow: version bump, changelog, release notes, tag, rollout checklist, and rollback documentation."
---

# mm-release

Structured release workflow: version bump, changelog, release notes, tag, rollout checklist, and rollback documentation.

## Instructions
Structured release workflow. Takes you from "code is done" to "version is shipped and documented."

**1. Pre-flight**
- Run `/mm:verify` checks (or confirm they passed recently)
- If verification hasn't passed, stop: "Run /mm:verify first."

**2. Version bump**
- Detect the versioning file: package.json, pyproject.toml, Cargo.toml, AssemblyInfo, etc.
- Read current version
- Ask: patch (bug fixes), minor (new features), or major (breaking changes)?
- Bump the version in all relevant files

**3. Changelog**
- Generate changelog entries from commits since last tag
- Group by type: Features, Bug Fixes, Breaking Changes, Other
- Write to CHANGELOG.md (prepend, don't overwrite)
- Format: Keep a Changelog style (keepachangelog.com)

**4. Release notes**
- Write human-readable release notes (not just commit list)
- What's new, what's fixed, what changed, migration steps if breaking
- Save to `.planning/RELEASE-NOTES.md`

**5. Tag and commit**
```bash
rtk git add -A && rtk git commit -m "chore: release vX.Y.Z"
rtk git tag -a vX.Y.Z -m "Release vX.Y.Z"
```

**6. Rollout checklist**
Generate and display:
- [ ] CI/CD pipeline passes on the release commit
- [ ] Deployed to staging/preview (if applicable)
- [ ] Smoke test on staging passes
- [ ] Deployed to production (if applicable)
- [ ] Monitoring checked — no new errors in first 15 minutes
- [ ] Release notes shared with stakeholders

**7. Rollback notes**
Document how to roll back if something goes wrong:
- Previous version tag
- Revert command
- Any data migrations that need reversing

End with: "Release vX.Y.Z prepared. Push when ready: `rtk git push && rtk git push --tags`"
