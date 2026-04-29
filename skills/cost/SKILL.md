---
name: cost
description: "Analyze Claude Code token usage and cost from local JSONL logs. Shows today/week/month breakdowns, per-project and per-model stats. Use when checking spend or optimizing token usage."
---

# /cost — Cost Analysis

Parse `~/.claude/projects/**/*.jsonl` and produce a cost report.

## Helper script

Run `python ~/.claude/skills/cost/cost_report.py` to generate the report. Flags: `--today`, `--week`, `--month`, `--trend`, `--by-project`, `--by-model`, `--top-sessions N`. No flag = full report (all time).

## Report structure

### 1. Time buckets (Today / This Week / This Month)

| Metric            | Value     |
| ----------------- | --------- |
| Cache reads       | Xk tokens |
| Cache writes (5m) | Xk tokens |
| Cache writes (1h) | Xk tokens |
| Direct input      | Xk tokens |
| Output            | Xk tokens |
| Cache hit ratio   | XX%       |
| Estimated cost    | $X.XX     |

Rates (Sonnet 4.6): Cache read $0.30/1M, Cache write $3.75/1M, Input $3.00/1M, Output $15.00/1M.

### 2. Per-project breakdown

Group by `cwd` field. Top 10 by cost.

### 3. Per-model breakdown

Group by `model` field.

### 4. Top 5 most expensive sessions

Sort by cost descending.

### 5. Optimization suggestions

- Low cache hit → longer sessions
- High output ratio → shorter responses
- High daily spend → review top sessions

## Trend mode (--trend)

Compare current week vs. previous week:

```
Week-over-Week Comparison
  This week:  123.4k tokens  $4.56
  Last week:  107.2k tokens  $3.89
  Change:     +15.1% tokens  +17.2% cost

Last 7 days (tokens):
  Mon  ███████                  32.1k
  Tue  ████████████             56.3k
  Wed  ██████                   28.5k
  Thu  ████████████████         71.2k
  Fri  ██████████               48.3k
  Sat  ████                     18.9k
  Sun  ███                      15.6k

Model breakdown (this week):
  claude-sonnet-4-6            89.2k  $3.24
  claude-haiku-4-5             34.2k  $1.32
```
