---
name: mm:search
description: "Research and analysis suite — deep multi-source research, deep code explanation, or structured effort estimate."
argument-hint: "[question | --explain <file/function> | --estimate]"
---

Research and analysis. Detect intent from argument.

- A question or topic → deep multi-source research with synthesis
- `--explain <file/function/concept>` → deep code explanation
- `--estimate` → structured effort estimate with confidence intervals

---

## Default — Deep Research

Multi-source research with synthesis. Use before building something unfamiliar.

Process:
1. **Decompose** — break the question into 3-5 sub-questions that must be answered
2. **Search** — for each sub-question, check at least 2-3 sources:
   - Official docs (Context7 MCP if available)
   - Recent blog posts or changelog entries (web search)
   - GitHub issues or PRs for real-world edge cases
3. **Synthesize** — combine findings, resolve contradictions, identify gaps
4. **Validate** — is this current? Does it apply to our stack?
5. **Deliver**:

```
## Research: [question]
Date: [today]

### Answer
[1-3 paragraph summary]

### Key decisions / trade-offs
- Option A: [pros/cons]
- Option B: [pros/cons]
→ Recommendation: [which and why]

### Gotchas & edge cases
- [specific thing that will bite you]

### Sources
- [title] — [url] (accessed [date])
```

Rules: cite every factual claim, flag anything older than 12 months as "may be outdated", show contradicting sources side-by-side. End with: "Ready to /plan?" if research is for an upcoming build.

---

## --explain — Deep Code Explanation

Deep code explanation — traces data flow, explains decisions, answers "why" not just "what".

Structure:
1. **What it does** — one sentence. Observable behavior.
2. **Why it exists** — what problem does this solve? What would break without it?
3. **How it works** — walk through the logic step by step: data in → transforms → data out. Explain each non-obvious line. Call out: patterns used, performance trade-offs, known limitations.
4. **Key dependencies** — what does this rely on? What relies on it?
5. **Edge cases handled** — special inputs or states accounted for.
6. **What to watch out for** — gotchas, things that have caused bugs, things that break under load or on different platforms.

Format: prose paragraphs, not bullet lists. Explain like a senior dev would to someone who needs to maintain it. Don't explain what is obvious from the code — focus on intent and non-obvious reasoning.

Depth: function → 150-300 words | file/module → 400-600 words | system/architecture → 600-1000 words + ASCII diagram

---

## --estimate — Effort Estimate

Structured effort estimate with confidence intervals and risk flags.

Read `.planning/PLAN.md` or `.planning/BRIEF.md`. If neither exists, ask what we're estimating.

**Task breakdown** — for each task:
- Optimistic (everything works first try)
- Realistic (one unexpected thing)
- Pessimistic (two things go wrong)

**Confidence factors** (Low/Medium/High):
- Have I done this exact thing before?
- Are requirements clear and stable?
- Are dependencies (APIs, libraries) well understood?
- Is the codebase familiar?
- Is there existing test coverage to catch regressions?

**Risk flags** — specific risks that could blow the estimate:
`⚠️ [risk] → could add [X] hours`

**Final estimate**:
```
Optimistic:   X hours
Realistic:    Y hours  ← plan for this
Pessimistic:  Z hours

Confidence: Low / Medium / High
```

Rules: never give a single number without a range, never estimate without listing assumptions, if realistic > 8 hours recommend breaking into smaller pieces, if confidence is Low say so clearly.
