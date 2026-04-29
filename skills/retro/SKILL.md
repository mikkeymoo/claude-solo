---
name: retro
description: "Sprint retrospective — what shipped, what worked, what to fix, and priorities for next sprint. Use at the end of a sprint or feature."
---

# /retro — Sprint Retrospective

Write `.planning/RETRO-[date].md` with:

1. **What shipped** — one-line list of everything delivered
2. **Estimate vs actual** — planned hours vs what it actually took
3. **What went well** — 2-3 specific things (not generic)
4. **What slowed us down** — blockers, rework, unclear scope
5. **What to do differently** — one concrete change for next sprint
6. **Next priorities** — top 3 things to tackle next (ordered)

Keep it under 200 words. No fluff. If it took twice as long as expected, say why.

End with: "Retro saved. What's next?"

## Bundled Script

Run `python skills/retro/git_stats.py` to generate sprint statistics.

Flags:

- `--days N` — last N days (default: 7)
- `--since YYYY-MM-DD` — since specific date
- `--since-tag v1.0` — since a git tag
- `--churn` — show file churn hotspots
- `--authors` — per-author breakdown

Reports: commits by type (feat/fix/chore), commits by day with ASCII bars,
file churn hotspots, most-changed files by lines, features shipped, bugs fixed,
and velocity (commits/day, lines/day).

Run this script first to populate the "What shipped" and "Estimate vs actual" sections.
