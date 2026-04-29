#!/usr/bin/env node
/**
 * claude-solo PermissionDenied hook
 *
 * Fires when a permission request is denied (by the user or by deny rules).
 * Logs the denial to stderr so Claude knows what was blocked and why.
 * Advisory only — never blocks.
 *
 * Input (stdin): JSON { tool_name, tool_input, decision_reason }
 * Output: none — informational stderr only
 */

import { createInterface } from 'readline';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => (raw += line));

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    return;
  }

  const { tool_name, tool_input, decision_reason } = input;

  // Build a concise description of what was denied
  let description = tool_name;
  if (tool_name === 'Bash' && tool_input?.command) {
    description = `Bash: ${tool_input.command.slice(0, 80)}`;
  } else if (tool_input?.file_path || tool_input?.path) {
    description = `${tool_name}: ${tool_input.file_path || tool_input.path}`;
  }

  const reason = decision_reason ? ` (${decision_reason})` : '';
  process.stderr.write(`🚫 claude-solo: permission denied — ${description}${reason}\n`);
});
