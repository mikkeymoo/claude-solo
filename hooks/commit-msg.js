#!/usr/bin/env node
/**
 * claude-solo commit message suggestion hook
 *
 * Runs after Bash tool use that includes 'git add'.
 * Analyzes staged changes and suggests a conventional commit message.
 * Advisory only — never blocks, never auto-commits.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 * Output (stdout): { action: 'continue' }
 * Suggestion (stderr): 💡 claude-solo: Suggested commit message...
 */

import { createInterface } from "readline";
import { spawnSync } from "child_process";
import { cwd } from "process";

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

  // Only trigger on Bash tool with git add command
  if (tool_name !== "Bash") {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  const command = tool_input?.command || "";

  // Check if command contains 'git add' but exclude batch/all variants
  if (!command.includes("git add") || command.includes("git add -u --all")) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Check if there are staged changes
  const stagedCheckResult = spawnSync("git", ["diff", "--staged", "--stat"], {
    cwd: cwd(),
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  });

  if (stagedCheckResult.status !== 0 || !stagedCheckResult.stdout.trim()) {
    // No staged changes
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Get list of changed files
  const filesResult = spawnSync("git", ["diff", "--staged", "--name-only"], {
    cwd: cwd(),
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  });

  if (filesResult.status !== 0) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  const files = filesResult.stdout.trim().split("\n").filter(Boolean);

  // Get the diff (limited to first 3000 chars)
  const diffResult = spawnSync("git", ["diff", "--staged", "--unified=0"], {
    cwd: cwd(),
    encoding: "utf8",
    stdio: ["pipe", "pipe", "pipe"],
  });

  let diff = "";
  if (diffResult.status === 0) {
    diff = diffResult.stdout.slice(0, 3000);
  }

  // Analyze changes and suggest commit message
  const suggestion = analyzeChanges(files, diff);

  // Write suggestion to stderr
  const message = `${suggestion.type}(${suggestion.scope}): ${suggestion.description}`;
  process.stderr.write(
    `💡 claude-solo: Suggested commit message:\n   ${message}\n\nTo use: git commit -m "${message}"\n`,
  );

  process.stdout.write(JSON.stringify({ action: "continue" }));
});

/**
 * Analyze changed files and diff to suggest a commit type, scope, and description.
 * @param {string[]} files - List of changed files
 * @param {string} diff - The unified diff output (first 3000 chars)
 * @returns {object} { type, scope, description }
 */
function analyzeChanges(files, diff) {
  // Determine scope from files
  const scope = inferScope(files);

  // Determine type from files and diff
  let type = "fix"; // default
  let description = "update code"; // default

  // Check if only docs/markdown changed
  if (files.every((f) => f.endsWith(".md"))) {
    type = "docs";
    description = "update documentation";
  }
  // Check if test files are involved
  else if (files.some((f) => f.includes("test") || f.includes("spec"))) {
    type = "test";
    description = "add or update tests";
  }
  // Check if all files are new (feat)
  else if (files.length > 0) {
    // Check diff to see if these are entirely new files (no @@ lines with minus context)
    const hasNewFilesOnly = files.some((f) => diff.includes(`+++ b/${f}`));
    const hasModifications = diff.includes("@@");

    if (hasNewFilesOnly && !hasModifications) {
      type = "feat";
      description = "add new feature";
    } else if (
      diff.includes("+++") &&
      !diff.split("\n").some((line) => line.startsWith("-") && line !== "---")
    ) {
      // Only additions, no removals (excluding --- separator)
      type = "feat";
      description = "add new feature";
    } else {
      // Check diff for pattern keywords
      if (
        diff.includes("refactor") ||
        diff.includes("rename") ||
        diff.includes("restructure")
      ) {
        type = "refactor";
        description = "refactor code structure";
      } else if (
        diff.includes("fix") ||
        diff.includes("bug") ||
        diff.includes("error")
      ) {
        type = "fix";
        description = "fix bug or issue";
      } else if (
        diff.includes("perf") ||
        diff.includes("performance") ||
        diff.includes("optimize")
      ) {
        type = "perf";
        description = "improve performance";
      } else {
        type = "fix";
        description = "update code";
      }
    }
  }

  // Infer more specific description from scope and type
  if (type === "feat") {
    description = `add ${scope} feature`;
  } else if (type === "fix") {
    description = `fix ${scope} issues`;
  } else if (type === "refactor") {
    description = `refactor ${scope}`;
  } else if (type === "docs") {
    description = "update documentation";
  } else if (type === "test") {
    description = `add ${scope} tests`;
  }

  return { type, scope, description };
}

/**
 * Infer the scope (main directory/module) from changed files.
 * @param {string[]} files - List of changed file paths
 * @returns {string} - The scope (e.g., 'hooks', 'skills/myskill', 'scripts')
 */
function inferScope(files) {
  if (files.length === 0) return "misc";

  // Collect all top-level directories
  const dirs = new Set();
  for (const file of files) {
    const parts = file.split(/[/\\]/);
    if (parts.length > 1) {
      dirs.add(parts[0]);
    }
  }

  // If multiple directories, pick the most common one or use 'misc'
  if (dirs.size === 0) {
    return "misc";
  }

  if (dirs.size === 1) {
    const dir = Array.from(dirs)[0];
    // For skills, try to extract the skill name
    if (dir === "skills" && files.length > 0) {
      const skillMatch = files[0].match(/skills\/([^/\\]+)/);
      if (skillMatch) {
        return `skills/${skillMatch[1]}`;
      }
    }
    return dir;
  }

  // Multiple dirs: pick the most frequently appearing one
  const dirCounts = {};
  for (const file of files) {
    const parts = file.split(/[/\\]/);
    const topDir = parts[0];
    dirCounts[topDir] = (dirCounts[topDir] || 0) + 1;
  }

  const mostCommon = Object.entries(dirCounts).sort((a, b) => b[1] - a[1])[0];
  return mostCommon ? mostCommon[0] : "misc";
}
