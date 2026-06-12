#!/usr/bin/env python3
"""Scan a codebase for dead code, stale TODOs, and commented-out blocks.

Usage:
    python dead_code_scanner.py [path]           # Scan directory (default: cwd)
    python dead_code_scanner.py --py-only [path] # Python files only
    python dead_code_scanner.py --js-only [path] # JS/TS files only
    python dead_code_scanner.py --todos [path]   # Stale TODOs only
    python dead_code_scanner.py --commented [path]  # Commented-out code only

Output: categorized findings with file:line references.
Zero dependencies — stdlib only.
"""

import ast
import os
import re
import subprocess
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
    "*.egg-info",
}

PY_EXTENSIONS = {".py"}
JS_EXTENSIONS = {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs"}

# Patterns that indicate commented-out code (not regular comments)
CODE_COMMENT_PATTERNS = [
    re.compile(
        r"^\s*#\s*(def |class |import |from |return |if |for |while |try:|except|raise )"
    ),
    re.compile(r"^\s*#\s*\w+\s*[=(]"),  # variable assignment or function call
    re.compile(
        r"^\s*//\s*(function |const |let |var |import |export |return |if |for |while |try |catch)"
    ),
    re.compile(r"^\s*//\s*\w+\s*[=(]"),
]

# TODO/FIXME pattern
TODO_PATTERN = re.compile(
    r"(?:#|//|/\*|\*)\s*(TODO|FIXME|HACK|XXX|TEMP|TEMPORARY)\b[:\s]*(.*)",
    re.IGNORECASE,
)


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


# ── Python Dead Code Analysis (AST-based) ───────────────────────────────────


def analyze_python_file(filepath):
    """Use AST to find potential dead code in a Python file."""
    findings = []
    try:
        source = filepath.read_text(encoding="utf-8", errors="replace")
        tree = ast.parse(source, filename=str(filepath))
    except (SyntaxError, UnicodeDecodeError):
        return findings

    # Collect all defined names and their line numbers
    defined = {}  # name -> (line, type)
    imported = {}  # name -> line
    used_names = set()

    for node in ast.walk(tree):
        # Track definitions
        if isinstance(node, ast.FunctionDef):
            if not node.name.startswith("_") or node.name == "__init__":
                defined[node.name] = (node.lineno, "function")
        elif isinstance(node, ast.ClassDef):
            defined[node.name] = (node.lineno, "class")
        elif isinstance(node, ast.Assign):
            for target in node.targets:
                if isinstance(target, ast.Name) and target.id.isupper():
                    # Skip module-level constants (likely used externally)
                    pass

        # Track imports
        if isinstance(node, ast.Import):
            for alias in node.names:
                name = alias.asname or alias.name.split(".")[0]
                imported[name] = node.lineno
        elif isinstance(node, ast.ImportFrom):
            for alias in node.names:
                if alias.name != "*":
                    name = alias.asname or alias.name
                    imported[name] = node.lineno

        # Track name usage
        if isinstance(node, ast.Name):
            used_names.add(node.id)
        elif isinstance(node, ast.Attribute):
            if isinstance(node.value, ast.Name):
                used_names.add(node.value.id)

    # Find unused imports
    for name, line in imported.items():
        if name not in used_names and name != "__all__":
            findings.append(
                {
                    "type": "unused_import",
                    "file": str(filepath),
                    "line": line,
                    "detail": f"Unused import: {name}",
                }
            )

    # Build a map of decorated names (decorators often register functions)
    decorated_names = set()
    for node in ast.walk(tree):
        if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef, ast.ClassDef)):
            if hasattr(node, "decorator_list") and node.decorator_list:
                decorated_names.add(node.name)

    # Find potentially unused functions (heuristic — can't catch all usage)
    for name, (line, kind) in defined.items():
        if name not in used_names and not name.startswith("test_"):
            # Skip decorated definitions (decorators often register functions)
            if name in decorated_names:
                continue
            findings.append(
                {
                    "type": f"potentially_unused_{kind}",
                    "file": str(filepath),
                    "line": line,
                    "detail": f"Potentially unused {kind}: {name}",
                }
            )

    return findings


# ── JS/TS Dead Code Analysis (regex-based) ──────────────────────────────────

# Patterns for JS/TS exports and declarations
JS_EXPORT_PATTERN = re.compile(
    r"^\s*export\s+(?:default\s+)?(?:function|class|const|let|var|interface|type|enum)\s+(\w+)",
    re.MULTILINE,
)
JS_CONSOLE_PATTERN = re.compile(
    r"\bconsole\.(log|debug|info|warn|error)\s*\(", re.MULTILINE
)
JS_DEBUGGER_PATTERN = re.compile(r"^\s*debugger\s*;?\s*$", re.MULTILINE)


def analyze_js_file(filepath):
    """Find potential dead code in JS/TS files."""
    findings = []
    try:
        source = filepath.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeDecodeError):
        return findings

    lines = source.split("\n")

    # Find console.log statements (likely debug leftovers)
    for i, line in enumerate(lines, 1):
        if JS_CONSOLE_PATTERN.search(line):
            # Skip if in test files
            if (
                "/test" in str(filepath)
                or ".test." in str(filepath)
                or ".spec." in str(filepath)
            ):
                continue
            findings.append(
                {
                    "type": "debug_statement",
                    "file": str(filepath),
                    "line": i,
                    "detail": f"console statement: {line.strip()[:80]}",
                }
            )

    # Find debugger statements
    for i, line in enumerate(lines, 1):
        if JS_DEBUGGER_PATTERN.match(line):
            findings.append(
                {
                    "type": "debugger_statement",
                    "file": str(filepath),
                    "line": i,
                    "detail": "debugger statement left in code",
                }
            )

    return findings


# ── Commented-Out Code Detection ─────────────────────────────────────────────


def find_commented_code(filepath):
    """Find blocks of commented-out code (3+ consecutive lines)."""
    findings = []
    try:
        lines = filepath.read_text(encoding="utf-8", errors="replace").split("\n")
    except (OSError, UnicodeDecodeError):
        return findings

    consecutive = 0
    block_start = 0

    for i, line in enumerate(lines, 1):
        is_code_comment = any(p.match(line) for p in CODE_COMMENT_PATTERNS)
        if is_code_comment:
            if consecutive == 0:
                block_start = i
            consecutive += 1
        else:
            if consecutive >= 3:
                findings.append(
                    {
                        "type": "commented_code",
                        "file": str(filepath),
                        "line": block_start,
                        "detail": f"Commented-out code block ({consecutive} lines, L{block_start}-{block_start + consecutive - 1})",
                    }
                )
            consecutive = 0

    # Handle block at end of file
    if consecutive >= 3:
        findings.append(
            {
                "type": "commented_code",
                "file": str(filepath),
                "line": block_start,
                "detail": f"Commented-out code block ({consecutive} lines, L{block_start}-{block_start + consecutive - 1})",
            }
        )

    return findings


# ── Stale TODO Detection ────────────────────────────────────────────────────


def find_stale_todos(filepath, max_age_days=30):
    """Find TODOs/FIXMEs and check their age via git blame."""
    findings = []
    try:
        lines = filepath.read_text(encoding="utf-8", errors="replace").split("\n")
    except (OSError, UnicodeDecodeError):
        return findings

    for i, line in enumerate(lines, 1):
        match = TODO_PATTERN.search(line)
        if match:
            tag = match.group(1).upper()
            text = match.group(2).strip()[:80]
            age_info = _get_line_age(filepath, i)
            findings.append(
                {
                    "type": "todo",
                    "file": str(filepath),
                    "line": i,
                    "detail": f"{tag}: {text}"
                    + (f" (last modified: {age_info})" if age_info else ""),
                    "age": age_info,
                }
            )

    return findings


def _get_line_age(filepath, line_num):
    """Get the age of a specific line using git blame."""
    try:
        result = subprocess.run(
            [
                "git",
                "blame",
                "-L",
                f"{line_num},{line_num}",
                "--porcelain",
                str(filepath),
            ],
            capture_output=True,
            text=True,
            timeout=5,
        )
        if result.returncode == 0:
            for blame_line in result.stdout.split("\n"):
                if blame_line.startswith("author-time "):
                    import datetime

                    ts = int(blame_line.split()[1])
                    dt = datetime.datetime.fromtimestamp(ts)
                    return dt.strftime("%Y-%m-%d")
    except (subprocess.TimeoutExpired, FileNotFoundError, ValueError):
        pass
    return None


# ── Report Formatting ────────────────────────────────────────────────────────


def print_report(findings, root):
    """Print categorized findings report."""
    if not findings:
        print("No dead code findings.")
        return

    # Group by type
    by_type = defaultdict(list)
    for f in findings:
        by_type[f["type"]].append(f)

    type_labels = {
        "unused_import": "Unused Imports",
        "potentially_unused_function": "Potentially Unused Functions",
        "potentially_unused_class": "Potentially Unused Classes",
        "debug_statement": "Debug Statements (console.*)",
        "debugger_statement": "Debugger Statements",
        "commented_code": "Commented-Out Code Blocks",
        "todo": "TODOs / FIXMEs",
    }

    total = len(findings)
    print(f"Dead Code Scan — {total} findings in {root}\n")

    for type_key, label in type_labels.items():
        items = by_type.get(type_key, [])
        if not items:
            continue

        print(f"── {label} ({len(items)}) ──")
        for item in items[:25]:  # Cap output per category
            rel = os.path.relpath(item["file"], root)
            print(f"  {rel}:{item['line']}  {item['detail']}")
        if len(items) > 25:
            print(f"  ... and {len(items) - 25} more")
        print()

    # Summary
    print("── Summary ──")
    for type_key, label in type_labels.items():
        count = len(by_type.get(type_key, []))
        if count:
            print(f"  {label:<40} {count:>4}")
    print(f"  {'Total':<40} {total:>4}")


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    args = sys.argv[1:]

    py_only = "--py-only" in args
    js_only = "--js-only" in args
    todos_only = "--todos" in args
    commented_only = "--commented" in args

    # Remove flags to find path
    path_args = [a for a in args if not a.startswith("--")]
    root = Path(path_args[0]) if path_args else Path.cwd()

    if not root.exists():
        print(f"Path not found: {root}", file=sys.stderr)
        sys.exit(1)

    # Determine which extensions to scan
    if py_only:
        extensions = PY_EXTENSIONS
    elif js_only:
        extensions = JS_EXTENSIONS
    else:
        extensions = PY_EXTENSIONS | JS_EXTENSIONS

    files = list(find_files(root, extensions))
    if not files:
        print(f"No source files found in {root}")
        sys.exit(0)

    findings = []

    for filepath in files:
        if not todos_only and not commented_only:
            if filepath.suffix in PY_EXTENSIONS:
                findings.extend(analyze_python_file(filepath))
            elif filepath.suffix in JS_EXTENSIONS:
                findings.extend(analyze_js_file(filepath))

        if not todos_only:
            findings.extend(find_commented_code(filepath))

        if not commented_only:
            findings.extend(find_stale_todos(filepath))

    print_report(findings, str(root))


if __name__ == "__main__":
    main()
