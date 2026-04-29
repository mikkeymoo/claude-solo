#!/usr/bin/env node
/**
 * claude-solo Stop hook continuation test gate
 *
 * Prevents Claude from stopping if issues exist:
 * 1. Uncommitted changes (blocks if any)
 * 2. TODO/FIXME in modified files (warns only)
 * 3. Test failures (blocks if tests fail)
 *
 * Input (stdin): JSON { stop_hook_active: true }
 * Output (stdout): empty on allow, or advisory message
 * Exit codes: 0 = allow, 2 = block
 */

import { createInterface } from "readline";
import { spawnSync } from "child_process";
import { readFileSync } from "fs";
import { join } from "path";

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    return; // Not valid JSON, allow
  }

  // Must have stop_hook_active to proceed
  if (!input.stop_hook_active) {
    return;
  }

  const cwd = process.cwd();
  let shouldBlock = false;

  // ── 1. Check for uncommitted changes ─────────────────────────────────────
  try {
    const gitCheck = spawnSync("git", ["rev-parse", "--git-dir"], {
      cwd,
      encoding: "utf8",
      shell: true,
      timeout: 5000,
    });

    // Only check git status if we're in a git repo
    if (gitCheck.status === 0) {
      const statusResult = spawnSync("git", ["status", "--porcelain"], {
        cwd,
        encoding: "utf8",
        shell: true,
        timeout: 5000,
      });

      if (statusResult.status === 0 && statusResult.stdout.trim().length > 0) {
        process.stderr.write(
          `⏸️  claude-solo stop-gate: Not stopping — uncommitted changes detected.\n` +
            `Commit or stash changes before stopping. Run: git status\n`,
        );
        shouldBlock = true;
      }
    }
  } catch {
    // Not in a git repo or git check failed — skip
  }

  // ── 2. Check for TODO/FIXME in recently modified files (advisory only) ────
  if (!shouldBlock) {
    try {
      const gitCheck = spawnSync("git", ["rev-parse", "--git-dir"], {
        cwd,
        encoding: "utf8",
        shell: true,
        timeout: 5000,
      });

      if (gitCheck.status === 0) {
        const diffResult = spawnSync("git", ["diff", "--name-only", "HEAD~1"], {
          cwd,
          encoding: "utf8",
          shell: true,
          timeout: 5000,
        });

        if (diffResult.status === 0 && diffResult.stdout.trim().length > 0) {
          const files = diffResult.stdout.trim().split("\n");

          let foundMarkers = [];
          for (const file of files) {
            try {
              const grepResult = spawnSync(
                "grep",
                ["-H", "-E", "TODO|FIXME|HACK|XXX", file],
                {
                  cwd,
                  encoding: "utf8",
                  shell: true,
                  timeout: 5000,
                },
              );

              if (grepResult.status === 0) {
                foundMarkers.push(file);
              }
            } catch {
              // File doesn't exist or grep failed, skip
            }
          }

          if (foundMarkers.length > 0) {
            process.stderr.write(
              `📝 claude-solo stop-gate: TODO/FIXME markers found in modified files — consider addressing before stopping.\n` +
                foundMarkers.map((f) => `   - ${f}`).join("\n") +
                "\n",
            );
            // Advisory only, don't block
          }
        }
      }
    } catch {
      // Skip TODO check if it fails
    }
  }

  // ── 3. Check tests (if discoverable) ─────────────────────────────────────
  if (!shouldBlock) {
    try {
      // Try to read package.json to find test commands
      const packageJsonPath = join(cwd, "package.json");
      let packageJson;
      try {
        const content = readFileSync(packageJsonPath, "utf8");
        packageJson = JSON.parse(content);
      } catch {
        // No package.json or parse error, skip test check
        packageJson = null;
      }

      if (packageJson && packageJson.scripts) {
        // Look for test commands (prefer 'test' or 'check', skip e2e/playwright)
        const testCmd = packageJson.scripts.test || packageJson.scripts.check;

        // Only run if the command looks quick (not playwright/e2e)
        if (
          testCmd &&
          !testCmd.includes("playwright") &&
          !testCmd.includes("e2e")
        ) {
          const testResult = spawnSync(testCmd, {
            cwd,
            shell: true,
            timeout: 30000, // 30s timeout
            encoding: "utf8",
          });

          if (testResult.status !== 0) {
            process.stderr.write(
              `🔴 claude-solo stop-gate: Test command failed — not stopping.\n` +
                `Run tests locally before stopping. Command: npm run test\n`,
            );
            shouldBlock = true;
          }
        }
      }
    } catch {
      // Test discovery/execution failed, don't block (not fatal)
    }
  }

  // Exit with appropriate code
  if (shouldBlock) {
    process.exit(2);
  }

  // Success: silent exit (exit 0)
  process.exit(0);
});
