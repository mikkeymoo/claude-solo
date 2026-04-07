---
name: mm-tdd
description: "Claude-solo command skill"
---

# mm-tdd

Claude-solo command skill

## Instructions
---
name: mm:tdd
description: "Strict Test-Driven Development mode. No production code before a failing test. Red → green → refactor cycle."
---

Strict Test-Driven Development mode. No production code before a failing test.

Activate for the current task or read `.planning/PLAN.md` for the next task.

The cycle — repeat for every unit of work:

1. **RED** — write a test that fails for the right reason
   - Run it: confirm it fails with a clear, specific failure message
   - If it passes immediately, the test is wrong — rewrite it
2. **GREEN** — write the minimum code to make the test pass
   - No extra logic, no "while I'm here" additions
   - Run it: confirm it passes
3. **REFACTOR** — clean up without changing behavior
   - Run tests again: still green
   - Only then move to the next cycle

Rules:
- One test per cycle — don't write 5 tests then implement
- If you can't write a failing test, the requirement is too vague — clarify first
- Mocks only for: external APIs, databases in unit tests, system clock
- Test file lives next to the code it tests (or in `tests/` mirroring src structure)
- Naming: `test_[what]_[condition]_[expected]`

For each RED-GREEN-REFACTOR cycle, report:
```
🔴 Test: test_name — FAILING (reason)
🟢 Test: test_name — PASSING
♻️  Refactored: [what changed]
```

At the end of all cycles: run full test suite, report total pass/fail.

Do NOT write implementation code speculatively. If you're unsure what to test next, ask.
