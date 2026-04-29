---
name: mm:cost
description: Analyze Claude Code token usage and cost from local JSONL logs. Shows today/week/month breakdowns, per-project and per-model stats, and top expensive sessions.
---

# /mm:cost — Cost Analysis

Parse `~/.claude/projects/**/*.jsonl` and produce a rich cost report.

## Report structure

### 1. Time buckets

Show three tabs: **Today**, **This Week**, **This Month**

For each bucket emit a markdown table:

| Metric            | Value     |
| ----------------- | --------- |
| Cache reads       | Xk tokens |
| Cache writes (5m) | Xk tokens |
| Cache writes (1h) | Xk tokens |
| Direct input      | Xk tokens |
| Output            | Xk tokens |
| Cache hit ratio   | XX%       |
| Estimated cost    | $X.XX     |

Use these Sonnet 4.6 rates (flag if stale after next CC release):

- Cache read: $0.30/1M
- Cache write (5m or 1h): $3.75/1M
- Input: $3.00/1M
- Output: $15.00/1M

### 2. Per-project breakdown

Group entries by the `cwd` field in the JSONL. Show top 10 projects by cost:

| Project | Tokens (in) | Tokens (out) | Cache hit% | Est. cost |
| ------- | ----------- | ------------ | ---------- | --------- |

### 3. Per-model breakdown

Group by `model` field. Show which model is consuming most.

### 4. Top 5 most expensive sessions

| Timestamp | Project | Model | Tokens | Est. cost |
| --------- | ------- | ----- | ------ | --------- |

Sort by estimated cost descending.

### 5. Optimization suggestions

Analyze patterns and suggest improvements:

- If any project has cache hit ratio < 50%: "Project X has low cache hit ratio — consider keeping sessions longer or using /pre-compact-checkpoint more aggressively"
- If cache_write_5m >> cache_write_1h: "Most cache writes are 5m TTL — if you're on CC v2.1.81+ without cache-fix-wrapper, you're paying 4-20x more than necessary. See ~/.claude/COST-OPTIMIZATION.md"
- If output tokens > 30% of total: "High output token ratio — consider asking for shorter responses when exploring"
- If total today > $5: "High spend today — review top sessions above"

## Implementation notes

- Use `jq -s` to aggregate all JSONL files in one pass per time range
- JSONL entries have shape: `{"timestamp":"...", "model":"...", "cwd":"...", "usage":{...}}`
- usage fields: `input_tokens`, `output_tokens`, `cache_read_input_tokens`, `cache_creation_input_tokens`, `cache_creation.ephemeral_5m_input_tokens`, `cache_creation.ephemeral_1h_input_tokens`
- If JSONL files not found at `~/.claude/projects/`, note it and suggest running a session first
- If `bc` not available, estimate costs using integer arithmetic only
