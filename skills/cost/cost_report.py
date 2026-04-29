#!/usr/bin/env python3
"""Parse Claude Code JSONL logs and produce a cost report.

Usage:
    python cost_report.py [--today | --week | --month | --all]
    python cost_report.py --top-sessions 5
    python cost_report.py --by-project
    python cost_report.py --by-model

Output: structured text report to stdout.
"""

import json
import sys
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

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
            with open(f, "r", encoding="utf-8", errors="replace") as fh:
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
                            entry_time = datetime.fromisoformat(
                                ts.replace("Z", "+00:00")
                            )
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
        usage = entry.get("usage") or entry.get("costData") or {}
        if not usage:
            continue

        model = entry.get("model", "unknown")
        cwd = entry.get("cwd", "unknown")
        session_id = entry.get("sessionId") or entry.get("session_id", "unknown")

        cache_read = usage.get("cache_creation_input_tokens", 0) or usage.get(
            "cacheReadTokens", 0
        )
        cache_write = usage.get("cache_read_input_tokens", 0) or usage.get(
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
        totals.get("cache_read", 0)
        + totals.get("cache_write", 0)
        + totals.get("input", 0)
    )
    cache_hit = (
        (totals.get("cache_read", 0) / total_input * 100) if total_input > 0 else 0
    )
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
        totals.get("cache_read", 0)
        + totals.get("cache_write", 0)
        + totals.get("input", 0)
    )
    cache_hit = (
        (totals.get("cache_read", 0) / total_input * 100) if total_input > 0 else 0
    )
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


def main():
    args = sys.argv[1:]
    now = datetime.now().astimezone()

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
