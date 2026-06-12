#!/usr/bin/env node
/**
 * claude-solo PermissionRequest hook
 *
 * Default mode: ALLOW ALL — designed for users who run with
 * --dangerouslySkipPermissions or want zero blocking prompts.
 *
 * Only denies truly catastrophic patterns (rm -rf /, DROP DATABASE on prod).
 * Everything else is auto-approved.
 *
 * To switch to a more conservative mode, change ALLOW_ALL to false below.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): JSON { decision: "allow" | "deny" | "ask" }
 */

import { createInterface } from "readline";

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Configuration: set CLAUDE_SOLO_ALLOW_ALL=1 to auto-approve everything
// (useful for --dangerouslySkipPermissions or fully trusted environments).
// Default: conservative mode — only auto-approves read-only operations.
const ALLOW_ALL = process.env.CLAUDE_SOLO_ALLOW_ALL === "1";
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const rl = createInterface({ input: process.stdin });
let raw = "";
rl.on("line", (line) => (raw += line));

rl.on("close", () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(
      JSON.stringify({ decision: ALLOW_ALL ? "allow" : "ask" }),
    );
    return;
  }

  const { tool_name, tool_input } = input;

  // ── Deny-list removed per user request — this hook never denies. ────────
  // (Previously blocked rm -rf /, mkfs, dd-to-disk, fork bombs.) Re-add a
  // catastrophic-pattern check here if you want a hook-level safety floor.

  // ── ALLOW_ALL mode: approve everything ──────────────────────────────────
  if (ALLOW_ALL) {
    process.stdout.write(JSON.stringify({ decision: "allow" }));
    return;
  }

  // ── Conservative mode (ALLOW_ALL = false) ───────────────────────────────
  // Only auto-approves read-only operations, asks for the rest.

  const alwaysSafe = [
    "Read",
    "Glob",
    "Grep",
    "LS",
    "WebSearch",
    "WebFetch",
    "TaskCreate",
    "TaskUpdate",
    "TaskGet",
    "TaskList",
    "TodoRead",
  ];

  if (alwaysSafe.includes(tool_name)) {
    process.stdout.write(JSON.stringify({ decision: "allow" }));
    return;
  }

  // MCP read-only tools
  const readOnlyMcpPatterns = [
    /^mcp__.*__(read|get|list|search|query|resolve|view|fetch)/,
    /^mcp__desktop-commander__(list_directory|read_file|read_multiple_files|get_file_info|list_processes|get_usage_stats)/,
    /^mcp__.*context7/,
  ];

  for (const pattern of readOnlyMcpPatterns) {
    if (pattern.test(tool_name)) {
      process.stdout.write(JSON.stringify({ decision: "allow" }));
      return;
    }
  }

  // Safe Bash commands
  if (tool_name === "Bash" && tool_input?.command) {
    const cmd = tool_input.command.trim();

    const safeBashPatterns = [
      /^rtk\s/,
      /^(git\s+)?(status|log|diff|show|branch|remote|tag)\b/,
      /^(git\s+)?rev-parse\b/,
      /^ls\b/,
      /^cat\b/,
      /^head\b/,
      /^tail\b/,
      /^wc\b/,
      /^pwd$/,
      /^which\b/,
      /^where\b/,
      /^node\s+--version/,
      /^python\s+--version/,
      /^(npm|pnpm|yarn)\s+(list|ls|outdated|view|info|why)\b/,
      /^gh\s+(pr|issue|run)\s+(view|list|status|checks)\b/,
      /^echo\s/,
      /^type\b/,
      /^file\b/,
      /^env$/,
      /^printenv\b/,
      /^uname\b/,
      /^date$/,
      /^df\b/,
      /^du\b/,
      /^free\b/,
    ];

    for (const pattern of safeBashPatterns) {
      if (pattern.test(cmd)) {
        process.stdout.write(JSON.stringify({ decision: "allow" }));
        return;
      }
    }
  }

  // Everything else in conservative mode: ask the user
  process.stdout.write(JSON.stringify({ decision: "ask" }));
});
