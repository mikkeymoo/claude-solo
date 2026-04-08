#!/usr/bin/env node
/**
 * claude-solo ConfigChange hook
 *
 * Fires when Claude Code's settings files change during a session.
 * Warns if claude-solo hooks are being removed, so users don't
 * accidentally break their pipeline. Advisory only — never blocks.
 *
 * Input (stdin): JSON { source, file_path, cwd, ... }
 * Output (stdout): JSON {} (always allow)
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync } from 'fs';
import { basename } from 'path';

// The hook events claude-solo registers — warn if any go missing
const CLAUDE_SOLO_HOOKS = [
  'SessionStart',
  'PreToolUse',
  'PostToolUse',
  'UserPromptSubmit',
  'PermissionRequest',
  'PreCompact',
  'PostCompact',
  'SubagentStop',
  'Stop',
  'PostToolUseFailure',
  'FileChanged',
  'ConfigChange',
  'InstructionsLoaded',
  'WorktreeCreate',
];

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  const filePath = input.file_path || '';

  // Only care about settings.json changes
  const fileName = basename(filePath);
  if (fileName !== 'settings.json' && fileName !== 'settings.local.json') {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  // Read the new config and check for missing hooks
  if (!existsSync(filePath)) {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  let config;
  try {
    config = JSON.parse(readFileSync(filePath, 'utf8'));
  } catch {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  const registeredHooks = Object.keys(config.hooks || {});
  const missing = CLAUDE_SOLO_HOOKS.filter(h => !registeredHooks.includes(h));

  if (missing.length > 0) {
    process.stderr.write(
      `⚠️  claude-solo: settings.json changed — these hooks are no longer registered:\n` +
      missing.map(h => `   - ${h}`).join('\n') + '\n' +
      `   Run setup.sh to restore them, or this is intentional.\n`
    );
  }

  // Always allow — this hook is advisory only
  process.stdout.write(JSON.stringify({}));
});
