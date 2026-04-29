#!/usr/bin/env python3
"""Scan files for hardcoded secrets, API keys, tokens, and high-entropy strings.

Usage:
    python secrets_scanner.py [path]              # Scan directory (default: cwd)
    python secrets_scanner.py --entropy [path]     # Include entropy analysis
    python secrets_scanner.py --strict [path]      # Lower thresholds, more findings
    python secrets_scanner.py --json [path]        # JSON output

Output: findings with severity labels and file:line references.
Zero dependencies — stdlib only.
"""

import json as json_mod
import math
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
    "dist",
    "build",
    ".next",
    "coverage",
    ".mypy_cache",
    ".pytest_cache",
}

SKIP_EXTENSIONS = {
    ".png",
    ".jpg",
    ".jpeg",
    ".gif",
    ".ico",
    ".svg",
    ".woff",
    ".woff2",
    ".ttf",
    ".eot",
    ".mp3",
    ".mp4",
    ".zip",
    ".tar",
    ".gz",
    ".bz2",
    ".exe",
    ".dll",
    ".so",
    ".dylib",
    ".pyc",
    ".pyo",
    ".class",
    ".lock",
    ".sum",
}

# Files that legitimately contain secret-like patterns
SKIP_FILES = {
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "Cargo.lock",
    "poetry.lock",
    "Pipfile.lock",
    "go.sum",
}

# ── Secret Patterns ──────────────────────────────────────────────────────────

SECRET_PATTERNS = [
    # AWS
    {
        "name": "AWS Access Key ID",
        "pattern": re.compile(r"(?:^|['\"\s=:])?(AKIA[0-9A-Z]{16})(?:['\"\s,;]|$)"),
        "severity": "CRITICAL",
    },
    {
        "name": "AWS Secret Access Key",
        "pattern": re.compile(
            r"(?:aws_secret_access_key|secret_key)\s*[=:]\s*['\"]?([A-Za-z0-9/+=]{40})['\"]?"
        ),
        "severity": "CRITICAL",
    },
    # GitHub
    {
        "name": "GitHub Token (classic)",
        "pattern": re.compile(r"(?:^|['\"\s=:])(ghp_[A-Za-z0-9]{36,})"),
        "severity": "CRITICAL",
    },
    {
        "name": "GitHub Token (fine-grained)",
        "pattern": re.compile(r"(?:^|['\"\s=:])(github_pat_[A-Za-z0-9_]{22,})"),
        "severity": "CRITICAL",
    },
    # Slack
    {
        "name": "Slack Bot Token",
        "pattern": re.compile(r"(xoxb-[0-9]{10,13}-[0-9]{10,13}-[A-Za-z0-9]{24,})"),
        "severity": "CRITICAL",
    },
    {
        "name": "Slack Webhook",
        "pattern": re.compile(
            r"(https://hooks\.slack\.com/services/T[A-Z0-9]+/B[A-Z0-9]+/[A-Za-z0-9]+)"
        ),
        "severity": "HIGH",
    },
    # Generic API Keys
    {
        "name": "Generic API Key",
        "pattern": re.compile(
            r"""(?:api[_-]?key|apikey|api[_-]?secret)\s*[=:]\s*['\"]([A-Za-z0-9_\-]{20,})['\"]""",
            re.IGNORECASE,
        ),
        "severity": "HIGH",
    },
    # Generic Secret/Token
    {
        "name": "Generic Secret",
        "pattern": re.compile(
            r"""(?:secret|token|password|passwd|pwd)\s*[=:]\s*['\"]([A-Za-z0-9_\-!@#$%^&*]{8,})['\"]""",
            re.IGNORECASE,
        ),
        "severity": "HIGH",
    },
    # Private Keys
    {
        "name": "Private Key Header",
        "pattern": re.compile(
            r"-----BEGIN (?:RSA |EC |DSA |OPENSSH )?PRIVATE KEY-----"
        ),
        "severity": "CRITICAL",
    },
    # Database URLs with credentials
    {
        "name": "Database URL with Password",
        "pattern": re.compile(
            r"(?:postgres|mysql|mongodb|redis)://[^:]+:([^@\s]{4,})@[^/\s]+"
        ),
        "severity": "CRITICAL",
    },
    # JWT Secrets
    {
        "name": "JWT Secret",
        "pattern": re.compile(
            r"""(?:jwt[_-]?secret|jwt[_-]?key)\s*[=:]\s*['\"]([A-Za-z0-9_\-]{16,})['\"]""",
            re.IGNORECASE,
        ),
        "severity": "CRITICAL",
    },
    # Anthropic
    {
        "name": "Anthropic API Key",
        "pattern": re.compile(r"(?:^|['\"\s=:])(sk-ant-[A-Za-z0-9\-_]{80,})"),
        "severity": "CRITICAL",
    },
    # OpenAI
    {
        "name": "OpenAI API Key",
        "pattern": re.compile(r"(?:^|['\"\s=:])(sk-[A-Za-z0-9]{48,})"),
        "severity": "CRITICAL",
    },
    # Google
    {
        "name": "Google API Key",
        "pattern": re.compile(r"(?:^|['\"\s=:])(AIza[A-Za-z0-9_\-]{35})"),
        "severity": "HIGH",
    },
    # Stripe
    {
        "name": "Stripe Secret Key",
        "pattern": re.compile(r"(?:^|['\"\s=:])(sk_live_[A-Za-z0-9]{24,})"),
        "severity": "CRITICAL",
    },
    {
        "name": "Stripe Publishable Key",
        "pattern": re.compile(r"(?:^|['\"\s=:])(pk_live_[A-Za-z0-9]{24,})"),
        "severity": "MEDIUM",
    },
    # SendGrid
    {
        "name": "SendGrid API Key",
        "pattern": re.compile(
            r"(?:^|['\"\s=:])(SG\.[A-Za-z0-9_\-]{22,}\.[A-Za-z0-9_\-]{43,})"
        ),
        "severity": "CRITICAL",
    },
    # Twilio
    {
        "name": "Twilio Auth Token",
        "pattern": re.compile(
            r"""(?:twilio[_-]?auth[_-]?token)\s*[=:]\s*['\"]([a-f0-9]{32})['\"]""",
            re.IGNORECASE,
        ),
        "severity": "CRITICAL",
    },
    # Hardcoded passwords in connection strings
    {
        "name": "Hardcoded Password",
        "pattern": re.compile(
            r"""password\s*[=:]\s*['\"](?!<|{|\$|%|password|changeme|placeholder|xxx|example)([^'\"]{8,})['\"]""",
            re.IGNORECASE,
        ),
        "severity": "HIGH",
    },
]

# Patterns that indicate a false positive (placeholder values)
FALSE_POSITIVE_PATTERNS = [
    re.compile(r"your[_-]?(api[_-]?)?key", re.IGNORECASE),
    re.compile(r"<[A-Z_]+>"),  # placeholder like <API_KEY>
    re.compile(r"\$\{"),  # template variable
    re.compile(r"process\.env"),
    re.compile(r"os\.environ"),
    re.compile(r"os\.getenv"),
    re.compile(r"xxx+", re.IGNORECASE),
    re.compile(r"placeholder", re.IGNORECASE),
    re.compile(r"example", re.IGNORECASE),
    re.compile(r"changeme", re.IGNORECASE),
    re.compile(r"TODO", re.IGNORECASE),
]


# ── Entropy Analysis ─────────────────────────────────────────────────────────


def shannon_entropy(s):
    """Calculate Shannon entropy of a string."""
    if not s:
        return 0.0
    freq = defaultdict(int)
    for c in s:
        freq[c] += 1
    length = len(s)
    return -sum((count / length) * math.log2(count / length) for count in freq.values())


def find_high_entropy_strings(line, line_num, filepath, threshold=4.5):
    """Find high-entropy strings that might be secrets."""
    findings = []
    # Match quoted strings of 16+ chars
    for match in re.finditer(r"""['\"]([A-Za-z0-9+/=_\-]{16,})['\"]""", line):
        value = match.group(1)
        entropy = shannon_entropy(value)
        if entropy >= threshold and len(value) >= 20:
            # Skip if it looks like a known false positive
            context = line[max(0, match.start() - 30) : match.start()]
            if any(
                fp.search(context) or fp.search(value) for fp in FALSE_POSITIVE_PATTERNS
            ):
                continue
            findings.append(
                {
                    "name": f"High-Entropy String (entropy={entropy:.1f})",
                    "file": str(filepath),
                    "line": line_num,
                    "detail": f"'{value[:40]}...' (len={len(value)}, entropy={entropy:.1f})",
                    "severity": "MEDIUM",
                }
            )
    return findings


# ── File Scanning ────────────────────────────────────────────────────────────


def should_skip(filepath):
    """Check if a file should be skipped."""
    if filepath.name in SKIP_FILES:
        return True
    if filepath.suffix in SKIP_EXTENSIONS:
        return True
    # Skip .env.example (it's supposed to have placeholders)
    if filepath.name == ".env.example":
        return True
    return False


def scan_file(filepath, include_entropy=False, strict=False):
    """Scan a single file for secrets."""
    findings = []
    try:
        content = filepath.read_text(encoding="utf-8", errors="replace")
    except (OSError, UnicodeDecodeError):
        return findings

    lines = content.split("\n")
    entropy_threshold = 4.0 if strict else 4.5

    for i, line in enumerate(lines, 1):
        # Skip lines that are clearly not secrets
        stripped = line.strip()
        if not stripped or (
            stripped.startswith("//") and "secret" not in stripped.lower()
        ):
            continue

        # Check against known patterns
        for pattern_info in SECRET_PATTERNS:
            match = pattern_info["pattern"].search(line)
            if match:
                # Check for false positives
                if any(fp.search(line) for fp in FALSE_POSITIVE_PATTERNS):
                    continue
                # Check if in a test/mock file
                fstr = str(filepath)
                if any(
                    x in fstr
                    for x in [
                        "/test",
                        ".test.",
                        ".spec.",
                        "/mock",
                        "/fixture",
                        "__test__",
                    ]
                ):
                    continue

                findings.append(
                    {
                        "name": pattern_info["name"],
                        "file": str(filepath),
                        "line": i,
                        "detail": f"Match in: {stripped[:80]}",
                        "severity": pattern_info["severity"],
                    }
                )

        # Entropy analysis
        if include_entropy:
            findings.extend(
                find_high_entropy_strings(line, i, filepath, entropy_threshold)
            )

    return findings


def scan_directory(root, include_entropy=False, strict=False):
    """Scan a directory recursively."""
    root = Path(root)
    findings = []

    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [
            d for d in dirnames if d not in SKIP_DIRS and not d.startswith(".")
        ]

        for fname in filenames:
            fpath = Path(dirpath) / fname
            if should_skip(fpath):
                continue
            # Skip very large files (likely generated) but always scan .env files
            try:
                if fpath.stat().st_size > 1_000_000 and not fpath.name.startswith(
                    ".env"
                ):
                    continue
            except OSError:
                continue

            findings.extend(scan_file(fpath, include_entropy, strict))

    return findings


# ── .env File Check ──────────────────────────────────────────────────────────


def check_env_files(root):
    """Check for .env files and whether they're gitignored."""
    findings = []
    root = Path(root)

    env_files = list(root.glob(".env")) + list(root.glob(".env.*"))
    env_files = [f for f in env_files if f.name != ".env.example" and f.is_file()]

    for env_file in env_files:
        # Check if gitignored
        try:
            result = subprocess.run(
                ["git", "check-ignore", str(env_file)],
                capture_output=True,
                text=True,
                timeout=5,
                cwd=str(root),
            )
            is_ignored = result.returncode == 0
        except (subprocess.TimeoutExpired, FileNotFoundError):
            is_ignored = False

        if not is_ignored:
            findings.append(
                {
                    "name": "Unignored .env File",
                    "file": str(env_file),
                    "line": 0,
                    "detail": f"{env_file.name} is NOT in .gitignore — secrets may be committed",
                    "severity": "CRITICAL",
                }
            )

    return findings


# ── Report ───────────────────────────────────────────────────────────────────

SEVERITY_ORDER = {"CRITICAL": 0, "HIGH": 1, "MEDIUM": 2, "LOW": 3}
SEVERITY_ICONS = {"CRITICAL": "[!!]", "HIGH": "[!]", "MEDIUM": "[~]", "LOW": "[.]"}


def print_report(findings, root):
    """Print findings report."""
    if not findings:
        print("No secrets found. Clean scan.")
        return

    # Sort by severity
    findings.sort(key=lambda f: SEVERITY_ORDER.get(f["severity"], 99))

    # Group by severity
    by_severity = defaultdict(list)
    for f in findings:
        by_severity[f["severity"]].append(f)

    total = len(findings)
    print(f"Secrets Scan — {total} findings in {root}\n")

    for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        items = by_severity.get(severity, [])
        if not items:
            continue

        icon = SEVERITY_ICONS[severity]
        print(f"── {icon} {severity} ({len(items)}) ──")
        for item in items[:20]:
            rel = os.path.relpath(item["file"], root)
            loc = f"{rel}:{item['line']}" if item["line"] > 0 else rel
            print(f"  {loc}")
            print(f"    {item['name']}: {item['detail'][:100]}")
        if len(items) > 20:
            print(f"  ... and {len(items) - 20} more")
        print()

    # Summary
    print("── Summary ──")
    for severity in ["CRITICAL", "HIGH", "MEDIUM", "LOW"]:
        count = len(by_severity.get(severity, []))
        if count:
            print(f"  {severity:<12} {count:>4}")
    print(f"  {'Total':<12} {total:>4}")

    critical = len(by_severity.get("CRITICAL", []))
    if critical > 0:
        print(
            f"\n  Action required: {critical} CRITICAL findings must be resolved before shipping."
        )


def print_json(findings, root):
    """Print findings as JSON."""
    output = {
        "root": str(root),
        "total": len(findings),
        "findings": [
            {
                "severity": f["severity"],
                "name": f["name"],
                "file": os.path.relpath(f["file"], root),
                "line": f["line"],
                "detail": f["detail"],
            }
            for f in findings
        ],
    }
    print(json_mod.dumps(output, indent=2))


# ── Main ─────────────────────────────────────────────────────────────────────


def main():
    args = sys.argv[1:]

    include_entropy = "--entropy" in args
    strict = "--strict" in args
    json_output = "--json" in args

    path_args = [a for a in args if not a.startswith("--")]
    root = Path(path_args[0]) if path_args else Path.cwd()

    if not root.exists():
        print(f"Path not found: {root}", file=sys.stderr)
        sys.exit(1)

    findings = []

    if root.is_file():
        findings.extend(scan_file(root, include_entropy, strict))
    else:
        findings.extend(scan_directory(root, include_entropy, strict))
        findings.extend(check_env_files(root))

    if json_output:
        print_json(findings, str(root))
    else:
        print_report(findings, str(root))

    # Exit code: 1 if CRITICAL findings
    if any(f["severity"] == "CRITICAL" for f in findings):
        sys.exit(1)


if __name__ == "__main__":
    main()
