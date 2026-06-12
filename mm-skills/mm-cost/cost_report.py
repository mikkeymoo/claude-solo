#!/usr/bin/env python3
"""Parse Claude Code JSONL logs and produce a cost report.

Usage:
    python cost_report.py [--today | --week | --month | --all | --trend]
    python cost_report.py --top-sessions 5
    python cost_report.py --by-project
    python cost_report.py --by-model

Output: structured text report to stdout.
"""

import json
import sys
from collections import defaultdict
from datetime import datetime, timedelta
from pathlib import Path

# ── Rate cards (per 1M tokens) ────────────────────────────────────────────────
RATES = {
    "claude-opus-4-6": {
        "cache_read": 0.30,
        "cache_write": 3.75,
        "input": 15.00,
        "output": 75.00,
    },
    "claude-sonnet-4-6": {
        "cache_read": 0.30,
        "cache_write": 3.75,
        "input": 3.00,
        "output": 15.00,
    },
    "claude-haiku-4-5-20251001": {
        "cache_read": 0.03,
        "cache_write": 0.30,
        "input": 0.80,
        "output": 4.00,
    },
}
DEFAULT_RATES = RATES["claude-sonnet-4-6"]


def find_jsonl_files():
    """Find all Claude Code JSONL log files."""
    claude_home = Path.home() / ".claude" / "projects"
    if not claude_home.exists():
        return []
    return list(claude_home.rglob("*.jsonl"))


def parse_jsonl(files, since=None):
    """Parse JSONL files, optionally filtering by timestamp."""
    entries = []
    for f in files:
        try:
            with open(f, encoding="utf-8", errors="replace") as fh:
                for line in fh:
                    line = line.strip()
                    if not line:
                        continue
                    try:
                        obj = json.loads(line)
                    except json.JSONDecodeError:
                        continue
                    # Filter by time if requested
                    ts = obj.get("timestamp") or obj.get("ts")
                    if ts and since:
                        try:
                            entry_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
                            if entry_time < since:
                                continue
                        except (ValueError, TypeError):
                            pass
                    entries.append(obj)
        except OSError:
            continue
    return entries


def extract_usage(entries):
    """Extract token usage from log entries."""
    totals = defaultdict(int)
    by_project = defaultdict(lambda: defaultdict(int))
    by_model = defaultdict(lambda: defaultdict(int))
    sessions = defaultdict(lambda: defaultdict(int))

    for entry in entries:
        msg = entry.get("message") or {}
        usage = msg.get("usage") or entry.get("usage") or entry.get("costData") or {}
        if not usage:
            continue

        model = msg.get("model") or entry.get("model", "unknown")
        cwd = entry.get("cwd", "unknown")
        session_id = entry.get("sessionId") or entry.get("session_id", "unknown")

        cache_read = usage.get("cache_read_input_tokens", 0) or usage.get("cacheReadTokens", 0)
        cache_write = usage.get("cache_creation_input_tokens", 0) or usage.get(
            "cacheWriteTokens", 0
        )
        input_tokens = usage.get("input_tokens", 0) or usage.get("inputTokens", 0)
        output_tokens = usage.get("output_tokens", 0) or usage.get("outputTokens", 0)

        metrics = {
            "cache_read": cache_read,
            "cache_write": cache_write,
            "input": input_tokens,
            "output": output_tokens,
        }

        for k, v in metrics.items():
            totals[k] += v
            by_project[cwd][k] += v
            by_model[model][k] += v
            sessions[session_id][k] += v

    return totals, by_project, by_model, sessions


def compute_cost(metrics, model="claude-sonnet-4-6"):
    """Compute estimated cost from token metrics."""
    rates = RATES.get(model, DEFAULT_RATES)
    cost = 0.0
    for key in ("cache_read", "cache_write", "input", "output"):
        tokens = metrics.get(key, 0)
        cost += (tokens / 1_000_000) * rates[key]
    return cost


def fmt_tokens(n):
    """Format token count."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}k"
    return str(n)


def print_summary(totals, label="Summary"):
    """Print token summary table."""
    total_input = (
        totals.get("cache_read", 0) + totals.get("cache_write", 0) + totals.get("input", 0)
    )
    cache_hit = (totals.get("cache_read", 0) / total_input * 100) if total_input > 0 else 0
    cost = compute_cost(totals)

    print(f"\n── {label} ──")
    print(f"  Cache reads       {fmt_tokens(totals.get('cache_read', 0)):>8}")
    print(f"  Cache writes      {fmt_tokens(totals.get('cache_write', 0)):>8}")
    print(f"  Direct input      {fmt_tokens(totals.get('input', 0)):>8}")
    print(f"  Output            {fmt_tokens(totals.get('output', 0)):>8}")
    print(f"  Cache hit ratio   {cache_hit:>7.0f}%")
    print(f"  Estimated cost    ${cost:>7.2f}")


def print_by_group(grouped, label, top_n=10):
    """Print grouped breakdown."""
    # Sort by total tokens descending
    sorted_groups = sorted(
        grouped.items(),
        key=lambda x: sum(x[1].values()),
        reverse=True,
    )[:top_n]

    print(f"\n── {label} (top {min(top_n, len(sorted_groups))}) ──")
    for name, metrics in sorted_groups:
        short_name = Path(name).name if "/" in name or "\\" in name else name
        cost = compute_cost(metrics)
        total = sum(metrics.values())
        print(f"  {short_name:<30} {fmt_tokens(total):>8}  ${cost:.2f}")


def print_top_sessions(sessions, top_n=5):
    """Print most expensive sessions."""
    sorted_sessions = sorted(
        sessions.items(),
        key=lambda x: compute_cost(x[1]),
        reverse=True,
    )[:top_n]

    print(f"\n── Top {top_n} Sessions by Cost ──")
    for sid, metrics in sorted_sessions:
        cost = compute_cost(metrics)
        short_id = sid[:12] if len(sid) > 12 else sid
        print(f"  {short_id}  {fmt_tokens(sum(metrics.values())):>8}  ${cost:.2f}")


def print_suggestions(totals):
    """Print optimization suggestions."""
    total_input = (
        totals.get("cache_read", 0) + totals.get("cache_write", 0) + totals.get("input", 0)
    )
    cache_hit = (totals.get("cache_read", 0) / total_input * 100) if total_input > 0 else 0
    output_ratio = totals.get("output", 0) / max(total_input, 1)

    print("\n── Suggestions ──")
    if cache_hit < 50:
        print("  ⚠ Low cache hit ratio — try longer sessions, fewer restarts")
    if output_ratio > 0.5:
        print("  ⚠ High output ratio — request shorter responses")
    cost = compute_cost(totals)
    if cost > 20:
        print("  ⚠ High spend — review top sessions for waste")
    if cache_hit >= 50 and output_ratio <= 0.5 and cost <= 20:
        print("  ✓ Usage looks healthy")


def format_trend_bar(value, max_value, width=20):
    """Format a value as a bar chart using block characters."""
    if max_value == 0:
        return ""
    filled = int((value / max_value) * width)
    return "█" * filled


def extract_usage_by_date(entries):
    """Extract token usage grouped by date."""
    by_date = defaultdict(lambda: defaultdict(int))
    by_model_total = defaultdict(lambda: defaultdict(int))

    for entry in entries:
        msg = entry.get("message") or {}
        usage = msg.get("usage") or entry.get("usage") or entry.get("costData") or {}
        if not usage:
            continue

        model = msg.get("model") or entry.get("model", "unknown")
        ts = entry.get("timestamp") or entry.get("ts")
        if not ts:
            continue

        try:
            entry_time = datetime.fromisoformat(ts.replace("Z", "+00:00"))
            date_key = entry_time.date().isoformat()
        except (ValueError, TypeError, AttributeError):
            continue

        cache_read = usage.get("cache_read_input_tokens", 0) or usage.get("cacheReadTokens", 0)
        cache_write = usage.get("cache_creation_input_tokens", 0) or usage.get(
            "cacheWriteTokens", 0
        )
        input_tokens = usage.get("input_tokens", 0) or usage.get("inputTokens", 0)
        output_tokens = usage.get("output_tokens", 0) or usage.get("outputTokens", 0)

        metrics = {
            "cache_read": cache_read,
            "cache_write": cache_write,
            "input": input_tokens,
            "output": output_tokens,
        }

        for k, v in metrics.items():
            by_date[date_key][k] += v
            by_model_total[model][k] += v

    return by_date, by_model_total


def print_trend_report(files):
    """Print week-over-week trend comparison."""
    now = datetime.now().astimezone()
    this_week_start = now - timedelta(days=now.weekday())
    last_week_start = this_week_start - timedelta(days=7)

    # Parse last 14 days
    entries = parse_jsonl(files, since=last_week_start)
    if not entries:
        print("No log entries found for the past 14 days")
        return

    by_date, by_model_total = extract_usage_by_date(entries)

    # Split into weeks
    this_week_totals = defaultdict(int)
    last_week_totals = defaultdict(int)

    for date_str, metrics in by_date.items():
        date_obj = datetime.fromisoformat(date_str).date()
        if date_obj >= this_week_start.date():
            for k, v in metrics.items():
                this_week_totals[k] += v
        else:
            for k, v in metrics.items():
                last_week_totals[k] += v

    # Compute costs
    this_week_cost = compute_cost(this_week_totals)
    last_week_cost = compute_cost(last_week_totals)

    # Calculate percent change
    this_week_tokens = sum(
        [
            this_week_totals.get("cache_read", 0),
            this_week_totals.get("cache_write", 0),
            this_week_totals.get("input", 0),
            this_week_totals.get("output", 0),
        ]
    )
    last_week_tokens = sum(
        [
            last_week_totals.get("cache_read", 0),
            last_week_totals.get("cache_write", 0),
            last_week_totals.get("input", 0),
            last_week_totals.get("output", 0),
        ]
    )

    token_change = (
        ((this_week_tokens - last_week_tokens) / last_week_tokens * 100)
        if last_week_tokens > 0
        else 0
    )
    cost_change = (
        ((this_week_cost - last_week_cost) / last_week_cost * 100) if last_week_cost > 0 else 0
    )

    print("\n── Week-over-Week Comparison ──")
    print(f"  This week:  {fmt_tokens(this_week_tokens):>8}  ${this_week_cost:>7.2f}")
    print(f"  Last week:  {fmt_tokens(last_week_tokens):>8}  ${last_week_cost:>7.2f}")
    print(f"  Change:     {token_change:>+7.1f}%  tokens  {cost_change:>+7.1f}%  cost")

    # Build last 7 days bar chart
    print("\n── Last 7 Days (tokens) ──")
    days_data = []
    day_labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    for i in range(6, -1, -1):
        day = now.date() - timedelta(days=i)
        day_str = day.isoformat()
        tokens = sum(
            [
                by_date[day_str].get("cache_read", 0),
                by_date[day_str].get("cache_write", 0),
                by_date[day_str].get("input", 0),
                by_date[day_str].get("output", 0),
            ]
        )
        days_data.append((day_labels[i], tokens))

    max_day_tokens = max([v for _, v in days_data]) if days_data else 1
    for label, tokens in days_data:
        bar = format_trend_bar(tokens, max_day_tokens, width=20)
        print(f"  {label}  {bar:<20}  {fmt_tokens(tokens):>8}")

    # Model breakdown
    print("\n── Model Breakdown (this week) ──")
    sorted_models = sorted(
        by_model_total.items(),
        key=lambda x: sum(x[1].values()),
        reverse=True,
    )
    for model, metrics in sorted_models:
        cost = compute_cost(metrics)
        total = sum(metrics.values())
        short_model = model.split("-")[2] if "-" in model else model
        print(f"  {short_model:<30} {fmt_tokens(total):>8}  ${cost:.2f}")


def main():
    args = sys.argv[1:]
    now = datetime.now().astimezone()

    # Handle --trend flag first (separate from time windows)
    if "--trend" in args:
        files = find_jsonl_files()
        if not files:
            print("No JSONL log files found in ~/.claude/projects/")
            sys.exit(1)
        print("Cost Report — Trend Analysis")
        print_trend_report(files)
        return

    # Determine time window
    since = None
    label = "All Time"
    if "--today" in args:
        since = now.replace(hour=0, minute=0, second=0, microsecond=0)
        label = "Today"
    elif "--week" in args:
        since = now - timedelta(days=7)
        label = "This Week"
    elif "--month" in args:
        since = now - timedelta(days=30)
        label = "This Month"

    files = find_jsonl_files()
    if not files:
        print("No JSONL log files found in ~/.claude/projects/")
        sys.exit(1)

    entries = parse_jsonl(files, since=since)
    if not entries:
        print(f"No log entries found for period: {label}")
        sys.exit(0)

    totals, by_project, by_model, sessions = extract_usage(entries)

    print(f"Cost Report — {label} ({len(entries)} entries from {len(files)} files)")

    if "--by-project" in args:
        print_by_group(by_project, "By Project")
    elif "--by-model" in args:
        print_by_group(by_model, "By Model")
    elif "--top-sessions" in args:
        n = 5
        idx = args.index("--top-sessions")
        if idx + 1 < len(args):
            try:
                n = int(args[idx + 1])
            except ValueError:
                pass
        print_top_sessions(sessions, n)
    else:
        print_summary(totals, label)
        print_by_group(by_project, "By Project", top_n=5)
        print_by_group(by_model, "By Model")
        print_top_sessions(sessions)
        print_suggestions(totals)


if __name__ == "__main__":
    main()
