#!/usr/bin/env python3
"""Bump version in project manifest files and update CHANGELOG.md.

Usage:
    python release_bump.py patch          # 1.2.3 → 1.2.4
    python release_bump.py minor          # 1.2.3 → 1.3.0
    python release_bump.py major          # 1.2.3 → 2.0.0
    python release_bump.py 2.1.0          # explicit version
    python release_bump.py --current      # print current version only
    python release_bump.py --dry-run ...  # preview without writing

Supports: package.json, Cargo.toml, pyproject.toml, VERSION file.
"""

import json
import re
import sys
from datetime import date
from pathlib import Path


def find_manifest():
    """Find the project manifest and return (path, format)."""
    cwd = Path.cwd()
    candidates = [
        (cwd / "package.json", "package.json"),
        (cwd / "Cargo.toml", "cargo"),
        (cwd / "pyproject.toml", "pyproject"),
        (cwd / "VERSION", "plain"),
    ]
    for path, fmt in candidates:
        if path.exists():
            return path, fmt
    return None, None


def read_version(path, fmt):
    """Extract current version from manifest."""
    content = path.read_text(encoding="utf-8")

    if fmt == "package.json":
        data = json.loads(content)
        return data.get("version", "0.0.0")
    elif fmt == "cargo":
        m = re.search(r'^version\s*=\s*"([^"]+)"', content, re.MULTILINE)
        return m.group(1) if m else "0.0.0"
    elif fmt == "pyproject":
        m = re.search(r'^version\s*=\s*"([^"]+)"', content, re.MULTILINE)
        return m.group(1) if m else "0.0.0"
    elif fmt == "plain":
        return content.strip()
    return "0.0.0"


def bump_version(current, bump_type):
    """Compute new version from bump type."""
    # If bump_type looks like an explicit version, use it
    if re.match(r"^\d+\.\d+\.\d+", bump_type):
        return bump_type

    parts = current.split(".")
    if len(parts) < 3:
        parts.extend(["0"] * (3 - len(parts)))

    major, minor, patch = int(parts[0]), int(parts[1]), int(parts[2])

    if bump_type == "major":
        return f"{major + 1}.0.0"
    elif bump_type == "minor":
        return f"{major}.{minor + 1}.0"
    elif bump_type == "patch":
        return f"{major}.{minor}.{patch + 1}"
    else:
        print(f"Unknown bump type: {bump_type}", file=sys.stderr)
        sys.exit(1)


def write_version(path, fmt, new_version, dry_run=False):
    """Write new version to manifest."""
    content = path.read_text(encoding="utf-8")

    if fmt == "package.json":
        data = json.loads(content)
        data["version"] = new_version
        new_content = json.dumps(data, indent=2, ensure_ascii=False) + "\n"
    elif fmt == "cargo":
        new_content = re.sub(
            r'^(version\s*=\s*)"[^"]+"',
            f'\\1"{new_version}"',
            content,
            count=1,
            flags=re.MULTILINE,
        )
    elif fmt == "pyproject":
        new_content = re.sub(
            r'^(version\s*=\s*)"[^"]+"',
            f'\\1"{new_version}"',
            content,
            count=1,
            flags=re.MULTILINE,
        )
    elif fmt == "plain":
        new_content = new_version + "\n"
    else:
        return

    if dry_run:
        print(f"  [dry-run] Would write {new_version} to {path}")
    else:
        path.write_text(new_content, encoding="utf-8")
        print(f"  ✓ Updated {path.name} → {new_version}")


def update_changelog(new_version, dry_run=False):
    """Move [Unreleased] section under new version heading."""
    cwd = Path.cwd()
    changelog = cwd / "CHANGELOG.md"
    if not changelog.exists():
        print("  (no CHANGELOG.md found, skipping)")
        return

    content = changelog.read_text(encoding="utf-8")
    today = date.today().isoformat()
    heading = f"## [{new_version}] — {today}"

    # Replace [Unreleased] heading with version + add new empty Unreleased
    new_content = re.sub(
        r"^## \[Unreleased\]",
        f"## [Unreleased]\n\n{heading}",
        content,
        count=1,
        flags=re.MULTILINE,
    )

    if new_content == content:
        print("  (no [Unreleased] section found in CHANGELOG.md)")
        return

    if dry_run:
        print(f"  [dry-run] Would update CHANGELOG.md with {heading}")
    else:
        changelog.write_text(new_content, encoding="utf-8")
        print(f"  ✓ Updated CHANGELOG.md → {heading}")


def main():
    args = sys.argv[1:]
    dry_run = "--dry-run" in args
    if dry_run:
        args.remove("--dry-run")

    path, fmt = find_manifest()
    if not path:
        print("No manifest found (package.json, Cargo.toml, pyproject.toml, VERSION)")
        sys.exit(1)

    current = read_version(path, fmt)

    if "--current" in args:
        print(current)
        sys.exit(0)

    if not args:
        print(f"Current version: {current}")
        print("Usage: release_bump.py [patch|minor|major|X.Y.Z] [--dry-run]")
        sys.exit(1)

    bump_type = args[0]
    new_version = bump_version(current, bump_type)

    print(f"Version: {current} → {new_version}")
    write_version(path, fmt, new_version, dry_run)
    update_changelog(new_version, dry_run)

    if not dry_run:
        print(
            f"\nDone. Next: git add, commit 'chore(release): v{new_version}', tag v{new_version}"
        )


if __name__ == "__main__":
    main()
