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

  // Shorten home dir — use startsWith+slice to handle mixed separators on Windows
  const shorten = (p) => {
    if (typeof p !== 'string') return String(p);
    // Normalize separators for comparison only
    const normalized = p.replace(/\\/g, '/');
    const homeNorm   = home.replace(/\\/g, '/');
    return normalized.startsWith(homeNorm)
      ? '~' + normalized.slice(homeNorm.length)
      : p;
  };

  // Three clean buckets — no overlaps
  const globalPaths  = [];  // ~/.claude/** but not rules
  const rulesPaths   = [];  // any path containing /rules/
  const projectPaths = [];  // everything else

  for (const p of paths) {
    const short = shorten(p);
    if (short.includes('/rules/')) {
      rulesPaths.push(short);
    } else if (short.startsWith('~/.claude')) {
      globalPaths.push(short);
    } else {
      projectPaths.push(short);
    }
  }

  const lines = ['📚 claude-solo instructions loaded:'];
  if (globalPaths.length > 0)  lines.push(`   Global:  ${globalPaths.join(', ')}`);
  if (rulesPaths.length > 0)   lines.push(`   Rules:   ${rulesPaths.join(', ')}`);
  if (projectPaths.length > 0) lines.push(`   Project: ${projectPaths.join(', ')}`);

  process.stderr.write(lines.join('\n') + '\n');
});
