#!/usr/bin/env node
/**
 * claude-solo WorktreeCreate hook
 *
 * Fires when a new git worktree is created (e.g. for a subagent).
 * Copies gitignored files (secrets, .env) into the new worktree so
 * agents can run the app without manual setup.
 *
 * Config: .claude/worktree-copy-list (one relative path per line)
 * If the file doesn't exist, a default one is created automatically.
 *
 * Input (stdin): JSON { worktree_path, branch, cwd, ... }
 * Output: none required
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'fs';
import { join, dirname, resolve } from 'path';

const DEFAULT_COPY_LIST = `.env
.env.local
.env.development
secrets.json
`;

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

  const worktreePath = input.worktree_path;
  if (!worktreePath) {
    process.stderr.write('⚠️  claude-solo worktree-create: no worktree_path in hook input\n');
    return;
  }

  const cwd = input.cwd || process.cwd();
  const claudeDir = join(cwd, '.claude');
  const copyListPath = join(claudeDir, 'worktree-copy-list');

  // Create default copy list if absent
  if (!existsSync(copyListPath)) {
    try {
      mkdirSync(claudeDir, { recursive: true });
      writeFileSync(copyListPath, DEFAULT_COPY_LIST);
      process.stderr.write('📄 claude-solo: created .claude/worktree-copy-list with defaults (.env, .env.local, .env.development, secrets.json)\n');
    } catch {
      // Not fatal
    }
  }

  let filesToCopy;
  try {
    filesToCopy = readFileSync(copyListPath, 'utf8')
      .split('\n')
      .map(l => l.trim())
      .filter(l => l && !l.startsWith('#'));
  } catch {
    return;
  }

  let copied = 0;
  let skipped = 0;

  for (const relPath of filesToCopy) {
    // Guard against path traversal (absolute paths or .. sequences)
    const srcPath = resolve(cwd, relPath);
    if (!srcPath.startsWith(cwd + '/') && !srcPath.startsWith(cwd + '\\') && srcPath !== cwd) {
      process.stderr.write(`⚠️  claude-solo: skipping "${relPath}" — path resolves outside project root\n`);
      skipped++;
      continue;
    }

    const destPath = join(worktreePath, relPath);

    if (!existsSync(srcPath)) {
      skipped++;
      continue;
    }

    try {
      const destDir = dirname(destPath);
      mkdirSync(destDir, { recursive: true });
      copyFileSync(srcPath, destPath);
      copied++;
    } catch (err) {
      process.stderr.write(`⚠️  claude-solo: failed to copy ${relPath} to worktree: ${err.message}\n`);
    }
  }

  if (copied > 0) {
    process.stderr.write(`📋 claude-solo: copied ${copied} file(s) into worktree (${skipped} not found, skipped)\n`);
  }
});
