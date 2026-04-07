---
name: mm-docsync
description: "Claude-solo command skill"
---

# mm-docsync

Claude-solo command skill

## Instructions
---
name: mm:docsync
description: "Synchronize documentation with current code state. Detects and fixes drift in README, CLAUDE.md, API docs, env files, and code comments."
---

Synchronize documentation with the current state of the code.

Run this after significant code changes to catch doc/code drift before it compounds.

**1. Scan for drift**
Check each documentation source against the codebase:

- **README.md** — do setup steps still work? Are listed features accurate?
- **CLAUDE.md** — do referenced commands, paths, and patterns still exist?
- **API docs** — do endpoint signatures match the code? Are examples valid?
- **Setup docs** — do install instructions match current dependencies?
- **.env.example** — does it list all required env vars used in code?
- **Code comments** — any @deprecated, TODO, or FIXME that reference completed work?

**2. Fix drift**
For each piece of drift found:
- Update the documentation to match the code (not the other way around)
- If the change is intentional: update the doc
- If the change looks accidental: flag it for review

**3. Consistency checks**
- All CLI commands in docs: do they actually work if copy-pasted?
- Version numbers in docs match package.json / pyproject.toml / etc.
- Links in docs: do they point to real files/URLs?
- Screenshots or examples: are they reasonably current?

**4. Report**
```
Documentation sync:
  ✅ README.md — up to date
  🔧 CLAUDE.md — updated 2 stale path references
  ⚠️  .env.example — missing DATABASE_URL
  ✅ API docs — endpoints match code
  🔧 Code comments — removed 3 resolved TODOs
```

Commit all doc updates:
```bash
rtk git add -A && rtk git commit -m "docs: sync documentation with current codebase"
```

End with: "Docs synced. [N] files updated, [M] issues found."
