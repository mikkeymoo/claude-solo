#!/usr/bin/env node
/**
 * claude-solo error-handling-reminder hook (PostToolUse)
 *
 * Opt-in: set CLAUDE_SOLO_ERROR_REMINDERS=1 to enable.
 * Advisory only — writes to stderr, never blocks.
 *
 * Checks written/edited code files for common problematic error-handling
 * patterns: empty catch blocks, bare TODO handlers, silent promise swallowing.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 * Output: none — informational stderr only
 */

import { createInterface } from 'readline';

if (!process.env.CLAUDE_SOLO_ERROR_REMINDERS) {
  process.exit(0);
}

const CODE_EXTENSIONS = /\.(js|ts|jsx|tsx|py|java|cs|go|rs|php|rb|swift|kt)$/;

const CHECKS = [
  {
    pattern: /catch\s*\([^)]*\)\s*\{\s*\}/,
    message: 'empty catch block',
  },
  {
    pattern: /catch\s*\([^)]*\)\s*\{\s*\/\/\s*TODO/i,
    message: 'unimplemented error handler (TODO in catch)',
  },
  {
    pattern: /\.catch\s*\(\s*\(\)\s*=>\s*\{\s*\}\s*\)/,
    message: 'empty .catch() arrow function',
  },
  {
    pattern: /\.catch\s*\(\s*function\s*\([^)]*\)\s*\{\s*\}\s*\)/,
    message: 'empty .catch() function',
  },
];

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

  const { tool_name, tool_input } = input;

  let code = '';
  let file = '';

  if (tool_name === 'Write') {
    code = tool_input?.content || '';
    file = tool_input?.file_path || tool_input?.path || '';
  } else if (tool_name === 'Edit') {
    code = tool_input?.new_string || '';
    file = tool_input?.file_path || tool_input?.path || '';
  } else {
    return;
  }

  if (!code || !CODE_EXTENSIONS.test(file)) return;

  for (const { pattern, message } of CHECKS) {
    if (pattern.test(code)) {
      process.stderr.write(`💭 claude-solo: ${message} detected in ${file}\n`);
    }
  }
});
