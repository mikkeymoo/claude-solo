#!/usr/bin/env python3
"""Parse conventional commits and generate a changelog.

Parse commits since the last tag (or --since TAG) and group by conventional commit type.
Output in Keep a Changelog format.

Usage:
    python changelog_gen.py [--preview|--write]
    python changelog_gen.py --since v0.5.0
    python changelog_gen.py --format json
    python changelog_gen.py --unreleased-only
    python changelog_gen.py --preview --since TAG --format markdown

Output: changelog markdown to stdout (--preview) or update CHANGELOG.md (--write)
"""

import json
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path
from typing import Optional, Dict, List, Tuple


# ── Commit type → section mapping ─────────────────────────────────────────────
COMMIT_SECTIONS = {
    "feat": "Added",
    "fix": "Fixed",
    "refactor": "Changed",
    "style": "Changed",
    "perf": "Changed",
    "docs": "Documentation",
    "security": "Security",
    "chore": "Chore",
    "test": "Chore",
    "build": "Chore",
    "ci": "Chore",
}

SECTION_ORDER = [
    "Added",
    "Changed",
    "Fixed",
    "Security",
    "Removed",
    "Documentation",
    "Chore",
]


def get_last_tag() -> Optional[str]:
    """Detect the most recent git tag."""
    try:
        tag = subprocess.check_output(
            ["git", "describe", "--tags", "--abbrev=0"],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
        return tag if tag else None
    except (subprocess.CalledProcessError, FileNotFoundError):
        return None


def parse_commit_subject(subject: str) -> Tuple[Optional[str], Optional[str], str]:
    """Parse conventional commit subject.

    Returns: (type, scope, description)
    E.g., "feat(auth): add login" → ("feat", "auth", "add login")
    """
    match = re.match(r"^(\w+)(?:\(([^)]+)\))?:\s*(.+)$", subject)
    if match:
        commit_type, scope, description = match.groups()
        return commit_type, scope, description
    return None, None, subject


def get_commits(since: Optional[str] = None) -> List[Dict]:
    """Get commits in conventional format.

    Args:
        since: tag name to start from. If None, auto-detect last tag.

    Returns:
        List of dicts: {type, scope, description, author, email, date, hash}
    """
    if since is None:
        since = get_last_tag()

    # Build git log range
    if since:
        git_range = f"{since}..HEAD"
    else:
        # No tags yet; show all commits
        git_range = "HEAD"

    try:
        output = subprocess.check_output(
            [
                "git",
                "log",
                git_range,
                "--format=%H|%s|%an|%ae|%ad",
                "--date=short",
            ],
            stderr=subprocess.DEVNULL,
            text=True,
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return []

    commits = []
    for line in output.split("\n"):
        if not line.strip():
            continue
        parts = line.split("|")
        if len(parts) < 5:
            continue
        hash_, subject, author, email, date = (
            parts[0],
            parts[1],
            parts[2],
            parts[3],
            parts[4],
        )

        commit_type, scope, description = parse_commit_subject(subject)
        if not commit_type:
            continue

        commits.append(
            {
                "hash": hash_,
                "type": commit_type,
                "scope": scope,
                "description": description,
                "author": author,
                "email": email,
                "date": date,
            }
        )

    return commits


def group_commits_by_section(commits: List[Dict]) -> Dict[str, List[Dict]]:
    """Group commits by changelog section."""
    sections = {section: [] for section in SECTION_ORDER}

    for commit in commits:
        section = COMMIT_SECTIONS.get(commit["type"], "Chore")
        sections[section].append(commit)

    # Remove empty sections
    return {k: v for k, v in sections.items() if v}


def format_commit_entry(commit: Dict) -> str:
    """Format a single commit for changelog."""
    scope_part = f"({commit['scope']})" if commit["scope"] else ""
    return f"- **{commit['type']}{scope_part}**: {commit['description']}"


def generate_markdown(commits: List[Dict], unreleased_only: bool = False) -> str:
    """Generate changelog markdown."""
    if not commits:
        return "## [Unreleased]\n\nNo changes yet.\n"

    sections = group_commits_by_section(commits)
    lines = ["## [Unreleased]", ""]

    for section in SECTION_ORDER:
        if section not in sections or not sections[section]:
            continue

        lines.append(f"### {section}")
        lines.append("")

        for commit in sections[section]:
            lines.append(format_commit_entry(commit))

        lines.append("")

    return "\n".join(lines).rstrip() + "\n"


def generate_json(commits: List[Dict]) -> str:
    """Generate changelog as JSON."""
    sections = group_commits_by_section(commits)
    data = {
        "unreleased": {section: sections.get(section, []) for section in SECTION_ORDER},
        "generated_at": datetime.now().isoformat(),
    }
    return json.dumps(data, indent=2)


def read_existing_changelog() -> str:
    """Read existing CHANGELOG.md if it exists."""
    path = Path("CHANGELOG.md")
    if path.exists():
        return path.read_text(encoding="utf-8")
    return ""


def write_changelog(new_content: str):
    """Update CHANGELOG.md with new content."""
    path = Path("CHANGELOG.md")
    existing = read_existing_changelog()

    # If [Unreleased] exists, replace it; otherwise prepend
    if "## [Unreleased]" in existing:
        # Find the next version section
        match = re.search(r"^## \[[\d.]+\]|^## \d+\.\d+\.\d+", existing, re.MULTILINE)
        if match:
            insert_pos = match.start()
            updated = new_content + existing[insert_pos:]
        else:
            # No version section found, just prepend
            updated = new_content + existing
    else:
        # No [Unreleased] section, prepend
        updated = new_content + existing

    path.write_text(updated, encoding="utf-8")
    print(f"Updated {path}")


def main():
    import argparse

    parser = argparse.ArgumentParser(
        description="Generate changelog from conventional commits"
    )
    parser.add_argument(
        "--preview",
        action="store_true",
        default=True,
        help="Output to stdout only (default)",
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Update CHANGELOG.md",
    )
    parser.add_argument(
        "--since",
        help="Start from specific tag",
    )
    parser.add_argument(
        "--format",
        choices=["markdown", "json"],
        default="markdown",
        help="Output format (default: markdown)",
    )
    parser.add_argument(
        "--unreleased-only",
        action="store_true",
        help="Show only unreleased commits",
    )

    args = parser.parse_args()

    # Get commits
    commits = get_commits(since=args.since)

    if not commits:
        print("No commits found.", file=sys.stderr)
        return 1

    # Generate output
    if args.format == "json":
        output = generate_json(commits)
    else:
        output = generate_markdown(commits, unreleased_only=args.unreleased_only)

    # Write or preview
    if args.write:
        if args.format != "markdown":
            print("--write requires markdown format", file=sys.stderr)
            return 1
        write_changelog(output)
    else:
        print(output, end="")

    return 0


if __name__ == "__main__":
    sys.exit(main())
