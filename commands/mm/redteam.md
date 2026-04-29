---
name: mm:redteam
description: "Adversarial code review: poke holes, find gaps, challenge assumptions, propose fixes. Not a security audit — logic, correctness, and edge-case hunting."
---

Red-team the target code. You are actively trying to **break** it, not admire it. Scope: files changed since last tag, or files in `.planning/PLAN.md`, or the path provided by the user.

This is **not** `/security` — skip OWASP checklists. Focus on correctness, logic gaps, hidden assumptions, and failure modes that ship-ready code tends to miss.

## Mindset

> "What does this code assume is true that isn't guaranteed?"

Be blunt. Generic advice is worthless. Every finding must cite `file:line` and describe a **concrete failure scenario** — an input, an order of operations, or a state that breaks it.

## Attack surface — work through every category

1. **Hidden assumptions** — what does the code treat as invariant without checking? (non-null, non-empty, sorted, deduped, within range, specific type). What happens if the assumption is wrong?

2. **Error paths** — for every `try`/`except`, `if err != nil`, `.catch()`: what state does the system land in on failure? Is anything leaked (file handles, locks, transactions, memory)? Is the user told? Is the error swallowed silently?

3. **Boundary conditions** — empty input, single element, max int, Unicode, timezone edges (DST, leap seconds), pagination-of-one, off-by-one on slicing, zero-length arrays passed to aggregations.

4. **Concurrency & ordering** — race conditions, TOCTOU, out-of-order callbacks, partial writes, retries that double-apply, idempotency assumptions, shared mutable state, async/await forgotten.

5. **Resource exhaustion** — unbounded loops, unbounded memory (loading whole file into RAM), unbounded recursion, connection leaks, no timeouts on network calls, no pagination on queries.

6. **Data integrity** — partial updates on multi-step writes, no transaction boundaries, lost updates, silent truncation (string → DB column), encoding round-trips (UTF-8 → latin-1 → UTF-8).

7. **Contract drift** — callers that assume behavior the callee no longer guarantees. API changes without version bumps. Schema changes without migrations.

8. **Dead code & lying code** — functions that claim to do X but do Y. Comments that contradict the code. Flags that are read but never set. Branches that can never execute.

9. **Observability gaps** — failures that leave no log trail, metrics that count the wrong thing, silent fallbacks that hide real problems, error IDs that don't correlate across services.

10. **Reversibility** — destructive operations without a dry-run, schema migrations without a rollback, deletes without soft-delete, deploys without a rollback plan.

## Output format

For each finding:

```
🔴 <short title>  (file.ext:123)
  Failure: <concrete scenario that breaks it — an input, sequence, or state>
  Why it ships anyway: <why tests/review missed it>
  Fix: <specific change — name the function, name the guard, name the test>
```

Severity labels:

- `🔴 CRITICAL` — will cause data loss, silent corruption, or user-visible breakage under realistic conditions
- `🟡 HIGH` — likely failure under uncommon-but-reachable input
- `🟢 MEDIUM` — degraded UX, inefficiency, or future-trap

## Ground rules

- **No speculation.** If you can't construct the failing scenario, don't list it.
- **No style notes.** This is not a linter. No "consider extracting this" or "rename for clarity".
- **No re-running `/security`.** OWASP, secrets, auth, CVEs are out of scope here.
- **Fixes must be specific.** Not "add error handling" — name the error, name the recovery, name the test that would have caught it.
- **Rank by blast radius × likelihood.** A rare-but-catastrophic bug beats a common cosmetic one.

## Close with a summary

After the findings list, end with:

1. **Top 3** — the findings to fix before anything else, with a one-line justification each.
2. **Test gaps** — which scenarios above have no test coverage today.
3. **One hypothesis** — what kind of bug this codebase is most likely to ship next, based on the patterns you saw.

Brevity wins. If there are no real findings, say so — don't pad.
