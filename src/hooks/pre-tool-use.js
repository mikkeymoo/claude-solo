#!/usr/bin/env node
/**
 * claude-solo pre-tool-use hook
 *
 * Runs before Claude executes any tool. Intercepts dangerous commands
 * and provides feedback before they run.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): JSON { action: "block"|"continue", reason?: string }
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
    // Not JSON — pass through
    process.stdout.write(JSON.stringify({ action: 'continue' }));
    return;
  }

  const { tool_name, tool_input } = input;

  // Intercept dangerous bash commands
  if (tool_name === 'Bash' || tool_name === 'mcp__desktop-commander__start_process') {
    const cmd = (tool_input?.command || tool_input?.cmd || '').toLowerCase();

    // Block destructive operations
    const dangerous = [
      { pattern: /rm\s+-rf\s+\/(?!tmp)/, reason: 'Deleting from root is not allowed' },
      { pattern: /git\s+push\s+--force\s+(origin\s+)?main/, reason: 'Force-pushing to main branch' },
      { pattern: /git\s+reset\s+--hard/, reason: 'Hard reset discards uncommitted work' },
      { pattern: /drop\s+table/i, reason: 'Dropping database tables is irreversible' },
      { pattern: /delete\s+from\s+\w+\s*;?\s*$/, reason: 'DELETE without WHERE clause' },
      { pattern: /truncate\s+table/i, reason: 'TRUNCATE is irreversible' },
    ];

    for (const { pattern, reason } of dangerous) {
      if (pattern.test(cmd)) {
        process.stdout.write(JSON.stringify({
          action: 'block',
          reason: `⚠️  claude-solo safety: ${reason}. Review and run manually if intentional.`
        }));
        return;
      }
    }
  }

  // All other commands pass through
  process.stdout.write(JSON.stringify({ action: 'continue' }));
});
