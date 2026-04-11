---
name: mm-pr
description: "Create a well-structured pull request with description, test plan, breaking changes, and review checklist."
---

# mm-pr

Create a well-structured pull request with description, test plan, breaking changes, and review checklist.

## Instructions
Create a well-structured pull request for the current branch.

1. **Gather context**:
```bash
rtk git log main..HEAD --oneline       # commits in this PR
rtk git diff main..HEAD --stat         # files changed
```
Also read `.planning/BRIEF.md` if it exists.

2. **Draft the PR**:

Title format: `[type]: short description` (≤72 chars)
Types: `feat` `fix` `refactor` `chore` `docs` `security`

Body:
```markdown
## What changed
- [bullet per logical change, not per commit]

## Why
[Link to issue, or 1-2 sentences on the problem this solves]

## How to test
- [ ] [specific step to verify the happy path]
- [ ] [specific step to verify error handling]
- [ ] [cross-platform check if applicable]

## Breaking changes
None / [describe what breaks and migration path]

## Security considerations
None / [any auth, data exposure, or input validation changes]

## Checklist
- [ ] Tests pass locally
- [ ] No secrets or credentials in diff
- [ ] Works on Windows and Linux
- [ ] BRIEF.md acceptance criteria met
```

3. **Create the PR**:
```bash
rtk gh pr create --title "[title]" --body "[body]" --draft
```
Create as draft first — show me the URL, then ask: "Ready to mark ready for review?"

4. **After confirmation**: remove draft status.

If there are WIP commits ("fix", "wip", "checkpoint"), ask: "Squash these into one clean commit before opening?" before creating.
