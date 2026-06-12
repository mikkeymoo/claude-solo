#!/usr/bin/env python3
"""Generate git statistics for sprint retrospectives.

Usage:
    python git_stats.py                    # Last 7 days (default)
    python git_stats.py --since 2026-04-01 # Since specific date
    python git_stats.py --days 14          # Last N days
    python git_stats.py --since-tag v1.0   # Since a git tag
    python git_stats.py --churn            # Show file churn hotspots
    python git_stats.py --authors          # Show per-author breakdown

Output: structured text report for retrospectives.
Zero dependencies — stdlib only.
"""

import os
import re
import subprocess
import sys
from collections import Counter, defaultdict
from datetime import datetime


# ── Git Helpers ──────────────────────────────────────────────────────────────


def run_git(*args, cwd=None):
    """Run a git command and return stdout."""
    try:
        result = subprocess.run(
            ["git"] + list(args),
            capture_output=True,
            text=True,
            timeout=30,
            cwd=cwd or os.getcwd(),
        )
        if result.returncode != 0:
            return ""
        return result.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return ""


def get_commits(since=None, since_tag=None):
    """Get commit log entries."""
    args = ["log", "--format=%H|%ai|%an|%s", "--no-merges"]
    if since_tag:
        args.append(f"{since_tag}..HEAD")
    elif since:
        args.extend(["--since", since])
    else:
        args.extend(["--since", "7 days ago"])

    output = run_git(*args)
    if not output:
        return []

    commits = []
    for line in output.split("\n"):
        if "|" not in line:
            continue
        parts = line.split("|", 3)
        if len(parts) < 4:
            continue
        commits.append(
            {
                "hash": parts[0][:8],
                "date": parts[1][:10],
                "author": parts[2],
                "message": parts[3],
            }
        )
    return commits


def get_diff_stats(since=None, since_tag=None):
    """Get diffstat (files changed, insertions, deletions)."""
    args = ["diff", "--stat", "--no-merges"]
    if since_tag:
        args.append(f"{since_tag}..HEAD")
    elif since:
        # Use log --diff-filter for time-based
        args = [
            "log",
            "--since",
            since,
            "--no-merges",
            "--diff-filter=ACDMR",
            "--numstat",
            "--format=",
        ]
    else:
        args = ["log", "--since", "7 days ago", "--no-merges", "--numstat", "--format="]

    output = run_git(*args)
    if not output:
        return [], 0, 0

    files = defaultdict(lambda: {"added": 0, "removed": 0, "changes": 0})
    total_added = 0
    total_removed = 0

    for line in output.split("\n"):
        line = line.strip()
        if not line:
            continue
        parts = line.split("\t")
        if len(parts) >= 3:
            try:
                added = int(parts[0]) if parts[0] != "-" else 0
                removed = int(parts[1]) if parts[1] != "-" else 0
                filepath = parts[2]
                files[filepath]["added"] += added
                files[filepath]["removed"] += removed
                files[filepath]["changes"] += 1
                total_added += added
                total_removed += removed
            except ValueError:
                continue

    return dict(files), total_added, total_removed


def get_file_churn(since=None, since_tag=None):
    """Get files sorted by number of times changed (churn hotspots)."""
    args = ["log", "--no-merges", "--name-only", "--format="]
    if since_tag:
        args.append(f"{since_tag}..HEAD")
    elif since:
        args.extend(["--since", since])
    else:
        args.extend(["--since", "7 days ago"])

    output = run_git(*args)
    if not output:
        return []

    file_counts = Counter()
    for line in output.split("\n"):
        line = line.strip()
        if line and not line.startswith("commit "):
            file_counts[line] += 1

    return file_counts.most_common(15)


# ── Analysis ─────────────────────────────────────────────────────────────────


def classify_commit(message):
    """Classify commit by conventional commit type."""
    msg = message.lower().strip()
    patterns = [
        ("feat", r"^feat[\(:]"),
        ("fix", r"^fix[\(:]"),
        ("refactor", r"^refactor[\(:]"),
        ("docs", r"^docs[\(:]"),
        ("test", r"^test[\(:]"),
        ("chore", r"^chore[\(:]"),
        ("style", r"^style[\(:]"),
        ("perf", r"^perf[\(:]"),
        ("ci", r"^ci[\(:]"),
        ("build", r"^build[\(:]"),
    ]
    for label, pattern in patterns:
        if re.match(pattern, msg):
            return label
    return "other"


def analyze_commits(commits):
    """Analyze commit patterns."""
    if not commits:
        return {}

    by_type = Counter()
    by_date = Counter()
    by_author = defaultdict(int)

    for c in commits:
        commit_type = classify_commit(c["message"])
        by_type[commit_type] += 1
        by_date[c["date"]] += 1
        by_author[c["author"]] += 1

    return {
        "by_type": by_type,
        "by_date": by_date,
        "by_author": by_author,
        "total": len(commits),
    }


# ── Report ───────────────────────────────────────────────────────────────────


def ascii_bar(value, max_value, width=20):
    """Render ASCII bar."""
    if max_value <= 0:
        return ""
    filled = int((value / max_value) * width)
    return "=" * filled


def print_report(
    commits,
    analysis,
    diff_files,
    total_added,
    total_removed,
    churn,
    label,
    show_churn=False,
    show_authors=False,
):
    """Print the retrospective stats report."""
    if not commits:
        print(f"No commits found for period: {label}")
        return

    print(f"Git Stats — {label}")
    print(
        f"  Commits: {analysis['total']}  |  Files changed: {len(diff_files)}"
        f"  |  +{total_added} / -{total_removed} lines\n"
    )

    # Commits by type
    by_type = analysis["by_type"]
    if by_type:
        max_count = max(by_type.values())
        print("── Commit Types ──")
        for ctype, count in by_type.most_common():
            bar = ascii_bar(count, max_count, 15)
            print(f"  {ctype:<12} {count:>3}  [{bar}]")
        print()

    # Commits by day
    by_date = analysis["by_date"]
    if by_date:
        max_count = max(by_date.values())
        print("── Commits by Day ──")
        for date_str in sorted(by_date.keys()):
            count = by_date[date_str]
            bar = ascii_bar(count, max_count, 20)
            # Day of week
            try:
                dt = datetime.strptime(date_str, "%Y-%m-%d")
                dow = dt.strftime("%a")
            except ValueError:
                dow = "???"
            print(f"  {date_str} {dow}  {count:>3}  [{bar}]")
        print()

    # Per-author breakdown
    if show_authors:
        by_author = analysis["by_author"]
        if by_author:
            max_count = max(by_author.values())
            print("── By Author ──")
            for author, count in sorted(by_author.items(), key=lambda x: -x[1]):
                bar = ascii_bar(count, max_count, 15)
                print(f"  {author:<30} {count:>3}  [{bar}]")
            print()

    # File churn hotspots
    if show_churn and churn:
        print("── Churn Hotspots (most-edited files) ──")
        max_count = churn[0][1] if churn else 1
        for filepath, count in churn[:10]:
            bar = ascii_bar(count, max_count, 15)
            print(f"  {count:>3}x  [{bar}]  {filepath}")
        print()

    # Most changed files by lines
    if diff_files:
        sorted_files = sorted(
            diff_files.items(),
            key=lambda x: x[1]["added"] + x[1]["removed"],
            reverse=True,
        )[:10]
        print("── Most Changed Files (by lines) ──")
        for filepath, stats in sorted_files:
            total = stats["added"] + stats["removed"]
            print(
                f"  +{stats['added']:<5} -{stats['removed']:<5} ({total:>5} total)  {filepath}"
            )
        print()

    # What shipped (features and fixes)
    features = [c for c in commits if classify_commit(c["message"]) == "feat"]
    fixes = [c for c in commits if classify_commit(c["message"]) == "fix"]

    if features:
        print(f"── Features Shipped ({len(features)}) ──")
        for c in features[:10]:
            print(f"  {c['hash']}  {c['message'][:70]}")
        if len(features) > 10:
            print(f"  ... and {len(features) - 10} more")
        print()

    if fixes:
        print(f"── Bugs Fixed ({len(fixes)}) ──")
        for c in fixes[:10]:
            print(f"  {c['hash']}  {c['message'][:70]}")
        if len(fixes) > 10:
            print(f"  ... and {len(fixes) - 10} more")
        print()

    # Velocity estimate
    dates = sorted(analysis["by_date"].keys())
    if len(dates) >= 2:
        try:
            start = datetime.strptime(dates[0], "%Y-%m-%d")
            end = datetime.strptime(dates[-1], "%Y-%m-%d")
            span_days = max((end - start).days, 1)
            velocity = analysis["total"] / span_days
            print("── Velocity ──")
            print(f"  {velocity:.1f} commits/day over {span_days} days")
            print(
                f"  {total_added + total_removed} lines changed ({total_added / max(span_days, 1):.0f} lines/day)"
            )
        except ValueError:
            pass


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    args = sys.argv[1:]

    since = None
    since_tag = None
    label = "Last 7 days"
    show_churn = "--churn" in args
    show_authors = "--authors" in args

    if "--since" in args:
        idx = args.index("--since")
        if idx + 1 < len(args):
            val = args[idx + 1]
            # Check if it's a tag or a date
            tag_check = run_git("rev-parse", val)
            if tag_check and not re.match(r"\d{4}-\d{2}-\d{2}", val):
                since_tag = val
                label = f"Since tag {val}"
            else:
                since = val
                label = f"Since {val}"

    elif "--since-tag" in args:
        idx = args.index("--since-tag")
        if idx + 1 < len(args):
            since_tag = args[idx + 1]
            label = f"Since tag {since_tag}"

    elif "--days" in args:
        idx = args.index("--days")
        if idx + 1 < len(args):
            try:
                days = int(args[idx + 1])
                since = f"{days} days ago"
                label = f"Last {days} days"
            except ValueError:
                pass

    commits = get_commits(since=since, since_tag=since_tag)
    analysis = analyze_commits(commits)
    diff_files, total_added, total_removed = get_diff_stats(
        since=since, since_tag=since_tag
    )
    churn = get_file_churn(since=since, since_tag=since_tag) if show_churn else []

    print_report(
        commits,
        analysis,
        diff_files,
        total_added,
        total_removed,
        churn,
        label,
        show_churn,
        show_authors,
    )


if __name__ == "__main__":
    main()
