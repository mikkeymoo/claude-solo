#!/usr/bin/env node
/**
 * claude-solo build-checker hook (PostToolUse)
 *
 * Opt-in: set CLAUDE_SOLO_BUILD_CHECK=1 to enable.
 * Advisory only — writes to stderr, never blocks.
 *
 * After TypeScript/JavaScript files are edited, surfaces a reminder
 * to run type checks. Does not auto-run builds (too slow, too invasive).
 *
 * Input (stdin): JSON { tool_name, tool_input, tool_response }
 * Output: none — informational stderr only
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync } from 'fs';
import { join, dirname } from 'path';

if (!process.env.CLAUDE_SOLO_BUILD_CHECK) {
  process.exit(0);
}

const TS_PATTERN = /\.(ts|tsx)$/;
const JS_PATTERN = /\.(js|jsx|mjs|cjs)$/;

function findTsConfig(filePath) {
  const root = process.cwd();
  let dir = dirname(filePath);
  while (dir.length >= root.length) {
    if (existsSync(join(dir, 'tsconfig.json'))) return true;
    const parent = dirname(dir);
    if (parent === dir) break;
    dir = parent;
  }
  return false;
}

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
  if (!['Write', 'Edit'].includes(tool_name)) return;

  const file = tool_input?.file_path || tool_input?.path || '';
  if (!file) return;

  if (TS_PATTERN.test(file) && findTsConfig(file)) {
    process.stderr.write(
      '🔧 claude-solo: TypeScript file modified — run `rtk tsc --noEmit` to check for type errors\n'
    );
    return;
  }

  if (JS_PATTERN.test(file)) {
    const pkgPath = join(process.cwd(), 'package.json');
    if (existsSync(pkgPath)) {
      try {
        const pkg = JSON.parse(readFileSync(pkgPath, 'utf8'));
        if (pkg.scripts?.lint) {
          process.stderr.write(
            '🔧 claude-solo: JS file modified — run `rtk npm run lint` to check for issues\n'
          );
        }
      } catch { /* not fatal */ }
    }
  }
});
