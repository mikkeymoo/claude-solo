#!/usr/bin/env node
/**
 * claude-solo lint-fix hook
 *
 * Runs after Edit, Write, or MultiEdit tool use.
 * Detects the project's linter and runs it on the changed file.
 * If lint errors are found, exits with code 2 to trigger Claude's auto-fix.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 * Output (stdout): { action: 'continue' } on success/no issues
 *                  Lint errors written to stderr, exit code 2
 */

import { createInterface } from "readline";
import { existsSync } from "fs";
import { spawnSync } from "child_process";
import { resolve, extname } from "path";
import { cwd } from "process";

// Binary file extensions to skip
const BINARY_EXTS = new Set([
  ".png",
  ".jpg",
  ".jpeg",
  ".gif",
  ".ico",
  ".woff",
  ".woff2",
  ".ttf",
  ".otf",
  ".pdf",
  ".zip",
  ".tar",
  ".gz",
  ".exe",
  ".dll",
  ".so",
  ".dylib",
  ".pyc",
  ".o",
  ".a",
]);

// Plain-text / non-code extensions - never pass to a linter
const NON_CODE_EXTS = new Set([
  ".txt",
  ".md",
  ".mdx",
  ".csv",
  ".tsv",
  ".log",
  ".yaml",
  ".yml",
  ".toml",
  ".ini",
  ".cfg",
  ".conf",
  ".env",
  ".gitignore",
  ".gitattributes",
  ".editorconfig",
  ".xml",
  ".svg",
  ".lock",
  ".sum",
]);

// Extensions that ruff (Python linter) should run on
const RUFF_EXTS = new Set([".py", ".pyi"]);

// Extensions that ESLint should run on
const ESLINT_EXTS = new Set([
  ".js",
  ".jsx",
  ".mjs",
  ".cjs",
  ".ts",
  ".tsx",
  ".mts",
  ".cts",
]);

// Directories to skip
const SKIP_DIRS = new Set([
  "node_modules",
  ".git",
  "dist",
  "build",
  ".next",
  ".cache",
]);

function shouldSkipFile(filePath) {
  const ext = extname(filePath).toLowerCase();

  // Skip binary files
  if (BINARY_EXTS.has(ext)) return true;

  // Skip plain-text / non-code files - linters cannot parse these
  if (NON_CODE_EXTS.has(ext)) return true;

  // Skip files in excluded directories
  const parts = filePath.split(/[/\\]/);
  for (const part of parts) {
    if (SKIP_DIRS.has(part)) return true;
  }

  return false;
}

function detectLinter(projectRoot) {
  // Check for eslint config
  const eslintPatterns = [
    "eslint.config.js",
    "eslint.config.mjs",
    "eslint.config.ts",
    ".eslintrc.js",
    ".eslintrc.json",
    ".eslintrc.yml",
    ".eslintrc.yaml",
  ];
  for (const pattern of eslintPatterns) {
    if (existsSync(resolve(projectRoot, pattern))) {
      return { type: "eslint", config: pattern };
    }
  }

  // Check for ruff (Python)
  if (
    existsSync(resolve(projectRoot, "pyproject.toml")) ||
    existsSync(resolve(projectRoot, "ruff.toml"))
  ) {
    return { type: "ruff" };
  }

  // Check for clippy (Rust)
  if (existsSync(resolve(projectRoot, "Cargo.toml"))) {
    return { type: "clippy" };
  }

  return null;
}

function runLinter(linter, filePath, projectRoot) {
  const timeout = 10000; // 10 seconds
  const ext = extname(filePath).toLowerCase();

  if (linter.type === "eslint") {
    // Only run ESLint on JS/TS files
    if (!ESLINT_EXTS.has(ext)) return { noLinter: true };

    const result = spawnSync(
      "npx",
      ["eslint", "--no-eslintrc", "-c", linter.config, filePath],
      {
        cwd: projectRoot,
        encoding: "utf8",
        timeout,
        stdio: ["pipe", "pipe", "pipe"],
      },
    );

    if (result.error) {
      return { error: `Failed to run eslint: ${result.error.message}` };
    }

    if (result.status !== 0) {
      return { lintErrors: result.stdout || result.stderr };
    }

    return { success: true };
  }

  if (linter.type === "ruff") {
    // Only run ruff on Python files
    if (!RUFF_EXTS.has(ext)) return { noLinter: true };

    const result = spawnSync("ruff", ["check", filePath], {
      cwd: projectRoot,
      encoding: "utf8",
      timeout,
      stdio: ["pipe", "pipe", "pipe"],
    });

    if (result.error) {
      return { error: `Failed to run ruff: ${result.error.message}` };
    }

    if (result.status !== 0) {
      return { lintErrors: result.stdout || result.stderr };
    }

    return { success: true };
  }

  if (linter.type === "clippy") {
    // Clippy runs project-wide, no per-file extension check needed
    const result = spawnSync("cargo", ["clippy", "--quiet"], {
      cwd: projectRoot,
      encoding: "utf8",
      timeout,
      stdio: ["pipe", "pipe", "pipe"],
    });

    if (result.error) {
      return { error: `Failed to run cargo clippy: ${result.error.message}` };
    }

    if (result.status !== 0) {
      return { lintErrors: result.stdout || result.stderr };
    }

    return { success: true };
  }

  return { noLinter: true };
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

  // Only run after Edit, Write, or MultiEdit tools
  if (!["Edit", "Write", "MultiEdit"].includes(tool_name)) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Extract file path from tool input
  let filePath = tool_input?.file_path || tool_input?.path;
  if (!filePath) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Resolve to absolute path
  const absolutePath = resolve(filePath);

  // Skip binary, plain-text, and excluded-directory files
  if (shouldSkipFile(absolutePath)) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Skip if file doesn't exist yet (Write might create it)
  if (!existsSync(absolutePath)) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Get project root (use current working directory)
  const projectRoot = cwd();

  // Detect linter
  const linter = detectLinter(projectRoot);
  if (!linter) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Run linter
  const result = runLinter(linter, absolutePath, projectRoot);

  if (result.noLinter) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  if (result.error) {
    // Linter not available or failed - don't block
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  if (result.lintErrors) {
    // Lint errors found - write to stderr and exit with code 2
    process.stderr.write(result.lintErrors);
    process.exit(2);
  }

  // Success - continue
  process.stdout.write(JSON.stringify({ action: "continue" }));
});
