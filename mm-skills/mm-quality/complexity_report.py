#!/usr/bin/env python3
"""Analyze code complexity: cyclomatic complexity, nesting depth, function length.

Usage:
    python complexity_report.py [path]             # Scan directory (default: cwd)
    python complexity_report.py --py-only [path]   # Python files only
    python complexity_report.py --js-only [path]   # JS/TS files only
    python complexity_report.py --threshold 10     # Custom complexity threshold (default: 10)
    python complexity_report.py --top 20           # Show top N functions (default: 15)
    python complexity_report.py --json [path]      # JSON output

Output: sorted table of complex functions with file:line references.
Zero dependencies — stdlib only.
"""

import ast
import json
import os
import re
import sys
from pathlib import Path

# ── Configuration ────────────────────────────────────────────────────────────

SKIP_DIRS = {
    ".git",
    "node_modules",
    "__pycache__",
    ".venv",
    "venv",
    "env",
    "dist",
    "build",
    ".next",
    "coverage",
    ".mypy_cache",
    ".pytest_cache",
}

PY_EXTENSIONS = {".py"}
JS_EXTENSIONS = {".js", ".jsx", ".ts", ".tsx", ".mjs", ".cjs"}

# Thresholds
DEFAULT_COMPLEXITY_THRESHOLD = 10
WARN_FUNCTION_LENGTH = 50  # lines
WARN_PARAMS = 5
WARN_NESTING = 4


# ── Python Complexity (AST-based) ────────────────────────────────────────────


class PythonComplexityVisitor(ast.NodeVisitor):
    """Compute cyclomatic complexity for Python functions/methods."""

    def __init__(self, filepath):
        self.filepath = str(filepath)
        self.functions = []
        self._class_stack = []

    def visit_ClassDef(self, node):
        self._class_stack.append(node.name)
        self.generic_visit(node)
        self._class_stack.pop()

    def visit_FunctionDef(self, node):
        self._visit_function(node)

    def visit_AsyncFunctionDef(self, node):
        self._visit_function(node)

    def _visit_function(self, node):
        complexity = self._compute_complexity(node)
        length = self._function_length(node)
        nesting = self._max_nesting(node)
        params = len(node.args.args) + len(node.args.kwonlyargs)
        if node.args.vararg:
            params += 1
        if node.args.kwarg:
            params += 1
        # Subtract 'self'/'cls' for methods
        if self._class_stack and params > 0:
            params -= 1

        name = node.name
        if self._class_stack:
            name = f"{'.'.join(self._class_stack)}.{name}"

        self.functions.append(
            {
                "name": name,
                "file": self.filepath,
                "line": node.lineno,
                "complexity": complexity,
                "length": length,
                "params": params,
                "nesting": nesting,
                "language": "python",
            }
        )

        # Visit nested functions
        old_stack = self._class_stack[:]
        self._class_stack = []
        self.generic_visit(node)
        self._class_stack = old_stack

    def _compute_complexity(self, node):
        """Cyclomatic complexity: 1 + number of decision points."""
        complexity = 1
        for child in ast.walk(node):
            if isinstance(child, (ast.If, ast.While, ast.For, ast.AsyncFor)):
                complexity += 1
            elif isinstance(child, ast.ExceptHandler):
                complexity += 1
            elif isinstance(child, ast.BoolOp):
                # Each 'and'/'or' adds a decision point
                complexity += len(child.values) - 1
            elif isinstance(child, ast.Assert):
                complexity += 1
            elif isinstance(child, ast.comprehension):
                complexity += 1
                complexity += len(child.ifs)
            elif isinstance(child, ast.Match):
                complexity += len(child.cases) - 1
        return complexity

    def _function_length(self, node):
        """Approximate function length in lines."""
        if hasattr(node, "end_lineno") and node.end_lineno:
            return node.end_lineno - node.lineno + 1
        # Fallback: count nodes
        return sum(1 for _ in ast.walk(node))

    def _max_nesting(self, node, depth=0):
        """Find maximum nesting depth."""
        max_depth = depth
        for child in ast.iter_child_nodes(node):
            if isinstance(
                child,
                (
                    ast.If,
                    ast.While,
                    ast.For,
                    ast.AsyncFor,
                    ast.With,
                    ast.AsyncWith,
                    ast.Try,
                ),
            ):
                max_depth = max(max_depth, self._max_nesting(child, depth + 1))
            else:
                max_depth = max(max_depth, self._max_nesting(child, depth))
        return max_depth


def analyze_python(filepath):
    """Analyze a Python file for complexity."""
    try:
        source = filepath.read_text(encoding="utf-8", errors="replace")
        tree = ast.parse(source, filename=str(filepath))
    except (SyntaxError, UnicodeDecodeError):
        return []

    visitor = PythonComplexityVisitor(filepath)
    visitor.visit(tree)
    return visitor.functions


# ── JS/TS Complexity (regex + heuristic) ─────────────────────────────────────

# Match function declarations/expressions/arrows
JS_FUNCTION_PATTERNS = [
    # function name(...)
    re.compile(r"^\s*(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+(\w+)\s*\("),
    # const name = (...) =>
    re.compile(r"^\s*(?:export\s+)?(?:const|let|var)\s+(\w+)\s*=\s*(?:async\s+)?\("),
    # class method: name(...)
    re.compile(r"^\s*(?:async\s+)?(\w+)\s*\([^)]*\)\s*\{"),
    # name: function(...)
    re.compile(r"^\s*(\w+)\s*:\s*(?:async\s+)?function\s*\("),
]

# Decision points in JS/TS
JS_DECISION_PATTERNS = [
    re.compile(r"\bif\s*\("),
    re.compile(r"\belse\s+if\s*\("),
    re.compile(r"\bfor\s*\("),
    re.compile(r"\bwhile\s*\("),
    re.compile(r"\bcatch\s*\("),
    re.compile(r"\bcase\s+"),
    re.compile(r"\?\s*[^:?]"),  # ternary operator
    re.compile(r"\?\?"),  # nullish coalescing
    re.compile(r"&&"),
    re.compile(r"\|\|"),
]


def analyze_js_file(filepath):
    """Analyze a JS/TS file for complexity using heuristics."""
    try:
        lines = filepath.read_text(encoding="utf-8", errors="replace").split("\n")
    except (OSError, UnicodeDecodeError):
        return []

    functions = []
    i = 0

    while i < len(lines):
        line = lines[i]
        func_name = None

        for pattern in JS_FUNCTION_PATTERNS:
            match = pattern.match(line)
            if match:
                func_name = match.group(1)
                break

        if func_name and func_name not in (
            "if",
            "else",
            "for",
            "while",
            "switch",
            "catch",
            "return",
        ):
            start_line = i + 1  # 1-indexed
            # Find the function body by tracking braces
            brace_depth = 0
            found_open = False
            end_idx = i

            for j in range(i, min(i + 500, len(lines))):
                for ch in lines[j]:
                    if ch == "{":
                        brace_depth += 1
                        found_open = True
                    elif ch == "}":
                        brace_depth -= 1

                if found_open and brace_depth <= 0:
                    end_idx = j
                    break
            else:
                end_idx = min(i + 50, len(lines) - 1)

            # Compute metrics for this function
            func_lines = lines[i : end_idx + 1]
            length = len(func_lines)
            complexity = 1  # base

            for fl in func_lines:
                for dp in JS_DECISION_PATTERNS:
                    complexity += len(dp.findall(fl))

            # Count nesting depth
            max_nesting = 0
            current_nesting = 0
            for fl in func_lines:
                current_nesting += fl.count("{") - fl.count("}")
                max_nesting = max(max_nesting, current_nesting)

            # Count params (rough)
            param_match = re.search(r"\(([^)]*)\)", line)
            params = 0
            if param_match:
                param_str = param_match.group(1).strip()
                if param_str:
                    params = len([p for p in param_str.split(",") if p.strip()])

            functions.append(
                {
                    "name": func_name,
                    "file": str(filepath),
                    "line": start_line,
                    "complexity": complexity,
                    "length": length,
                    "params": params,
                    "nesting": max_nesting,
                    "language": "js/ts",
                }
            )

            i = end_idx + 1
            continue

        i += 1

    return functions


# ── File Discovery ───────────────────────────────────────────────────────────


def find_files(root, extensions):
    """Find source files."""
    root = Path(root)
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        ]
        for fname in filenames:
            fpath = Path(dirpath) / fname
            if fpath.suffix in extensions:
                yield fpath


# ── Report ───────────────────────────────────────────────────────────────────


def print_report(functions, root, threshold, top_n):
    """Print complexity report."""
    if not functions:
        print("No functions found to analyze.")
        return

    # Sort by complexity descending
    functions.sort(key=lambda f: f["complexity"], reverse=True)

    # File-level summary
    files = set(f["file"] for f in functions)
    total_funcs = len(functions)
    complex_funcs = [f for f in functions if f["complexity"] > threshold]
    long_funcs = [f for f in functions if f["length"] > WARN_FUNCTION_LENGTH]
    many_params = [f for f in functions if f["params"] > WARN_PARAMS]
    deep_nesting = [f for f in functions if f["nesting"] > WARN_NESTING]

    print(f"Complexity Report — {total_funcs} functions in {len(files)} files")
    print(f"Threshold: complexity > {threshold}\n")

    # Top complex functions
    top = functions[:top_n]
    print(f"── Most Complex Functions (top {len(top)}) ──")
    print(
        f"  {'Function':<40} {'CC':>4} {'Len':>5} {'Params':>6} {'Nest':>5}  Location"
    )
    print(f"  {'─' * 40} {'─' * 4} {'─' * 5} {'─' * 6} {'─' * 5}  {'─' * 30}")

    for f in top:
        rel = os.path.relpath(f["file"], root)
        name = f["name"][:40]
        flag = " *" if f["complexity"] > threshold else ""
        print(
            f"  {name:<40} {f['complexity']:>4} {f['length']:>5} {f['params']:>6} {f['nesting']:>5}  {rel}:{f['line']}{flag}"
        )

    # Warnings
    if complex_funcs or long_funcs or many_params or deep_nesting:
        print("\n── Warnings ──")
        if complex_funcs:
            print(f"  Complexity > {threshold}:  {len(complex_funcs)} functions")
        if long_funcs:
            print(
                f"  Length > {WARN_FUNCTION_LENGTH} lines:  {len(long_funcs)} functions"
            )
        if many_params:
            print(f"  Params > {WARN_PARAMS}:         {len(many_params)} functions")
        if deep_nesting:
            print(f"  Nesting > {WARN_NESTING}:        {len(deep_nesting)} functions")

    # File hotspots
    file_complexity = {}
    for f in functions:
        if f["file"] not in file_complexity:
            file_complexity[f["file"]] = {"total_cc": 0, "count": 0, "max_cc": 0}
        file_complexity[f["file"]]["total_cc"] += f["complexity"]
        file_complexity[f["file"]]["count"] += 1
        file_complexity[f["file"]]["max_cc"] = max(
            file_complexity[f["file"]]["max_cc"], f["complexity"]
        )

    hotspots = sorted(
        file_complexity.items(), key=lambda x: x[1]["total_cc"], reverse=True
    )[:5]
    if hotspots:
        print("\n── File Hotspots (by total complexity) ──")
        for filepath, stats in hotspots:
            rel = os.path.relpath(filepath, root)
            avg = stats["total_cc"] / stats["count"]
            print(
                f"  {rel:<50} total={stats['total_cc']:>3}  avg={avg:.1f}  max={stats['max_cc']:>3}  funcs={stats['count']}"
            )

    # Overall stats
    all_cc = [f["complexity"] for f in functions]
    avg_cc = sum(all_cc) / len(all_cc) if all_cc else 0
    print("\n── Summary ──")
    print(f"  Total functions:    {total_funcs}")
    print(f"  Average complexity: {avg_cc:.1f}")
    print(f"  Max complexity:     {max(all_cc) if all_cc else 0}")
    print(f"  Over threshold:     {len(complex_funcs)}")

    if not complex_funcs:
        print(
            f"\n  All functions are within complexity threshold ({threshold}). Code looks healthy."
        )


def print_json_report(functions, root):
    """Print JSON output."""
    output = {
        "root": str(root),
        "total_functions": len(functions),
        "functions": [
            {
                "name": f["name"],
                "file": os.path.relpath(f["file"], root),
                "line": f["line"],
                "complexity": f["complexity"],
                "length": f["length"],
                "params": f["params"],
                "nesting": f["nesting"],
                "language": f["language"],
            }
            for f in sorted(functions, key=lambda x: x["complexity"], reverse=True)
        ],
    }
    print(json.dumps(output, indent=2))


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    args = sys.argv[1:]

    py_only = "--py-only" in args
    js_only = "--js-only" in args
    json_output = "--json" in args
    threshold = DEFAULT_COMPLEXITY_THRESHOLD
    top_n = 15

    if "--threshold" in args:
        idx = args.index("--threshold")
        if idx + 1 < len(args):
            try:
                threshold = int(args[idx + 1])
            except ValueError:
                pass

    if "--top" in args:
        idx = args.index("--top")
        if idx + 1 < len(args):
            try:
                top_n = int(args[idx + 1])
            except ValueError:
                pass

    path_args = [
        a
        for a in args
        if not a.startswith("--") and a not in (str(threshold), str(top_n))
    ]
    root = Path(path_args[0]) if path_args else Path.cwd()

    if not root.exists():
        print(f"Path not found: {root}", file=sys.stderr)
        sys.exit(1)

    if py_only:
        extensions = PY_EXTENSIONS
    elif js_only:
        extensions = JS_EXTENSIONS
    else:
        extensions = PY_EXTENSIONS | JS_EXTENSIONS

    functions = []
    for filepath in find_files(root, extensions):
        if filepath.suffix in PY_EXTENSIONS:
            functions.extend(analyze_python(filepath))
        elif filepath.suffix in JS_EXTENSIONS:
            functions.extend(analyze_js_file(filepath))

    if json_output:
        print_json_report(functions, root)
    else:
        print_report(functions, str(root), threshold, top_n)


if __name__ == "__main__":
    main()
