#!/usr/bin/env node
/**
 * claude-solo CwdChanged hook
 *
 * Fires when the working directory changes (e.g. user navigates to a new project).
 * Emits a brief context note to stderr so Claude knows the directory changed.
 *
 * Input (stdin): JSON { old_dir, new_dir }
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

  const { old_dir, new_dir } = input;
  if (!new_dir) return;

  const shortNew = new_dir.split(/[\\/]/).slice(-2).join('/');
  const shortOld = old_dir ? old_dir.split(/[\\/]/).slice(-2).join('/') : '?';

  process.stderr.write(`📁 claude-solo: cwd changed — ${shortOld} → ${shortNew}\n`);
});
