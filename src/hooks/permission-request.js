#!/usr/bin/env node
/**
 * claude-solo PermissionRequest hook
 *
 * Auto-approves safe, read-only operations to eliminate blocking prompts.
 * Denies nothing — just approves known-safe patterns; everything else
 * falls through to the normal permission prompt.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): JSON { decision: "allow" | "deny" | "ask" }
 */

import { createInterface } from 'readline';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({ decision: 'ask' }));
    return;
  }

  const { tool_name, tool_input } = input;

  // ── Always-safe tools (read-only, no side effects) ──────────────────────
  const alwaysSafe = [
    'Read',
    'Glob',
    'Grep',
    'LS',
    'WebSearch',
    'WebFetch',
    'TaskCreate',
    'TaskUpdate',
    'TaskGet',
    'TaskList',
    'TodoRead',
  ];

  if (alwaysSafe.includes(tool_name)) {
    process.stdout.write(JSON.stringify({ decision: 'allow' }));
    return;
  }

  // ── MCP read-only tools ─────────────────────────────────────────────────
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

  // ── Safe Bash commands (read-only patterns) ─────────────────────────────
  if (tool_name === 'Bash' && tool_input?.command) {
    const cmd = tool_input.command.trim();

    const safeBashPatterns = [
      /^rtk\s/,                          // RTK-wrapped commands (always safe passthrough)
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
        process.stdout.write(JSON.stringify({ decision: 'allow' }));
        return;
      }
    }
  }

  // ── Everything else: ask the user ───────────────────────────────────────
  process.stdout.write(JSON.stringify({ decision: 'ask' }));
});
