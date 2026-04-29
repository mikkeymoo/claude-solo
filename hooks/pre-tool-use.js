#!/usr/bin/env node
/**
 * claude-solo pre-tool-use hook
 *
 * 1. Warns about potentially dangerous commands (stderr, advisory only)
 * 2. Auto-wraps supported commands with `rtk` prefix for token savings.
 *    RTK's shell-level hook is Unix-only; this provides the same benefit
 *    on Windows via Claude Code's updatedInput mechanism.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): updatedInput when rtk wrapping applied, otherwise { action: 'continue' }
 */

import { createInterface } from "readline";

// ── Conventional Commits validation ────────────────────────────────────────
const CONVENTIONAL_COMMIT_PATTERN =
  /^(feat|fix|docs|style|refactor|test|chore|perf|ci|build|revert)(\(.+\))?: .{1,100}$/;
const VALID_TYPES = [
  "feat",
  "fix",
  "docs",
  "style",
  "refactor",
  "test",
  "chore",
  "perf",
  "ci",
  "build",
  "revert",
];

/**
 * Extract commit message from various git commit formats.
 * Handles: -m "msg", -m 'msg', --message="msg", $(cat <<EOF...EOF)
 */
function extractCommitMessage(cmd) {
  // Skip if --no-verify or -n flag present (bypass enforcement)
  if (/--no-verify|-[a-zA-Z]*n[a-zA-Z]*\b/.test(cmd)) {
    return null;
  }

  // Match -m "message", -m 'message', --message="message"
  const shortMatch = cmd.match(/(?:^|\s)-m\s+["'](.+?)["']/);
  if (shortMatch) {
    return shortMatch[1];
  }

  const longMatch = cmd.match(/--message\s*=\s*["'](.+?)["']/);
  if (longMatch) {
    return longMatch[1];
  }

  // Match heredoc format: $(cat <<'EOF'\nmessage\nEOF) or $(cat <<EOF\nmessage\nEOF)
  const heredocMatch = cmd.match(
    /\$\(cat\s+<<['"]?(\w+)['"]?\s*\n([\s\S]*?)\n\1\)/,
  );
  if (heredocMatch) {
    return heredocMatch[2].trim();
  }

  // No -m or --message flag found; skip enforcement (interactive commit)
  return null;
}

/**
 * Validate commit message against Conventional Commits format.
 */
function isValidConventionalCommit(message) {
  return CONVENTIONAL_COMMIT_PATTERN.test(message);
}

/**
 * Suggest a conventional commit based on the provided message.
 */
function suggestConventionalCommit(message) {
  const trimmed = message.trim();
  if (!trimmed) return null;

  // Simple heuristic: prepend 'chore:' if message doesn't match pattern
  if (!CONVENTIONAL_COMMIT_PATTERN.test(trimmed)) {
    return `chore: ${trimmed}`;
  }
  return null;
}

// Commands rtk supports — auto-wrap these for token savings
const RTK_PATTERNS = [
  /^git\s/,
  /^gh\s+(pr|run|issue|api)\b/,
  /^pnpm\b/,
  /^npm\b/,
  /^npx\b/,
  /^cargo\s+(test|build|check|clippy)\b/,
  /^python\s+-m\s+pytest\b/,
  /^vitest\b/,
  /^playwright\s+test\b/,
  /^tsc\b/,
  /^next\s+(build|dev)\b/,
  /^docker\s+(ps|images|logs)\b/,
  /^kubectl\s+(get|logs)\b/,
  /^lint\b/,
  /^prettier\b/,
];

function needsRtk(segment) {
  const trimmed = segment.trim();
  if (!trimmed || /^rtk\s/.test(trimmed)) return false;
  return RTK_PATTERNS.some((p) => p.test(trimmed));
}

// Wrap each && segment independently, preserving whitespace
function applyRtk(command) {
  // Split on && boundaries, keeping separators
  const parts = command.split(/(\s*&&\s*)/);
  let modified = false;
  const out = parts.map((part) => {
    if (/^\s*&&\s*$/.test(part)) return part;
    if (needsRtk(part)) {
      modified = true;
      return part.replace(/^(\s*)/, "$1rtk ");
    }
    return part;
  });
  return { command: out.join(""), modified };
}

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  const { tool_name, tool_input } = input;

  if (
    tool_name === "Bash" ||
    tool_name === "mcp__desktop-commander__start_process"
  ) {
    const rawCmd = tool_input?.command || tool_input?.cmd || "";
    const cmdLower = rawCmd.toLowerCase();

    // ── Danger warnings (advisory, never blocks) ──────────────────────────
    const warnings = [
      // Filesystem destruction
      { pattern: /rm\s+-rf\s+\/(?!tmp)/, reason: "Deleting from root" },
      {
        pattern: /rm\s+(-\w+\s+)*--no-preserve-root/,
        reason: "Bypassing root preservation guard",
      },

      // Git danger
      {
        pattern: /git\s+push\s+(?!.*--dry-run)(--force|-f)/,
        reason: "Force-pushing (overwrites remote history)",
      },
      {
        pattern: /git\s+reset\s+--hard/,
        reason: "Hard reset discards uncommitted work",
      },
      {
        pattern: /git\s+clean\s+(?!.*-n)(?!.*--dry-run).*-\w*f/,
        reason: "git clean -f removes untracked files permanently",
      },

      // Database
      { pattern: /drop\s+table/, reason: "Dropping database table" },
      { pattern: /drop\s+database/, reason: "Dropping entire database" },
      {
        pattern: /delete\s+from\s+\w+\s*(?:;|"|'|$)(?!\s+where)/i,
        reason: "DELETE without WHERE clause",
      },
      { pattern: /truncate\s+table/, reason: "TRUNCATE is irreversible" },

      // Process control
      {
        pattern: /pkill\s+-9|kill\s+-9/,
        reason: "SIGKILL forcefully terminates processes (no cleanup)",
      },
      {
        pattern: /killall\s+-9/,
        reason: "SIGKILL to all matching processes (no cleanup)",
      },

      // Permissions
      {
        pattern: /chmod\s+-r\s+777|chmod\s+777\s+-r|chmod\s+a\+rwx\s+-r/,
        reason: "World-writable recursive permission change",
      },
      {
        pattern: /chmod\s+777\s+\/|chmod\s+777\s+~/,
        reason: "World-writable on root or home directory",
      },

      // Remote code execution
      {
        pattern: /curl\s+.+\|\s*(ba)?sh|wget\s+.+\|\s*(ba)?sh/,
        reason: "Piping remote content directly to shell (RCE risk)",
      },
      {
        pattern: /curl\s+.+\|\s*node|wget\s+.+\|\s*node/,
        reason: "Piping remote content directly to Node (RCE risk)",
      },

      // Disk write
      {
        pattern: /\bdd\s+if=/,
        reason: "Direct disk write (dd) — can destroy data",
      },

      // Publishing
      {
        pattern: /npm\s+publish(?!\s+--dry-run)/,
        reason: "Publishing to npm registry (use --dry-run first)",
      },
      {
        pattern: /cargo\s+publish(?!\s+--dry-run)/,
        reason: "Publishing to crates.io (use --dry-run first)",
      },
      {
        pattern:
          /pip\s+install\s+--upload|twine\s+upload(?!\s+--repository\s+testpypi)/,
        reason: "Publishing to PyPI",
      },
    ];

    for (const { pattern, reason } of warnings) {
      if (pattern.test(cmdLower)) {
        process.stderr.write(`⚠️  claude-solo: ${reason}\n`);
        break;
      }
    }

    // ── Conventional Commits enforcement (blocks invalid commits) ──────────
    if (/\bgit\s+commit\b/.test(cmdLower)) {
      const commitMessage = extractCommitMessage(rawCmd);
      if (commitMessage !== null) {
        // -m flag was present; enforce format
        if (!isValidConventionalCommit(commitMessage)) {
          const suggested = suggestConventionalCommit(commitMessage);
          const suggestion = suggested ? `\nSuggested: ${suggested}` : "";
          process.stderr.write(
            `❌ claude-solo: Commit message must follow Conventional Commits format\n\n` +
              `Expected: type(scope): description\n` +
              `Types: ${VALID_TYPES.join(", ")}\n\n` +
              `Your message: "${commitMessage}"` +
              suggestion +
              `\n`,
          );
          process.exit(2);
        }
      }
    }

    // ── RTK auto-wrap (Windows workaround for shell-level hook) ───────────
    const { command: wrappedCmd, modified } = applyRtk(rawCmd);
    if (modified) {
      process.stderr.write(`🔧 rtk: auto-wrapped for token savings\n`);
      process.stdout.write(
        JSON.stringify({
          updatedInput: { command: wrappedCmd },
        }),
      );
      return;
    }
  }

  process.stdout.write(JSON.stringify({ action: "continue" }));
});
