Structured effort estimate with confidence intervals and risk flags.

Read `.planning/PLAN.md` or `.planning/BRIEF.md` (whichever exists). If neither, ask what we're estimating.

Produce a structured estimate:

### Task breakdown
For each task, estimate:
- Optimistic (everything works first try)
- Realistic (one unexpected thing)
- Pessimistic (two things go wrong)

### Confidence factors
Rate each (Low/Medium/High confidence):
- [ ] Have I done this exact thing before?
- [ ] Are the requirements clear and stable?
- [ ] Are dependencies (APIs, libraries) well understood?
- [ ] Is the codebase familiar?
- [ ] Is there existing test coverage to catch regressions?

### Risk flags
List specific risks that could blow the estimate:
- `⚠️ [risk] → could add [X] hours`

### Final estimate
```
Optimistic:   X hours
Realistic:    Y hours  ← plan for this
Pessimistic:  Z hours

Confidence: Low / Medium / High
```

### What would make me more confident
One or two things that would reduce estimate uncertainty (e.g., "spike the API integration for 30 min first").

Rules:
- Never give a single number without a range
- Never estimate without listing assumptions
- If realistic > 8 hours, recommend breaking into smaller pieces
- If confidence is Low, say so clearly — don't false-precision it
