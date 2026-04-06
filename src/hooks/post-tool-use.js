#!/usr/bin/env node
/**
 * claude-solo post-tool-use hook
 *
 * Runs after Claude executes any tool. Used for logging, token tracking,
 * and surfacing RTK hints when raw commands are run.
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 */

import { createInterface } from 'readline';
import { appendFileSync, mkdirSync } from 'fs';
import { join } from 'path';
import os from 'os';

const LOG_DIR = join(os.homedir(), '.claude', 'logs');
const LOG_FILE = join(LOG_DIR, `session-${new Date().toISOString().slice(0,10)}.log`);

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    return; // Not JSON — skip
  }

  const { tool_name, tool_input } = input;

  // Log bash commands for session history
  if (tool_name === 'Bash' && tool_input?.command) {
    const cmd = tool_input.command;
    const timestamp = new Date().toISOString();

    // RTK hint: if running common commands without rtk prefix, suggest it
    const noRtkPatterns = [
      { match: /^git\s/, suggest: 'rtk git' },
      { match: /^npm\s/, suggest: 'rtk npm' },
      { match: /^pnpm\s/, suggest: 'rtk pnpm' },
      { match: /^python\s+-m\s+pytest/, suggest: 'rtk python -m pytest' },
      { match: /^gh\s+(pr|run|issue)/, suggest: 'rtk gh' },
    ];

    for (const { match, suggest } of noRtkPatterns) {
      if (match.test(cmd.trim())) {
        // Write RTK hint to stderr (shows in Claude Code output)
        process.stderr.write(`\n💡 RTK hint: prefix with \`rtk\` → \`${suggest} ...\` for 60-80% token savings\n`);
        break;
      }
    }

    // Append to session log
    try {
      mkdirSync(LOG_DIR, { recursive: true });
      appendFileSync(LOG_FILE, `[${timestamp}] ${tool_name}: ${cmd.slice(0, 200)}\n`);
    } catch {
      // Log failure is not fatal
    }
  }
});
