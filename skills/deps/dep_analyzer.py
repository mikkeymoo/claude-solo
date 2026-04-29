#!/usr/bin/env python3
"""Dependency analyzer: find unused packages, show imports, check versions.

Auto-detects package manager (npm, pnpm, pip, cargo) and analyzes dependencies.

Usage:
    python dep_analyzer.py                    # List all dependencies + status
    python dep_analyzer.py --unused           # Show unused packages
    python dep_analyzer.py --why PKG          # Show which files import PKG
    python dep_analyzer.py --outdated         # Check for new versions (requires pip-audit, npm outdated, cargo tree)
    python dep_analyzer.py --format json      # Machine-readable output
"""

import json
import sys
import re
from pathlib import Path
from collections import defaultdict
from typing import Dict, List, Set, Tuple, Optional


# ── Package Manager Detection ────────────────────────────────────────────────


def detect_package_manager() -> Optional[str]:
    """Detect which package manager is in use by checking for lockfiles/manifests."""
    cwd = Path.cwd()

    # Check in order of priority
    if (cwd / "pnpm-lock.yaml").exists():
        return "pnpm"
    if (cwd / "package-lock.json").exists():
        return "npm"
    if (cwd / "package.json").exists():
        return "npm"  # npm uses package.json as fallback
    if (cwd / "pyproject.toml").exists() or (cwd / "requirements.txt").exists():
        return "pip"
    if (cwd / "Cargo.toml").exists():
        return "cargo"

    return None


# ── NPM/PNPM Support ────────────────────────────────────────────────────────


def load_npm_dependencies() -> Dict[str, str]:
    """Load dependencies from package.json."""
    pkg_file = Path.cwd() / "package.json"
    if not pkg_file.exists():
        return {}

    try:
        with open(pkg_file, "r") as f:
            pkg = json.load(f)

        deps = {}
        deps.update(pkg.get("dependencies", {}))
        deps.update(pkg.get("devDependencies", {}))
        deps.update(pkg.get("optionalDependencies", {}))
        return deps
    except (json.JSONDecodeError, IOError):
        return {}


def find_npm_imports() -> Set[str]:
    """Find all npm packages imported in TypeScript/JavaScript files."""
    cwd = Path.cwd()
    imports = set()

    search_dirs = [
        d for d in [cwd / "src", cwd / "lib", cwd / "app", cwd / "pages"] if d.exists()
    ]
    if not search_dirs:
        search_dirs = [cwd]

    # Patterns for require/import statements
    patterns = [
        r"(?:require|import)\s*\(\s*['\"](@?[a-zA-Z0-9_.-]+)",  # require('pkg') or require('@org/pkg')
        r"(?:from|import)\s+['\"](@?[a-zA-Z0-9_.-]+)",  # import X from 'pkg'
        r"import\s+\*\s+as\s+\w+\s+from\s+['\"](@?[a-zA-Z0-9_.-]+)",  # import * as X from 'pkg'
    ]

    for search_dir in search_dirs:
        for file in search_dir.rglob("*"):
            if file.is_file() and file.suffix in {
                ".ts",
                ".tsx",
                ".js",
                ".jsx",
                ".mjs",
                ".cjs",
            }:
                try:
                    content = file.read_text(encoding="utf-8", errors="ignore")
                    for pattern in patterns:
                        for match in re.finditer(pattern, content):
                            pkg_name = match.group(1)
                            # Extract base package name (before first / for scoped packages)
                            if pkg_name.startswith("@"):
                                # @org/pkg -> @org/pkg
                                parts = pkg_name.split("/")
                                if len(parts) >= 2:
                                    pkg_name = f"{parts[0]}/{parts[1]}"
                            else:
                                # pkg/subpath -> pkg
                                pkg_name = pkg_name.split("/")[0]
                            imports.add(pkg_name)
                except (IOError, UnicodeDecodeError):
                    pass

    return imports


# ── Pip Support ────────────────────────────────────────────────────────────


def load_pip_dependencies() -> Dict[str, str]:
    """Load dependencies from requirements.txt or pyproject.toml."""
    deps = {}

    # Try requirements.txt first
    req_file = Path.cwd() / "requirements.txt"
    if req_file.exists():
        try:
            with open(req_file, "r") as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    # Parse requirement: pkg==1.0.0 or pkg>=1.0 etc.
                    match = re.match(r"^([a-zA-Z0-9_-]+)", line)
                    if match:
                        pkg_name = match.group(1).lower()
                        # Extract version if present
                        version = "unknown"
                        version_match = re.search(r"([=<>!~]+.+?)(?:\s|$)", line)
                        if version_match:
                            version = version_match.group(1)
                        deps[pkg_name] = version
        except IOError:
            pass

    # Also try pyproject.toml
    pyproject_file = Path.cwd() / "pyproject.toml"
    if pyproject_file.exists():
        try:
            with open(pyproject_file, "r") as f:
                content = f.read()
                in_deps = False
                for line in content.split("\n"):
                    if (
                        "[project.dependencies]" in line
                        or "[project.optional-dependencies" in line
                    ):
                        in_deps = True
                        continue
                    if in_deps and line.startswith("["):
                        in_deps = False
                    if in_deps and line.strip():
                        match = re.match(r'^["\']?([a-zA-Z0-9_-]+)', line.strip())
                        if match:
                            pkg_name = match.group(1).lower()
                            if pkg_name not in deps:
                                deps[pkg_name] = "unknown"
        except IOError:
            pass

    return deps


def find_pip_imports() -> Set[str]:
    """Find all Python packages imported in .py files."""
    cwd = Path.cwd()
    imports = set()

    search_dirs = [d for d in [cwd / "src", cwd / "lib", cwd / "app"] if d.exists()]
    if not search_dirs:
        search_dirs = [cwd]

    # Patterns for import statements
    patterns = [
        r"^(?:from|import)\s+([a-zA-Z0-9_-]+)",  # import pkg or from pkg
        r"^(?:from|import)\s+([a-zA-Z0-9_-]+\.[a-zA-Z0-9_]+)",  # from pkg.submodule
    ]

    for search_dir in search_dirs:
        for file in search_dir.rglob("*.py"):
            if file.is_file():
                try:
                    content = file.read_text(encoding="utf-8", errors="ignore")
                    for line in content.split("\n"):
                        line = line.strip()
                        for pattern in patterns:
                            match = re.match(pattern, line)
                            if match:
                                pkg_name = match.group(1).split(".")[0].lower()
                                # Normalize underscores/hyphens (setuptools convention)
                                imports.add(pkg_name)
                except (IOError, UnicodeDecodeError):
                    pass

    return imports


# ── Cargo Support ────────────────────────────────────────────────────────────


def load_cargo_dependencies() -> Dict[str, str]:
    """Load dependencies from Cargo.toml."""
    cargo_file = Path.cwd() / "Cargo.toml"
    if not cargo_file.exists():
        return {}

    deps = {}
    try:
        with open(cargo_file, "r") as f:
            content = f.read()
            in_deps = False
            for line in content.split("\n"):
                if line.startswith("[dependencies]") or line.startswith(
                    "[dev-dependencies]"
                ):
                    in_deps = True
                    continue
                if in_deps and line.startswith("["):
                    in_deps = False
                if in_deps and "=" in line and not line.startswith("#"):
                    # Parse: pkg = "0.1.0" or pkg = { version = "0.1" }
                    match = re.match(r"^([a-zA-Z0-9_-]+)\s*=", line.strip())
                    if match:
                        pkg_name = match.group(1)
                        version = "unknown"
                        version_match = re.search(r'"([^"]+)"', line)
                        if version_match:
                            version = version_match.group(1)
                        deps[pkg_name] = version
    except IOError:
        pass

    return deps


def find_cargo_imports() -> Set[str]:
    """Find all Rust crates used via 'use' statements."""
    cwd = Path.cwd()
    imports = set()

    for file in cwd.rglob("*.rs"):
        if file.is_file():
            try:
                content = file.read_text(encoding="utf-8", errors="ignore")
                for line in content.split("\n"):
                    line = line.strip()
                    # Match: use crate_name::... or use crate_name;
                    match = re.match(r"^use\s+([a-zA-Z0-9_]+)", line)
                    if match:
                        crate_name = match.group(1)
                        # Skip std and core
                        if crate_name not in {"std", "core", "alloc", "proc_macro"}:
                            imports.add(crate_name)
            except (IOError, UnicodeDecodeError):
                pass

    return imports


# ── File location tracking ────────────────────────────────────────────────────


def find_package_imports_with_locations(
    pkg_name: str, pm: str
) -> Dict[str, List[Tuple[str, int]]]:
    """Find all locations where a package is imported.

    Returns: dict[file_path] = [(import_line, line_number), ...]
    """
    locations = defaultdict(list)
    cwd = Path.cwd()

    if pm in {"npm", "pnpm"}:
        # Normalize package name for search (handle scoped packages)
        if pkg_name.startswith("@"):
            parts = pkg_name.split("/")
            search_pattern = f"{parts[0]}/{parts[1]}" if len(parts) >= 2 else pkg_name
        else:
            search_pattern = pkg_name.split("/")[0]

        search_dirs = [
            d
            for d in [cwd / "src", cwd / "lib", cwd / "app", cwd / "pages"]
            if d.exists()
        ]
        if not search_dirs:
            search_dirs = [cwd]

        for search_dir in search_dirs:
            for file in search_dir.rglob("*"):
                if file.is_file() and file.suffix in {
                    ".ts",
                    ".tsx",
                    ".js",
                    ".jsx",
                    ".mjs",
                    ".cjs",
                }:
                    try:
                        content = file.read_text(encoding="utf-8", errors="ignore")
                        for line_no, line in enumerate(content.split("\n"), 1):
                            if search_pattern in line and re.search(
                                rf"(?:require|import|from)\s*['\"].*{re.escape(search_pattern)}",
                                line,
                            ):
                                rel_path = str(file.relative_to(cwd))
                                locations[rel_path].append((line.strip(), line_no))
                    except (IOError, UnicodeDecodeError):
                        pass

    elif pm == "pip":
        search_dirs = [d for d in [cwd / "src", cwd / "lib", cwd / "app"] if d.exists()]
        if not search_dirs:
            search_dirs = [cwd]

        normalized_name = pkg_name.lower().replace("-", "_")

        for search_dir in search_dirs:
            for file in search_dir.rglob("*.py"):
                if file.is_file():
                    try:
                        content = file.read_text(encoding="utf-8", errors="ignore")
                        for line_no, line in enumerate(content.split("\n"), 1):
                            if re.search(
                                rf"(?:from|import)\s+{re.escape(normalized_name)}\b",
                                line,
                            ):
                                rel_path = str(file.relative_to(cwd))
                                locations[rel_path].append((line.strip(), line_no))
                    except (IOError, UnicodeDecodeError):
                        pass

    elif pm == "cargo":
        for file in cwd.rglob("*.rs"):
            if file.is_file():
                try:
                    content = file.read_text(encoding="utf-8", errors="ignore")
                    for line_no, line in enumerate(content.split("\n"), 1):
                        if re.search(rf"^use\s+{re.escape(pkg_name)}\b", line.strip()):
                            rel_path = str(file.relative_to(cwd))
                            locations[rel_path].append((line.strip(), line_no))
                except (IOError, UnicodeDecodeError):
                    pass

    return locations


# ── Main analysis ────────────────────────────────────────────────────────────


def analyze(pm: str) -> Tuple[Dict[str, str], Set[str], Set[str]]:
    """Analyze dependencies for given package manager.

    Returns: (all_deps, imported_packages, unused_packages)
    """
    if pm in {"npm", "pnpm"}:
        all_deps = load_npm_dependencies()
        imported = find_npm_imports()
    elif pm == "pip":
        all_deps = load_pip_dependencies()
        imported = find_pip_imports()
    elif pm == "cargo":
        all_deps = load_cargo_dependencies()
        imported = find_cargo_imports()
    else:
        return {}, set(), set()

    unused = set(all_deps.keys()) - imported
    return all_deps, imported, unused


def output_text(all_deps: Dict[str, str], imported: Set[str], unused: Set[str]):
    """Human-readable output."""
    print(f"Total dependencies: {len(all_deps)}")
    print(f"Used: {len(all_deps) - len(unused)}")
    print(f"Unused: {len(unused)}")

    if unused:
        print("\n💀 Unused packages:")
        for pkg in sorted(unused):
            print(f"  - {pkg} ({all_deps.get(pkg, 'unknown')})")
    else:
        print("\n✓ All packages are imported")


def output_json(all_deps: Dict[str, str], imported: Set[str], unused: Set[str]):
    """Machine-readable JSON output."""
    result = {
        "total": len(all_deps),
        "used": len(all_deps) - len(unused),
        "unused_count": len(unused),
        "dependencies": all_deps,
        "imported": list(imported),
        "unused": list(unused),
    }
    print(json.dumps(result, indent=2))


def main():
    args = sys.argv[1:]

    pm = detect_package_manager()
    if not pm:
        print(
            "Error: No package manager detected (npm, pnpm, pip, or cargo)",
            file=sys.stderr,
        )
        sys.exit(1)

    fmt = "text"
    if "--format" in args:
        idx = args.index("--format")
        if idx + 1 < len(args):
            fmt = args[idx + 1]

    # Handle --why flag
    if "--why" in args:
        idx = args.index("--why")
        if idx + 1 < len(args):
            pkg_name = args[idx + 1]
            locations = find_package_imports_with_locations(pkg_name, pm)

            if fmt == "json":
                result = {
                    "package": pkg_name,
                    "locations": {
                        path: [(line, line_no) for line, line_no in locs]
                        for path, locs in locations.items()
                    },
                }
                print(json.dumps(result, indent=2))
            else:
                if locations:
                    print(f"Package '{pkg_name}' is imported in:")
                    for path in sorted(locations.keys()):
                        print(f"  {path}:")
                        for line, line_no in locations[path]:
                            print(f"    :{line_no} {line}")
                else:
                    print(f"Package '{pkg_name}' is not imported anywhere")
        return

    # Main analysis
    all_deps, imported, unused = analyze(pm)

    if "--unused" in args:
        if fmt == "json":
            print(json.dumps({"unused": list(unused)}, indent=2))
        else:
            if unused:
                print("Unused packages:")
                for pkg in sorted(unused):
                    print(f"  - {pkg}")
            else:
                print("No unused packages found")
    else:
        if fmt == "json":
            output_json(all_deps, imported, unused)
        else:
            output_text(all_deps, imported, unused)


if __name__ == "__main__":
    main()
