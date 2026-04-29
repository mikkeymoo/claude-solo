#!/usr/bin/env node
/**
 * claude-solo gitignore validation hook (PreToolUse)
 *
 * Warns when Write tool is used to write to typically-gitignored paths.
 * Advisory only — never blocks the write.
 *
 * Checks for common patterns:
 * - node_modules/
 * - dist/ or /dist as directory segment
 * - .next/
 * - __pycache__/
 * - .venv/ or venv/
 * - .env (but not .env.example)
 * - build/ as exact directory segment
 * - .cache/
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): { action: 'continue' }
 */

import { createInterface } from "readline";

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

  if (tool_name === "Write") {
    const filePath = tool_input?.file_path || "";

    // Check gitignored patterns
    const isGitignored = checkGitignored(filePath);

    if (isGitignored) {
      process.stderr.write(
        `⚠️  claude-solo: Writing to typically-gitignored path: ${filePath}\n`,
      );
    }
  }

  process.stdout.write(JSON.stringify({ action: "continue" }));
});

/**
 * Check if a path matches common gitignored patterns.
 * @param {string} filePath - The file path to check
 * @returns {boolean} - True if path matches a gitignored pattern
 */
function checkGitignored(filePath) {
  // Normalize path separators to forward slashes for consistent checking
  const normalized = filePath.replace(/\\/g, "/");

  // Check each pattern
  const patterns = [
    // node_modules/
    () => normalized.includes("node_modules/"),

    // dist/ or /dist as a directory segment (not distrib, etc.)
    () => /(?:^|\/)dist(?:\/|$)/.test(normalized),

    // .next/
    () => normalized.includes(".next/"),

    // __pycache__/
    () => normalized.includes("__pycache__/"),

    // .venv/ or venv/ as directory segments
    () => /(?:^|\/)\.?venv(?:\/|$)/.test(normalized),

    // .env files (but not .env.example)
    () =>
      /\.env(?:\/|$)/.test(normalized) && !normalized.endsWith(".env.example"),

    // build/ as exact directory segment (not builds/, etc.)
    () => /(?:^|\/)build(?:\/|$)/.test(normalized),

    // .cache/
    () => normalized.includes(".cache/"),
  ];

  return patterns.some((check) => check());
}
