#!/usr/bin/env node
/**
 * Auto Test-Then-Fix Hook
 *
 * Opt-in: set AUTO_TEST=1 in your environment or .claude/settings.local.json env block
 * Example: { "env": { "AUTO_TEST": "1" } }
 * Only runs unit/integration tests — never e2e. Timeout: 30s.
 *
 * Runs after Edit, Write, or MultiEdit tool use.
 * Discovers and runs relevant tests on changed files.
 * If tests fail, exits with code 2 to trigger Claude's auto-fix.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 * Output (stdout): { action: 'continue' } on success/no issues
 *                  Test errors written to stderr, exit code 2
 */

import { createInterface } from "readline";
import { existsSync, statSync } from "fs";
import { spawnSync } from "child_process";
import { resolve, extname, dirname } from "path";
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
  // Skip binary files
  const ext = extname(filePath).toLowerCase();
  if (BINARY_EXTS.has(ext)) return true;

  // Skip files in excluded directories
  const parts = filePath.split(/[/\\]/);
  for (const part of parts) {
    if (SKIP_DIRS.has(part)) return true;
  }

  return false;
}

function isTestFile(filePath) {
  // Check if file is a test file by looking for test indicators in name
  const fileName = filePath.toLowerCase();
  return (
    fileName.includes(".test.") ||
    fileName.includes(".spec.") ||
    fileName.includes("_test.") ||
    fileName.includes("test_")
  );
}

function detectTestCommand(projectRoot) {
  // Check for package.json with test script
  const pkgPath = resolve(projectRoot, "package.json");
  if (existsSync(pkgPath)) {
    try {
      const pkg = JSON.parse(require("fs").readFileSync(pkgPath, "utf8"));
      if (pkg.scripts && pkg.scripts.test) {
        const testScript = pkg.scripts.test;
        // Skip if it's an e2e or playwright test
        if (
          testScript.includes("playwright") ||
          testScript.includes("cypress") ||
          testScript.includes("e2e")
        ) {
          return null;
        }
        return { type: "npm", command: ["npm", "run", "test"] };
      }
    } catch {
      /* ignore parse errors */
    }
  }

  // Check for pyproject.toml with pytest config
  const pyprojectPath = resolve(projectRoot, "pyproject.toml");
  if (existsSync(pyprojectPath)) {
    try {
      const content = require("fs").readFileSync(pyprojectPath, "utf8");
      if (content.includes("[tool.pytest.ini_options]")) {
        return { type: "pytest", command: ["python", "-m", "pytest"] };
      }
    } catch {
      /* ignore parse errors */
    }
  }

  // Check for Cargo.toml
  if (existsSync(resolve(projectRoot, "Cargo.toml"))) {
    return { type: "cargo", command: ["cargo", "test"] };
  }

  return null;
}

function runTests(testConfig, projectRoot) {
  const timeout = 30000; // 30 seconds hard limit

  if (!testConfig) {
    return { noTests: true };
  }

  try {
    const result = spawnSync(
      testConfig.command[0],
      testConfig.command.slice(1),
      {
        cwd: projectRoot,
        encoding: "utf8",
        timeout,
        stdio: ["pipe", "pipe", "pipe"],
        shell: false,
      },
    );

    if (result.error) {
      // Timeout or crash — don't block
      if (result.error.code === "ETIMEDOUT") {
        return { timedOut: true };
      }
      return { error: `Failed to run tests: ${result.error.message}` };
    }

    // Check exit status: 0 = success, non-zero = test failures
    if (result.status !== 0 && result.status !== null) {
      return { testFailures: result.stdout || result.stderr };
    }

    return { success: true };
  } catch (e) {
    // Unexpected error — don't block
    return { error: e.message };
  }
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

  // Only run if AUTO_TEST is explicitly enabled
  if (process.env.AUTO_TEST !== "1") {
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

  // Skip binary files and excluded directories
  if (shouldSkipFile(absolutePath)) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Skip if file is itself a test file
  if (isTestFile(absolutePath)) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Skip if file doesn't exist yet (Write might create it)
  if (!existsSync(absolutePath)) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Get project root
  const projectRoot = cwd();

  // Detect test command
  const testConfig = detectTestCommand(projectRoot);
  if (!testConfig) {
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  // Run tests
  const result = runTests(testConfig, projectRoot);

  if (result.noTests || result.error || result.timedOut) {
    // No tests found, error running tests, or timeout — don't block
    process.stdout.write(JSON.stringify({ action: "continue" }));
    return;
  }

  if (result.testFailures) {
    // Test failures found — write to stderr and exit with code 2
    process.stderr.write(result.testFailures);
    process.exit(2);
  }

  // Success — continue
  process.stdout.write(JSON.stringify({ action: "continue" }));
});
