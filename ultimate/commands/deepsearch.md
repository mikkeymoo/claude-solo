---
name: mm:deepsearch
description: "Multi-source research with synthesis and citations. Use before building something unfamiliar."
argument-hint: "[research question]"
---

Multi-source research with synthesis and citations. Use when you need to understand something deeply before building it.

Usage: `/mm:deepsearch [research question]`

Process:

1. **Decompose** — break the question into 3-5 sub-questions that must be answered to fully address it
2. **Search** — for each sub-question, search at least 2-3 sources:
   - Official docs (Context7 MCP if available)
   - Recent blog posts or changelog entries (web search)
   - GitHub issues or PRs for real-world edge cases
3. **Synthesize** — combine findings, resolve contradictions, identify gaps
4. **Validate** — check: is this information current? (check dates). Does it apply to our stack?
5. **Deliver** — structured report:

```
## Research: [question]
Date: [today]

### Answer
[1-3 paragraph summary of the finding]

### Key decisions / trade-offs
- Option A: [pros/cons]
- Option B: [pros/cons]
→ Recommendation: [which and why]

### Gotchas & edge cases
- [specific thing that will bite you]

### Sources
- [title] — [url] (accessed [date])
```

Rules:
- Cite every factual claim
- Flag anything older than 12 months as "may be outdated"
- If sources contradict, show both and explain the difference
- End with: "Ready to /plan?" if the research is for an upcoming build

Scope: this is research, not implementation. Produce the report, then stop.
