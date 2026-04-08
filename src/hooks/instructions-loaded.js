#!/usr/bin/env node
/**
 * claude-solo InstructionsLoaded hook
 *
 * Fires when CLAUDE.md or .claude/rules/*.md files are loaded.
 * Logs which instruction files are active to stderr — useful for
 * debugging which rules apply in multi-project or nested setups.
 *
 * Input (stdin): JSON { paths: string[], cwd, ... }
 * Output: none required — informational only
 */

import { createInterface } from 'readline';
import os from 'os';
import { join } from 'path';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    return;
  }

  const paths = input.paths || input.instruction_files || [];

  if (!Array.isArray(paths) || paths.length === 0) {
    return;
  }

  const home = os.homedir();

  // Shorten home directory for readability
  const display = paths.map(p =>
    typeof p === 'string' ? p.replace(home, '~') : String(p)
  );

  // Categorize
  const global = display.filter(p => p.includes('~/.claude') && !p.includes('/rules/'));
  const rules  = display.filter(p => p.includes('/rules/'));
  const project = display.filter(p => !p.includes('~/.claude') || p.includes('/rules/'));
  const other  = display.filter(p => !global.includes(p) && !rules.includes(p));

  const lines = ['📚 claude-solo instructions loaded:'];

  if (global.length > 0)  lines.push(`   Global:  ${global.join(', ')}`);
  if (rules.length > 0)   lines.push(`   Rules:   ${rules.join(', ')}`);
  if (project.length > 0 && project.some(p => !global.includes(p) && !rules.includes(p))) {
    const proj = project.filter(p => !global.includes(p) && !rules.includes(p));
    if (proj.length > 0) lines.push(`   Project: ${proj.join(', ')}`);
  }
  if (other.length > 0) {
    const unique = other.filter(p => !global.includes(p) && !rules.includes(p));
    if (unique.length > 0) lines.push(`   Other:   ${unique.join(', ')}`);
  }

  process.stderr.write(lines.join('\n') + '\n');
});
