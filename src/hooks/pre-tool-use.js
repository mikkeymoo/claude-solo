#!/usr/bin/env node
/**
 * claude-solo pre-tool-use hook
 *
 * Warns about potentially dangerous commands via stderr — never blocks.
 * Claude Code will still execute the command; this is advisory only.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): JSON { action: "continue" }
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
    process.stdout.write(JSON.stringify({ action: 'continue' }));
    return;
  }

  const { tool_name, tool_input } = input;

  if (tool_name === 'Bash' || tool_name === 'mcp__desktop-commander__start_process') {
    const cmd = (tool_input?.command || tool_input?.cmd || '').toLowerCase();

    const warnings = [
      { pattern: /rm\s+-rf\s+\/(?!tmp)/, reason: 'Deleting from root' },
      { pattern: /git\s+push\s+--force\s+(origin\s+)?main/, reason: 'Force-pushing to main' },
      { pattern: /git\s+reset\s+--hard/, reason: 'Hard reset discards uncommitted work' },
      { pattern: /drop\s+table/i, reason: 'Dropping database table' },
      { pattern: /delete\s+from\s+\w+\s*;?\s*$/, reason: 'DELETE without WHERE clause' },
      { pattern: /truncate\s+table/i, reason: 'TRUNCATE is irreversible' },
    ];

    for (const { pattern, reason } of warnings) {
      if (pattern.test(cmd)) {
        process.stderr.write(`⚠️  claude-solo: ${reason}\n`);
        break;
      }
    }
  }

  // Always continue — never block
  process.stdout.write(JSON.stringify({ action: 'continue' }));
});
