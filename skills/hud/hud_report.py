#!/usr/bin/env python3
"""Generate session HUD with ASCII bar charts from JSONL logs.

Usage:
    python hud_report.py              # Full HUD (tokens + tools)
    python hud_report.py --tokens     # Token usage only
    python hud_report.py --tools      # Tool distribution only

Output: plain text to stdout, no ANSI colors.
"""

import json
import sys
from datetime import datetime
from pathlib import Path
from collections import defaultdict, Counter


def find_today_jsonl():
    """Find JSONL files with entries from today."""
    claude_home = Path.home() / ".claude" / "projects"
    if not claude_home.exists():
        return []
    return list(claude_home.rglob("*.jsonl"))


def parse_today_entries(files):
    """Parse entries from today only."""
    today = datetime.now().date().isoformat()
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
                    ts = obj.get("timestamp") or obj.get("ts") or ""
                    if today in ts:
                        entries.append(obj)
        except OSError:
            continue
    return entries


def ascii_bar(value, max_value, width=20):
    """Render ASCII bar."""
    if max_value <= 0:
        return " " * width
    filled = int((value / max_value) * width)
    return "=" * filled + " " * (width - filled)


def fmt_tokens(n):
    """Format token count."""
    if n >= 1_000_000:
        return f"{n / 1_000_000:.1f}M"
    if n >= 1_000:
        return f"{n / 1_000:.0f}k"
    return str(n)


def print_token_usage(entries):
    """Print token usage with ASCII bars."""
    totals = defaultdict(int)
    for entry in entries:
        usage = entry.get("usage") or entry.get("costData") or {}
        if not usage:
            continue
        totals["cache_read"] += usage.get(
            "cache_creation_input_tokens", 0
        ) or usage.get("cacheReadTokens", 0)
        totals["cache_write"] += usage.get("cache_read_input_tokens", 0) or usage.get(
            "cacheWriteTokens", 0
        )
        totals["input"] += usage.get("input_tokens", 0) or usage.get("inputTokens", 0)
        totals["output"] += usage.get("output_tokens", 0) or usage.get(
            "outputTokens", 0
        )

    if not any(totals.values()):
        print("  (no token data today)")
        return

    max_val = max(totals.values())
    total_input = totals["cache_read"] + totals["cache_write"] + totals["input"]
    cache_hit = (totals["cache_read"] / total_input * 100) if total_input > 0 else 0

    # Cost estimate (Sonnet rates)
    cost = (
        (totals["cache_read"] / 1e6) * 0.30
        + (totals["cache_write"] / 1e6) * 3.75
        + (totals["input"] / 1e6) * 3.00
        + (totals["output"] / 1e6) * 15.00
    )

    rows = [
        ("Cache reads", totals["cache_read"]),
        ("Cache writes", totals["cache_write"]),
        ("Direct input", totals["input"]),
        ("Output", totals["output"]),
    ]

    print("Token usage today")
    for label, val in rows:
        pct = (
            f"({val / total_input * 100:.0f}%)"
            if total_input > 0 and label != "Output"
            else ""
        )
        bar = ascii_bar(val, max_val)
        print(f"  {label:<14} [{bar}] {fmt_tokens(val):>6}  {pct}")
    print(f"\n  Cache hit ratio: {cache_hit:.0f}%  |  Est. cost: ${cost:.2f}")


def print_tool_distribution(entries, top_n=50):
    """Print recent tool call distribution."""
    tools = []
    for entry in entries:
        tool = entry.get("tool") or entry.get("tool_name")
        if tool:
            tools.append(tool)

    if not tools:
        print("  (no tool calls today)")
        return

    # Take last N
    recent = tools[-top_n:]
    counts = Counter(recent)
    top = counts.most_common(6)

    if not top:
        print("  (no tool calls)")
        return

    max_count = top[0][1]

    print(f"Recent tool calls (last {len(recent)})")
    for tool_name, count in top:
        bar = ascii_bar(count, max_count, width=18)
        print(f"  {tool_name:<14} {count:>3}  [{bar}]")


def main():
    args = sys.argv[1:]
    files = find_today_jsonl()

    if not files:
        print("No JSONL logs found in ~/.claude/projects/")
        sys.exit(1)

    entries = parse_today_entries(files)

    if not entries:
        print("No log entries for today.")
        sys.exit(0)

    if "--tokens" in args:
        print_token_usage(entries)
    elif "--tools" in args:
        print_tool_distribution(entries)
    else:
        print_token_usage(entries)
        print()
        print_tool_distribution(entries)


if __name__ == "__main__":
    main()
