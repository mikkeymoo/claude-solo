#!/usr/bin/env python3
"""Parse coverage reports and identify untested code.

Usage:
    python coverage_gaps.py                        # Auto-detect coverage report
    python coverage_gaps.py coverage/lcov.info     # Parse lcov format
    python coverage_gaps.py coverage-summary.json  # Parse Istanbul JSON summary
    python coverage_gaps.py .coverage              # Parse Python coverage.py
    python coverage_gaps.py --changed              # Only show gaps in recently changed files
    python coverage_gaps.py --threshold 80         # Custom coverage threshold (default: 80%)

Supported formats: lcov, Istanbul JSON, coverage.py JSON, Cobertura XML.
Zero dependencies — stdlib only.
"""

import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

# ── Configuration ────────────────────────────────────────────────────────────

DEFAULT_THRESHOLD = 80  # percent

COVERAGE_FILE_CANDIDATES = [
    "coverage/lcov.info",
    "lcov.info",
    "coverage/coverage-summary.json",
    "coverage-summary.json",
    "coverage/coverage-final.json",
    ".coverage.json",
    "coverage.json",
    "coverage.xml",
    "coverage/cobertura.xml",
    "htmlcov/status.json",
]


# ── Parsers ──────────────────────────────────────────────────────────────────


def parse_lcov(filepath):
    """Parse lcov.info format → dict of file: {lines_found, lines_hit, uncovered_lines}."""
    results = {}
    current_file = None
    lines_found = 0
    lines_hit = 0
    uncovered = []

    try:
        content = Path(filepath).read_text(encoding="utf-8", errors="replace")
    except OSError:
        return {}

    for line in content.split("\n"):
        line = line.strip()
        if line.startswith("SF:"):
            current_file = line[3:]
        elif line.startswith("LF:"):
            lines_found = int(line[3:])
        elif line.startswith("LH:"):
            lines_hit = int(line[3:])
        elif line.startswith("DA:"):
            parts = line[3:].split(",")
            if len(parts) >= 2:
                line_num = int(parts[0])
                hits = int(parts[1])
                if hits == 0:
                    uncovered.append(line_num)
        elif line == "end_of_record":
            if current_file:
                results[current_file] = {
                    "lines_found": lines_found,
                    "lines_hit": lines_hit,
                    "coverage": (lines_hit / lines_found * 100)
                    if lines_found > 0
                    else 100,
                    "uncovered_lines": sorted(uncovered),
                }
            current_file = None
            lines_found = 0
            lines_hit = 0
            uncovered = []

    return results


def parse_istanbul_json(filepath):
    """Parse Istanbul/NYC JSON coverage summary."""
    try:
        data = json.loads(Path(filepath).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}

    results = {}

    # coverage-summary.json format
    if "total" in data and isinstance(data.get("total"), dict):
        for file_path, file_data in data.items():
            if file_path == "total":
                continue
            if isinstance(file_data, dict) and "lines" in file_data:
                lines = file_data["lines"]
                results[file_path] = {
                    "lines_found": lines.get("total", 0),
                    "lines_hit": lines.get("covered", 0),
                    "coverage": lines.get("pct", 0),
                    "uncovered_lines": [],
                }
    # coverage-final.json format (per-file detailed)
    else:
        for file_path, file_data in data.items():
            if not isinstance(file_data, dict):
                continue
            s = file_data.get("s", {})  # statement map
            total = len(s)
            hit = sum(1 for v in s.values() if v > 0)

            # Find uncovered lines from statement map
            uncovered = []
            stat_map = file_data.get("statementMap", {})
            for key, count in s.items():
                if count == 0 and key in stat_map:
                    loc = stat_map[key]
                    if "start" in loc:
                        uncovered.append(loc["start"].get("line", 0))

            results[file_path] = {
                "lines_found": total,
                "lines_hit": hit,
                "coverage": (hit / total * 100) if total > 0 else 100,
                "uncovered_lines": sorted(set(uncovered)),
            }

    return results


def parse_coverage_py_json(filepath):
    """Parse Python coverage.py JSON report."""
    try:
        data = json.loads(Path(filepath).read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}

    results = {}
    files = data.get("files", {})

    for file_path, file_data in files.items():
        summary = file_data.get("summary", {})
        missing_lines = file_data.get("missing_lines", [])
        executed = file_data.get("executed_lines", [])

        total = summary.get("num_statements", len(executed) + len(missing_lines))
        covered = summary.get("covered_lines", len(executed))
        pct = summary.get("percent_covered", 0)

        results[file_path] = {
            "lines_found": total,
            "lines_hit": covered,
            "coverage": pct,
            "uncovered_lines": sorted(missing_lines),
        }

    return results


def parse_cobertura_xml(filepath):
    """Parse Cobertura XML format."""
    try:
        tree = ET.parse(filepath)
        root = tree.getroot()
    except (OSError, ET.ParseError):
        return {}

    results = {}

    for package in root.iter("package"):
        for cls in package.iter("class"):
            filename = cls.get("filename", "")
            line_rate = float(cls.get("line-rate", 0))
            lines = cls.find("lines")
            uncovered = []
            total = 0
            hit = 0

            if lines is not None:
                for line in lines.iter("line"):
                    total += 1
                    hits = int(line.get("hits", 0))
                    if hits > 0:
                        hit += 1
                    else:
                        uncovered.append(int(line.get("number", 0)))

            results[filename] = {
                "lines_found": total,
                "lines_hit": hit,
                "coverage": line_rate * 100,
                "uncovered_lines": sorted(uncovered),
            }

    return results


# ── Auto-detection ───────────────────────────────────────────────────────────


def find_coverage_report():
    """Auto-detect coverage report file."""
    cwd = Path.cwd()
    for candidate in COVERAGE_FILE_CANDIDATES:
        path = cwd / candidate
        if path.exists():
            return str(path)
    return None


def detect_format(filepath):
    """Detect coverage report format."""
    filepath = Path(filepath)
    name = filepath.name.lower()

    if name.endswith(".info") or "lcov" in name:
        return "lcov"
    elif name.endswith(".xml"):
        return "cobertura"
    elif name.endswith(".json"):
        try:
            data = json.loads(filepath.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError):
            return "unknown"
        if "meta" in data and "show_contexts" in data.get("meta", {}):
            return "coverage_py"
        if "files" in data and any(
            "missing_lines" in v
            for v in data.get("files", {}).values()
            if isinstance(v, dict)
        ):
            return "coverage_py"
        if "total" in data:
            return "istanbul"
        return "istanbul"  # best guess for JSON

    return "unknown"


def parse_report(filepath):
    """Parse any supported coverage report format."""
    fmt = detect_format(filepath)
    if fmt == "lcov":
        return parse_lcov(filepath)
    elif fmt == "istanbul":
        return parse_istanbul_json(filepath)
    elif fmt == "coverage_py":
        return parse_coverage_py_json(filepath)
    elif fmt == "cobertura":
        return parse_cobertura_xml(filepath)
    else:
        print(f"Unknown coverage format: {filepath}", file=sys.stderr)
        return {}


# ── Changed Files Filter ────────────────────────────────────────────────────


def get_recently_changed_files(days=7):
    """Get files changed in the last N days via git."""
    try:
        result = subprocess.run(
            ["git", "log", f"--since={days} days ago", "--name-only", "--format="],
            capture_output=True,
            text=True,
            timeout=10,
        )
        if result.returncode == 0:
            files = set()
            for line in result.stdout.split("\n"):
                line = line.strip()
                if line:
                    files.add(line)
            return files
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return set()


# ── Uncovered Line Ranges ───────────────────────────────────────────────────


def collapse_ranges(lines):
    """Collapse [1,2,3,5,6,10] → ['1-3', '5-6', '10']."""
    if not lines:
        return []
    ranges = []
    start = lines[0]
    end = lines[0]
    for line in lines[1:]:
        if line == end + 1:
            end = line
        else:
            if start == end:
                ranges.append(str(start))
            else:
                ranges.append(f"{start}-{end}")
            start = end = line
    if start == end:
        ranges.append(str(start))
    else:
        ranges.append(f"{start}-{end}")
    return ranges


# ── Report ───────────────────────────────────────────────────────────────────


def print_report(results, threshold, changed_only=False, changed_files=None):
    """Print coverage gaps report."""
    if not results:
        print("No coverage data found.")
        return

    # Filter to changed files if requested
    if changed_only and changed_files:
        filtered = {}
        for filepath, data in results.items():
            # Normalize paths for cross-platform comparison
            norm = Path(filepath).as_posix()
            norm_parts = norm.rsplit("/", maxsplit=5)
            if any(
                Path(cf).as_posix().endswith(norm)
                or norm.endswith(Path(cf).as_posix())
                or any(
                    Path(cf).as_posix().endswith(part) for part in norm_parts if part
                )
                for cf in changed_files
            ):
                filtered[filepath] = data
        if not filtered:
            print("No coverage data for recently changed files.")
            return
        results = filtered

    # Sort by coverage ascending (worst first)
    sorted_files = sorted(results.items(), key=lambda x: x[1]["coverage"])

    # Overall stats
    total_found = sum(d["lines_found"] for d in results.values())
    total_hit = sum(d["lines_hit"] for d in results.values())
    overall_pct = (total_hit / total_found * 100) if total_found > 0 else 0

    below_threshold = [f for f, d in results.items() if d["coverage"] < threshold]
    zero_coverage = [
        f for f, d in results.items() if d["coverage"] == 0 and d["lines_found"] > 0
    ]

    print(f"Coverage Gaps Report — {len(results)} files analyzed")
    print(f"  Overall: {overall_pct:.1f}%  ({total_hit}/{total_found} lines)")
    print(f"  Threshold: {threshold}%")
    print(f"  Below threshold: {len(below_threshold)} files")
    if zero_coverage:
        print(f"  Zero coverage: {len(zero_coverage)} files")
    print()

    # Files below threshold
    if below_threshold:
        print(f"── Below {threshold}% Coverage ({len(below_threshold)} files) ──")
        for filepath, data in sorted_files:
            if data["coverage"] >= threshold:
                continue
            pct = data["coverage"]
            bar_width = 20
            filled = int(pct / 100 * bar_width)
            bar = "=" * filled + " " * (bar_width - filled)

            uncovered_str = ""
            if data["uncovered_lines"]:
                ranges = collapse_ranges(data["uncovered_lines"][:20])
                uncovered_str = f"  uncovered: {', '.join(ranges[:8])}"
                if len(ranges) > 8:
                    uncovered_str += f" (+{len(ranges) - 8} more)"

            print(f"  {pct:>5.1f}%  [{bar}]  {filepath}")
            if uncovered_str:
                print(f"         {uncovered_str}")
        print()

    # Files with good coverage
    good_files = [f for f, d in results.items() if d["coverage"] >= threshold]
    if good_files:
        print(f"── Above {threshold}% Coverage ({len(good_files)} files) ──")
        for filepath, data in sorted(results.items(), key=lambda x: -x[1]["coverage"]):
            if data["coverage"] < threshold:
                continue
            pct = data["coverage"]
            print(f"  {pct:>5.1f}%  {filepath}")
        print()

    # Summary
    print("── Summary ──")
    print(f"  Total files:        {len(results)}")
    print(f"  Overall coverage:   {overall_pct:.1f}%")
    print(f"  Below threshold:    {len(below_threshold)}")
    print(
        f"  At 100%:            {sum(1 for d in results.values() if d['coverage'] == 100)}"
    )

    if overall_pct < threshold:
        gap = threshold - overall_pct
        lines_needed = int(gap / 100 * total_found)
        print(f"\n  To reach {threshold}%: ~{lines_needed} more lines need coverage")

    # Priority list
    if below_threshold:
        print("\n── Priority: Test These First ──")
        # Sort by impact: most uncovered lines first
        by_impact = sorted(
            [(f, d) for f, d in results.items() if d["coverage"] < threshold],
            key=lambda x: x[1]["lines_found"] - x[1]["lines_hit"],
            reverse=True,
        )[:5]
        for i, (filepath, data) in enumerate(by_impact, 1):
            uncovered = data["lines_found"] - data["lines_hit"]
            print(
                f"  {i}. {filepath} ({uncovered} uncovered lines, {data['coverage']:.0f}%)"
            )


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    args = sys.argv[1:]

    changed_only = "--changed" in args
    threshold = DEFAULT_THRESHOLD

    if "--threshold" in args:
        idx = args.index("--threshold")
        if idx + 1 < len(args):
            try:
                threshold = int(args[idx + 1])
            except ValueError:
                pass

    # Find coverage file — strip consumed flag arguments and their values
    consumed = {"--changed", "--threshold", str(threshold)}
    path_args = [a for a in args if a not in consumed and not a.startswith("--")]
    if path_args:
        coverage_file = path_args[0]
    else:
        coverage_file = find_coverage_report()

    if not coverage_file:
        print("No coverage report found.")
        print(f"Looked for: {', '.join(COVERAGE_FILE_CANDIDATES)}")
        print("\nGenerate a report first:")
        print("  Python:  coverage run -m pytest && coverage json")
        print("  Node:    npx vitest --coverage --reporter=lcov")
        print("  Go:      go test -coverprofile=coverage.out ./...")
        sys.exit(1)

    if not Path(coverage_file).exists():
        print(f"Coverage file not found: {coverage_file}", file=sys.stderr)
        sys.exit(1)

    results = parse_report(coverage_file)

    changed_files = None
    if changed_only:
        changed_files = get_recently_changed_files()

    print_report(results, threshold, changed_only, changed_files)


if __name__ == "__main__":
    main()
