---
name: brainstorm
description: "Structured brainstorming session — diverge widely, cluster, then converge on best ideas. Saves artifact to .planning/. Use when exploring solutions, generating feature ideas, designing architecture alternatives, or unsticking any creative or technical decision."
argument-hint: "[topic] [--problem | --architecture | --reverse | --feature]"
---

# /brainstorm — Structured Idea Generation

Run a disciplined brainstorm: diverge first, judge later, converge last.
Saves a timestamped artifact to `.planning/BRAINSTORM-{slug}-{date}.md`.

---

## Golden Rules (enforce throughout)

- **Diverge before converging.** No filtering, scoring, or "yes but" during the ideation phase.
- **Quantity beats quality early.** A weak idea often unlocks a great one.
- **Separate generation from evaluation.** These are different cognitive modes — don't mix them.
- **Name the constraint, then break it.** "We assumed X — what if we didn't?"
- **End with a decision.** A brainstorm that produces no ranked output is just a list.

---

## Default Mode — Open Brainstorm

Invoke: `/brainstorm [topic]`

### Step 1 — Frame (1 min)

Restate the topic as a **How Might We** question:

> "How might we [verb] [object] so that [outcome]?"

If the user gave a vague topic, sharpen it before continuing. Ask one clarifying question if needed.

### Step 2 — Diverge (generate ≥12 ideas, no filtering)

Generate ideas across these lenses — at least one idea per lens:

| Lens                   | Prompt                                                                      |
| ---------------------- | --------------------------------------------------------------------------- |
| **Obvious**            | What are the first 3 things anyone would try?                               |
| **Analogous**          | How does another domain solve this? (nature, games, manufacturing, finance) |
| **Invert**             | What would make this problem worse? (flip the answer)                       |
| **Constraint removal** | What if cost/time/team size were no object?                                 |
| **Smallest possible**  | What's the 1-hour version of a solution?                                    |
| **Wildcard**           | What's the weirdest, most unreasonable idea?                                |
| **SCAMPER**            | Substitute, Combine, Adapt, Modify, Eliminate, Reverse one element          |
| **First principles**   | Strip away assumptions — what is actually true about this problem?          |

Present all ideas as a flat numbered list. No commentary, no qualifiers, no "this won't work because".

### Step 3 — Cluster

Group the list into 3–6 named themes. Rename ideas that belong together.
Call out any idea that doesn't fit a cluster — outliers are often the most interesting.

### Step 4 — Converge (score top candidates)

Pick the 5 most interesting ideas (at least one from each cluster).
Score each on two axes, 1–5:

| Idea | Impact | Feasibility | Score (I×F) | Notes |
| ---- | ------ | ----------- | ----------- | ----- |
| ...  | ...    | ...         | ...         | ...   |

Sort by Score descending. Flag the top 3 as **Candidates**.

### Step 5 — Next steps

For each Candidate, one-line next action:

- **Candidate 1:** [spike / prototype / research / just do it]
- **Candidate 2:** ...
- **Candidate 3:** ...

### Step 6 — Save artifact

Write `.planning/BRAINSTORM-{slug}-{YYYY-MM-DD}.md` with the full output (frame, ideas, clusters, scored table, next steps). Confirm with: "Saved to `.planning/BRAINSTORM-{slug}-{date}.md`. Top pick: [Candidate 1]."

---

## --problem Mode — Problem Framing First

Invoke: `/brainstorm --problem [problem description]`

Use when the problem itself is fuzzy before jumping to solutions.

### Step 1 — Diagnosis (before any solutions)

Ask 5-Why style: restate the problem, then ask "why does this happen?" recursively until you hit a root cause or a hidden assumption. Surface at least 2 candidate root causes.

### Step 2 — Reframe

Write 3 alternative problem statements:

1. The **narrow** version (smallest scope)
2. The **broad** version (systemic, upstream)
3. The **inverted** version (what if this isn't a problem at all?)

Ask the user which framing feels most accurate. If they're sure, proceed with that frame.

### Step 3 — Ideate

Run Steps 2–6 from Default Mode using the chosen problem frame.

---

## --architecture Mode — System Design Alternatives

Invoke: `/brainstorm --architecture [system or component name]`

Use when designing a new component, evaluating a rewrite, or picking between architectural approaches.

### Step 1 — Constraints inventory

List all hard constraints (must-haves) vs. soft constraints (nice-to-haves):

- Latency / throughput requirements
- Team familiarity (languages, frameworks)
- Deployment environment
- Integration points (APIs, DBs, queues)
- Migration cost from current state

### Step 2 — Generate ≥5 architectural approaches

For each approach, write a 2-line sketch:

- What it looks like (key components, data flow)
- What it trades off (what gets easier vs. harder)

Approaches should span the spectrum from simplest-possible to most-robust.

### Step 3 — Tradeoff matrix

| Approach | Simplicity | Scalability | Operability | Migration cost     | Fit to constraints |
| -------- | ---------- | ----------- | ----------- | ------------------ | ------------------ |
| ...      | 1–5        | 1–5         | 1–5         | 1–5 (lower=better) | 1–5                |

Sort by total score. Flag the winner and explain in 2 sentences why it wins.

### Step 4 — Risks on the winner

List the top 3 risks for the winning approach and one mitigation per risk.

### Step 5 — Save artifact

Write `.planning/BRAINSTORM-arch-{slug}-{date}.md` with the full analysis.

---

## --reverse Mode — Reverse Brainstorming

Invoke: `/brainstorm --reverse [goal]`

Use when stuck or when conventional thinking keeps producing the same answers.

### Step 1 — Invert the goal

Restate the goal as its opposite:

> Goal: "Make onboarding fast" → Inverted: "How might we make onboarding as slow and painful as possible?"

### Step 2 — Generate ≥10 ways to achieve the inverted goal

No filtering. The worse the idea (for the inverted goal), the better.

### Step 3 — Flip each idea

For each anti-solution, derive its positive counterpart:

> "Require 12 form fields" → "Reduce to 3 required fields, defer the rest"

### Step 4 — Filter and score

Run the flipped ideas through the Default Mode convergence table (Steps 4–6).

---

## --feature Mode — Feature Ideation in a Codebase

Invoke: `/brainstorm --feature [area of the codebase or product]`

Use when generating feature ideas grounded in what the codebase already does.

### Step 1 — Anchor in the current state

Read the relevant part of the codebase (entry point, key module, README). Summarize in 3 bullets:

- What it does today
- What its users complain about (infer from TODOs, issue comments, error handling)
- What it's close to doing but doesn't yet

### Step 2 — Generate ideas across three horizons

| Horizon          | Scope                         | Examples                                             |
| ---------------- | ----------------------------- | ---------------------------------------------------- |
| **H1 — Polish**  | Improve what exists           | faster, fewer clicks, better errors                  |
| **H2 — Extend**  | Adjacent capability           | new format, new integration, new user type           |
| **H3 — Rethink** | Fundamentally different model | different data model, different interaction paradigm |

Generate ≥4 ideas per horizon.

### Step 3 — Feasibility filter

Cross each idea against: estimated effort (S/M/L/XL) and whether it requires a breaking change. Eliminate XL + breaking unless the impact is exceptional.

### Step 4 — Converge and save

Run Default Mode Steps 4–6 on the surviving ideas. Save to `.planning/BRAINSTORM-feature-{slug}-{date}.md`.

---

## Artifact Format

All modes write a markdown file with this structure:

```markdown
# Brainstorm: {Topic}

**Date:** {YYYY-MM-DD}  
**Mode:** {default | problem | architecture | reverse | feature}  
**HMW Frame:** {How Might We question}

## Ideas (raw)

1. ...
2. ...

## Clusters

### {Cluster Name}

- idea N, idea N...

## Scored Candidates

| Idea | Impact | Feasibility | Score | Notes |
| ---- | ------ | ----------- | ----- | ----- |

## Top Pick: {Candidate 1}

{2-sentence rationale}

## Next Steps

- **{Candidate 1}:** {action}
- **{Candidate 2}:** {action}
- **{Candidate 3}:** {action}
```

---

## When to stop brainstorming

Stop and commit to an approach when:

- The top-scored candidate has clear next actions
- The team (or solo developer) can articulate _why_ it beats the alternatives
- Continuing generates variations on already-covered ground

If none of those are true after two full passes, the problem frame is probably wrong — switch to `--problem` mode.
