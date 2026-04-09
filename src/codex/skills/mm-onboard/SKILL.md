---
name: mm-onboard
description: "Generate a new contributor onboarding guide for this project: setup steps, architecture overview, development workflow, and where to find things."
---

# mm-onboard

Generate a new contributor onboarding guide for this project: setup steps, architecture overview, development workflow, and where to find things.

## Instructions
Generate a contributor onboarding guide for this project.

Run:
```bash
rtk git log --oneline -10
rtk ls .
cat README.md 2>/dev/null | head -100 || true
cat package.json 2>/dev/null || cat pyproject.toml 2>/dev/null || true
cat .env.example 2>/dev/null || true
ls .github/ 2>/dev/null || true
```

Produce a guide covering:

**1. Prerequisites**
- Required tools and versions (Node, Python, Docker, etc.)
- Required accounts or access (cloud provider, API keys, etc.)

**2. Local setup** (step by step)
```bash
git clone <repo>
cd <project>
<install deps>
cp .env.example .env
<fill in required env vars>
<run migrations if needed>
<start dev server>
```

**3. Project structure** (brief — link to `/mm:map` for full map)
- Where is the entry point?
- Where do new features go?
- Where are the tests?

**4. Development workflow**
- How to run tests: `rtk <test command>`
- How to run linting: `rtk <lint command>`
- Branch naming convention
- PR process (if `.github/PULL_REQUEST_TEMPLATE.md` exists, reference it)
- Commit message convention

**5. Architecture in 5 bullets**
- What is this app? What does it do?
- How is it structured? (layered? modular? monolith?)
- What are the key dependencies and why?
- Where is the data stored?
- What external services does it use?

**6. Where to find things**
| I want to... | Look here |
|---|---|
| Add an API endpoint | `src/routes/` |
| Change the DB schema | `prisma/schema.prisma` or `migrations/` |
| Add a test | `tests/` or co-located `*.test.ts` |
| Change config | `.env` + `src/config/` |

**7. Common pitfalls**
- Things that trip up new contributors
- Non-obvious behavior or constraints
- "If you see X error, do Y"

Save to `docs/ONBOARDING.md` and print a summary.
