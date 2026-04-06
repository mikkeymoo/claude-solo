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

import { createInterface } from 'readline';

// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
// Configuration: set to false for a more conservative approval mode
// that only auto-approves read-only operations and asks for the rest.
const ALLOW_ALL = true;
// ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({ decision: ALLOW_ALL ? 'allow' : 'ask' }));
    return;
  }

  const { tool_name, tool_input } = input;

  // ── Catastrophic patterns — always block regardless of mode ─────────────
  if (tool_name === 'Bash' && tool_input?.command) {
    const cmd = tool_input.command.trim();

    const catastrophic = [
      /rm\s+-rf\s+\/(?!tmp)/,                        // rm -rf / (not /tmp)
      /rm\s+-rf\s+~\s*$/,                             // rm -rf ~ (home dir)
      /mkfs\./,                                        // format filesystem
      /dd\s+if=.*of=\/dev\/[sh]d/,                    // dd to disk device
      /:\(\)\s*\{\s*:\|:\s*&\s*\}\s*;?\s*:/,          // fork bomb
    ];

    for (const pattern of catastrophic) {
      if (pattern.test(cmd)) {
        process.stderr.write(`🛑 claude-solo: BLOCKED catastrophic command: ${cmd.slice(0, 80)}\n`);
        process.stdout.write(JSON.stringify({ decision: 'deny' }));
        return;
      }
    }
  }

  // ── ALLOW_ALL mode: approve everything that isn't catastrophic ──────────
  if (ALLOW_ALL) {
    process.stdout.write(JSON.stringify({ decision: 'allow' }));
    return;
  }

  // ── Conservative mode (ALLOW_ALL = false) ───────────────────────────────
  // Only auto-approves read-only operations, asks for the rest.

  const alwaysSafe = [
    'Read', 'Glob', 'Grep', 'LS', 'WebSearch', 'WebFetch',
    'TaskCreate', 'TaskUpdate', 'TaskGet', 'TaskList', 'TodoRead',
  ];

  if (alwaysSafe.includes(tool_name)) {
    process.stdout.write(JSON.stringify({ decision: 'allow' }));
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
      process.stdout.write(JSON.stringify({ decision: 'allow' }));
      return;
    }
  }

  // Safe Bash commands
  if (tool_name === 'Bash' && tool_input?.command) {
    const cmd = tool_input.command.trim();

    const safeBashPatterns = [
      /^rtk\s/,
      /^(git\s+)?(status|log|diff|show|branch|remote|tag)\b/,
      /^(git\s+)?rev-parse\b/,
      /^ls\b/, /^cat\b/, /^head\b/, /^tail\b/, /^wc\b/, /^pwd$/,
      /^which\b/, /^where\b/,
      /^node\s+--version/, /^python\s+--version/,
      /^(npm|pnpm|yarn)\s+(list|ls|outdated|view|info|why)\b/,
      /^gh\s+(pr|issue|run)\s+(view|list|status|checks)\b/,
      /^echo\s/, /^type\b/, /^file\b/, /^env$/, /^printenv\b/,
      /^uname\b/, /^date$/, /^df\b/, /^du\b/, /^free\b/,
    ];

    for (const pattern of safeBashPatterns) {
      if (pattern.test(cmd)) {
        process.stdout.write(JSON.stringify({ decision: 'allow' }));
        return;
      }
    }
  }

  // Everything else in conservative mode: ask the user
  process.stdout.write(JSON.stringify({ decision: 'ask' }));
});
