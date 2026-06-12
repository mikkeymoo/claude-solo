#!/usr/bin/env python3
"""Scan a codebase for performance anti-patterns.

Usage:
    python perf_analyzer.py [path]              # Scan directory (default: cwd)
    python perf_analyzer.py --lang py [path]    # Python files only
    python perf_analyzer.py --lang js [path]    # JavaScript files only
    python perf_analyzer.py --lang ts [path]    # TypeScript files only
    python perf_analyzer.py --format json       # JSON output

Output: performance findings grouped by file, sorted by severity.
Zero dependencies — stdlib only.
"""

import ast
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path

# ── Configuration ────────────────────────────────────────────────────────────

SKIP_DIRS = {
    ".git",
    "node_modules",
    "__pycache__",
    ".venv",
    "venv",
    "env",
    ".mypy_cache",
    ".pytest_cache",
    ".ruff_cache",
    "dist",
    "build",
    ".next",
    ".nuxt",
    "coverage",
    ".tox",
    ".eggs",
}

PY_EXTENSIONS = {".py"}
JS_EXTENSIONS = {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs"}


# ── File Discovery ───────────────────────────────────────────────────────────


def should_skip_dir(dirname):
    """Check if directory should be skipped."""
    return dirname in SKIP_DIRS or dirname.startswith(".")


def find_files(root, extensions=None):
    """Find source files, respecting skip rules."""
    root = Path(root)
    if extensions is None:
        extensions = PY_EXTENSIONS | JS_EXTENSIONS

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if not should_skip_dir(d)]
        for fname in filenames:
            fpath = Path(dirpath) / fname
            if fpath.suffix in extensions:
                yield fpath


# ── Python Analysis (AST-based) ──────────────────────────────────────────────


def analyze_python_file(filepath):
    """Scan Python file for performance anti-patterns."""
    findings = []
    try:
        source = filepath.read_text(encoding="utf-8", errors="replace")
        tree = ast.parse(source, filename=str(filepath))
    except (SyntaxError, UnicodeDecodeError):
        return findings

    # Find nested loops (O(n²) pattern)
    for node in ast.walk(tree):
        if isinstance(node, (ast.For, ast.While)):
            findings.extend(_check_nested_loops(node, filepath, source))

    # Find allocations in loops
    for node in ast.walk(tree):
        if isinstance(node, (ast.For, ast.While)):
            findings.extend(_check_allocations_in_loop(node, filepath, source))

    # Find sync I/O in loops
    for node in ast.walk(tree):
        if isinstance(node, (ast.For, ast.While)):
            findings.extend(_check_sync_io_in_loop(node, filepath, source))

    # Find string concatenation in loops
    for node in ast.walk(tree):
        if isinstance(node, (ast.For, ast.While)):
            findings.extend(_check_string_concat_in_loop(node, filepath, source))

    return findings


def _check_nested_loops(loop_node, filepath, source):
    """Detect nested loops (potential O(n²))."""
    findings = []
    lines = source.split("\n")

    # Check if loop body contains another loop
    for child in ast.walk(loop_node):
        if child is loop_node:
            continue
        if isinstance(child, (ast.For, ast.While)):
            # Found nested loop
            findings.append(
                {
                    "type": "nested_loop",
                    "file": str(filepath),
                    "line": loop_node.lineno,
                    "severity": "HIGH",
                    "detail": f"Nested loop at L{child.lineno} (potential O(n²))",
                    "snippet": _get_snippet(lines, loop_node.lineno),
                }
            )
            break  # Report once per outer loop

    return findings


def _check_allocations_in_loop(loop_node, filepath, source):
    """Detect large allocations inside loops."""
    findings = []
    lines = source.split("\n")
    loop_body = loop_node.body if hasattr(loop_node, "body") else []

    for node in ast.walk(loop_node):
        # new list, dict, set allocation
        if isinstance(node, ast.List):
            if any(isinstance(n, ast.Constant) for n in node.elts):
                # List with elements is OK; empty list is fine too
                pass
            findings.append(
                {
                    "type": "allocation_in_loop",
                    "file": str(filepath),
                    "line": node.lineno,
                    "severity": "MEDIUM",
                    "detail": f"Array allocation in loop at L{node.lineno}",
                    "snippet": _get_snippet(lines, node.lineno),
                }
            )
        elif isinstance(node, ast.Dict):
            findings.append(
                {
                    "type": "allocation_in_loop",
                    "file": str(filepath),
                    "line": node.lineno,
                    "severity": "MEDIUM",
                    "detail": f"Dict allocation in loop at L{node.lineno}",
                    "snippet": _get_snippet(lines, node.lineno),
                }
            )
        elif isinstance(node, ast.Call):
            if isinstance(node.func, ast.Name):
                if node.func.id in ("set", "dict", "list"):
                    findings.append(
                        {
                            "type": "allocation_in_loop",
                            "file": str(filepath),
                            "line": node.lineno,
                            "severity": "MEDIUM",
                            "detail": f"{node.func.id}() allocation in loop at L{node.lineno}",
                            "snippet": _get_snippet(lines, node.lineno),
                        }
                    )

    return findings


def _check_sync_io_in_loop(loop_node, filepath, source):
    """Detect synchronous I/O operations inside loops."""
    findings = []
    lines = source.split("\n")

    for node in ast.walk(loop_node):
        if isinstance(node, ast.Call):
            if isinstance(node.func, ast.Attribute):
                # Check for open(), read(), write()
                if node.func.attr in ("read", "write", "readlines", "readline"):
                    findings.append(
                        {
                            "type": "sync_io_in_loop",
                            "file": str(filepath),
                            "line": node.lineno,
                            "severity": "HIGH",
                            "detail": f"Sync I/O call .{node.func.attr}() in loop at L{node.lineno}",
                            "snippet": _get_snippet(lines, node.lineno),
                        }
                    )
            elif isinstance(node.func, ast.Name):
                if node.func.id == "open":
                    findings.append(
                        {
                            "type": "sync_io_in_loop",
                            "file": str(filepath),
                            "line": node.lineno,
                            "severity": "HIGH",
                            "detail": f"open() call in loop at L{node.lineno}",
                            "snippet": _get_snippet(lines, node.lineno),
                        }
                    )

    return findings


def _check_string_concat_in_loop(loop_node, filepath, source):
    """Detect string concatenation in loops (O(n²) in some cases)."""
    findings = []
    lines = source.split("\n")

    for node in ast.walk(loop_node):
        if isinstance(node, ast.AugAssign):
            # s += item pattern
            if isinstance(node.op, ast.Add) and isinstance(node.target, ast.Name):
                findings.append(
                    {
                        "type": "string_concat_in_loop",
                        "file": str(filepath),
                        "line": node.lineno,
                        "severity": "MEDIUM",
                        "detail": f"String concatenation (+= operator) in loop at L{node.lineno}",
                        "snippet": _get_snippet(lines, node.lineno),
                    }
                )

    return findings


def _get_snippet(lines, line_num):
    """Extract a code snippet around a line."""
    if line_num < 1 or line_num > len(lines):
        return ""
    idx = line_num - 1
    return lines[idx].strip()[:100]


# ── JavaScript/TypeScript Analysis (regex-based) ─────────────────────────────


# Patterns for nested loops
JS_FOR_PATTERN = re.compile(r"^\s*(?:for|while)\s*[\(\{]", re.MULTILINE)

# Patterns for allocations
JS_ALLOC_PATTERN = re.compile(
    r"(?:new\s+(?:Map|Set|Array|Object|WeakMap|WeakSet)|(?:\[|\{)(?:\s|//[^\n]*\n)*(?:\]|\}))",
    re.MULTILINE,
)

# Sync I/O patterns
JS_SYNC_IO_PATTERN = re.compile(
    r"(?:fs\.readFileSync|fs\.writeFileSync|readFileSync|writeFileSync|XMLHttpRequest)",
    re.MULTILINE,
)

# String concatenation
JS_STRING_CONCAT_PATTERN = re.compile(r"[\w_]+\s*\+=\s*(?:['\"]|[\w_]+)", re.MULTILINE)


def analyze_js_file(filepath):
    """Scan JS/TS file for performance anti-patterns."""
    findings = []
    try:
        source = filepath.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeDecodeError):
        return findings

    lines = source.split("\n")

    # Find nested loops
    findings.extend(_check_js_nested_loops(source, filepath, lines))

    # Find allocations in loops
    findings.extend(_check_js_allocations_in_loops(source, filepath, lines))

    # Find sync I/O in loops
    findings.extend(_check_js_sync_io_in_loops(source, filepath, lines))

    # Find string concatenation in loops
    findings.extend(_check_js_string_concat(source, filepath, lines))

    # Find N+1 patterns (loop with DB/API call)
    findings.extend(_check_n1_patterns(source, filepath, lines))

    return findings


def _check_js_nested_loops(source, filepath, lines):
    """Detect nested loops in JS/TS."""
    findings = []

    # Simple heuristic: find "for" or "while" lines
    for_while_lines = []
    for i, line in enumerate(lines, 1):
        if re.search(r"^\s*(for|while)\s*[\(\{]", line):
            for_while_lines.append(i)

    # Check for nested patterns: indentation increase then another loop
    for i, line_num in enumerate(for_while_lines[:-1]):
        next_line_num = for_while_lines[i + 1]
        if next_line_num > line_num + 1:
            current_indent = len(lines[line_num - 1]) - len(
                lines[line_num - 1].lstrip()
            )
            next_indent = len(lines[next_line_num - 1]) - len(
                lines[next_line_num - 1].lstrip()
            )

            if next_indent > current_indent:
                findings.append(
                    {
                        "type": "nested_loop",
                        "file": str(filepath),
                        "line": line_num,
                        "severity": "HIGH",
                        "detail": f"Nested loop at L{next_line_num} (potential O(n²))",
                        "snippet": lines[line_num - 1].strip()[:100],
                    }
                )
                break

    return findings


def _check_js_allocations_in_loops(source, filepath, lines):
    """Detect allocations inside loops in JS/TS."""
    findings = []

    for i, line_content in enumerate(lines, 1):
        if re.search(r"^\s*(for|while)\s*[\(\{]", line_content):
            # Check next 10 lines for allocations
            for j in range(i, min(i + 10, len(lines))):
                if re.search(
                    r"new\s+(Map|Set|Array|Object|WeakMap|WeakSet)|const\s+\w+\s*=\s*[\[\{]",
                    lines[j - 1],
                ):
                    findings.append(
                        {
                            "type": "allocation_in_loop",
                            "file": str(filepath),
                            "line": j,
                            "severity": "MEDIUM",
                            "detail": f"Allocation in loop at L{j}",
                            "snippet": lines[j - 1].strip()[:100],
                        }
                    )

    return findings


def _check_js_sync_io_in_loops(source, filepath, lines):
    """Detect sync I/O inside loops."""
    findings = []

    for i, line_content in enumerate(lines, 1):
        if re.search(r"^\s*(for|while)\s*[\(\{]", line_content):
            # Check next 15 lines for sync I/O
            for j in range(i, min(i + 15, len(lines))):
                if JS_SYNC_IO_PATTERN.search(lines[j - 1]):
                    findings.append(
                        {
                            "type": "sync_io_in_loop",
                            "file": str(filepath),
                            "line": j,
                            "severity": "HIGH",
                            "detail": f"Sync I/O in loop at L{j}",
                            "snippet": lines[j - 1].strip()[:100],
                        }
                    )

    return findings


def _check_js_string_concat(source, filepath, lines):
    """Detect string concatenation in loops."""
    findings = []

    for i, line_content in enumerate(lines, 1):
        if re.search(r"^\s*(for|while)\s*[\(\{]", line_content):
            # Check next 15 lines for += on strings
            for j in range(i, min(i + 15, len(lines))):
                if re.search(r"\w+\s*\+=\s*['\"]", lines[j - 1]):
                    findings.append(
                        {
                            "type": "string_concat_in_loop",
                            "file": str(filepath),
                            "line": j,
                            "severity": "MEDIUM",
                            "detail": f"String concatenation (+=) in loop at L{j}",
                            "snippet": lines[j - 1].strip()[:100],
                        }
                    )

    return findings


def _check_n1_patterns(source, filepath, lines):
    """Detect N+1 query patterns (loop with DB/API call)."""
    findings = []

    for i, line_num in enumerate(lines, 1):
        if re.search(r"^\s*(for|while)\s+", lines[i - 1]):
            # Extract loop variable
            loop_match = re.search(
                r"(?:for|while)\s+(?:(?:const|let|var)\s+)?(\w+)\s+(?:of|in|;)",
                lines[i - 1],
            )
            if loop_match:
                loop_var = loop_match.group(1)

                # Check next 20 lines for DB/API calls using loop var
                for j in range(i, min(i + 20, len(lines))):
                    line = lines[j - 1]
                    # Patterns: .find(id), .get(id), .query(), db.*, api.*
                    if re.search(
                        rf"\.(?:find|get|query|fetch|load|select|where)\s*\(\s*.*{loop_var}",
                        line,
                    ) or re.search(
                        rf"(?:db|api|query|select)\s*\(\s*.*{loop_var}", line
                    ):
                        findings.append(
                            {
                                "type": "n1_query",
                                "file": str(filepath),
                                "line": j,
                                "severity": "HIGH",
                                "detail": f"N+1 pattern: loop variable '{loop_var}' used in query at L{j}",
                                "snippet": line.strip()[:100],
                            }
                        )
                        break

    return findings


# ── Report Formatting ────────────────────────────────────────────────────────


def format_text_report(findings, root):
    """Format findings as human-readable text."""
    if not findings:
        print("No performance issues found.")
        return

    # Group by file
    by_file = defaultdict(list)
    for f in findings:
        by_file[f["file"]].append(f)

    # Sort by severity
    severity_order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    for file_findings in by_file.values():
        file_findings.sort(key=lambda x: severity_order.get(x["severity"], 99))

    # Count by severity
    severity_count = defaultdict(int)
    for f in findings:
        severity_count[f["severity"]] += 1

    print(f"Performance Analysis — {len(findings)} findings in {root}\n")

    for filepath in sorted(by_file.keys()):
        items = by_file[filepath]
        rel = os.path.relpath(filepath, root)
        print(f"── {rel} ({len(items)} findings) ──")

        for item in items:
            severity_mark = "🔴" if item["severity"] == "HIGH" else "🟡"
            print(
                f"  {severity_mark} L{item['line']:4d} [{item['severity']}] {item['type']}"
            )
            print(f"         {item['detail']}")
            if item.get("snippet"):
                print(f"         > {item['snippet']}")
        print()

    # Summary
    print("── Summary ──")
    total = len(findings)
    print(f"  {'Total findings':<40} {total:>4}")
    for severity in ["HIGH", "MEDIUM", "LOW"]:
        count = severity_count.get(severity, 0)
        if count:
            mark = "🔴" if severity == "HIGH" else "🟡"
            print(f"  {mark} {severity:<38} {count:>4}")


def format_json_report(findings):
    """Format findings as JSON."""
    # Convert Path objects to strings
    output = [
        {
            "type": f["type"],
            "file": str(f["file"]),
            "line": f["line"],
            "severity": f["severity"],
            "detail": f["detail"],
            "snippet": f.get("snippet", ""),
        }
        for f in findings
    ]
    return json.dumps(output, indent=2)


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    args = sys.argv[1:]

    # Parse arguments
    lang = "auto"
    output_format = "text"
    path_arg = None

    i = 0
    while i < len(args):
        if args[i] == "--lang" and i + 1 < len(args):
            lang = args[i + 1]
            i += 2
        elif args[i] == "--format" and i + 1 < len(args):
            output_format = args[i + 1]
            i += 2
        elif not args[i].startswith("--"):
            path_arg = args[i]
            i += 1
        else:
            i += 1

    root = Path(path_arg) if path_arg else Path.cwd()

    if not root.exists():
        print(f"Path not found: {root}", file=sys.stderr)
        sys.exit(1)

    # Determine extensions based on language
    if lang == "py":
        extensions = PY_EXTENSIONS
    elif lang == "js":
        extensions = JS_EXTENSIONS
    elif lang == "ts":
        extensions = {".ts", ".tsx"}
    else:  # auto
        extensions = PY_EXTENSIONS | JS_EXTENSIONS

    files = list(find_files(root, extensions))
    if not files:
        print(f"No source files found in {root}")
        sys.exit(0)

    findings = []

    for filepath in files:
        if filepath.suffix in PY_EXTENSIONS:
            findings.extend(analyze_python_file(filepath))
        elif filepath.suffix in JS_EXTENSIONS:
            findings.extend(analyze_js_file(filepath))

    # Sort by severity, then line number
    severity_order = {"HIGH": 0, "MEDIUM": 1, "LOW": 2}
    findings.sort(
        key=lambda x: (
            severity_order.get(x["severity"], 99),
            x["file"],
            x["line"],
        )
    )

    if output_format == "json":
        print(format_json_report(findings))
    else:
        format_text_report(findings, str(root))


if __name__ == "__main__":
    main()
