#!/usr/bin/env node
/**
 * claude-solo WorktreeCreate hook
 *
 * Fires BEFORE a new git worktree is created. This hook is responsible
 * for creating the worktree (Claude Code does NOT create it automatically).
 * After creation, copies gitignored files (.env etc.) into the new worktree.
 *
 * Input (stdin): JSON { base_directory, worktree_name, source_ref, isolation_scope, ... }
 * Output (stdout): absolute path to the created worktree (single line, plain text)
 *
 * Config: .claude/worktree-copy-list (one relative path per line)
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync, writeFileSync, mkdirSync, copyFileSync } from 'fs';
import { join, dirname, resolve } from 'path';
import { execSync } from 'child_process';

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
    process.stderr.write('⚠️  claude-solo worktree-create: failed to parse hook input JSON\n');
    process.exit(1);
  }

  const baseDir = input.base_directory || input.cwd;
  const worktreeName = input.worktree_name || `claude-wt-${Date.now()}`;
  const sourceRef = input.source_ref || 'HEAD';

  if (!baseDir) {
    process.stderr.write('⚠️  claude-solo worktree-create: no base_directory in hook input\n');
    process.exit(1);
  }

  // Place worktrees in a standard location outside the repo
  const worktreePath = resolve(baseDir, '..', '.claude-worktrees', worktreeName);

  // Create worktree — suppress all stdout/stderr from git
  try {
    mkdirSync(resolve(baseDir, '..', '.claude-worktrees'), { recursive: true });
    execSync(
      `git -C "${baseDir}" worktree add --detach "${worktreePath}" ${sourceRef}`,
      { stdio: 'pipe' }
    );
  } catch (err) {
    process.stderr.write(`⚠️  claude-solo worktree-create: git worktree add failed: ${err.message}\n`);
    process.exit(1);
  }

  // Copy gitignored config files into the new worktree
  const claudeDir = join(baseDir, '.claude');
  const copyListPath = join(claudeDir, 'worktree-copy-list');

  if (!existsSync(copyListPath)) {
    try {
      mkdirSync(claudeDir, { recursive: true });
      writeFileSync(copyListPath, DEFAULT_COPY_LIST);
    } catch {
      // Not fatal
    }
  }

  let filesToCopy = [];
  try {
    filesToCopy = readFileSync(copyListPath, 'utf8')
      .split('\n')
      .map(l => l.trim())
      .filter(l => l && !l.startsWith('#'));
  } catch {
    // Not fatal — proceed without copying
  }

  let copied = 0;
  for (const relPath of filesToCopy) {
    const srcPath = resolve(baseDir, relPath);
    // Guard against path traversal
    if (!srcPath.startsWith(baseDir + '/') && !srcPath.startsWith(baseDir + '\\') && srcPath !== baseDir) {
      process.stderr.write(`⚠️  claude-solo worktree-create: skipping "${relPath}" — outside project root\n`);
      continue;
    }
    if (!existsSync(srcPath)) continue;
    try {
      const destPath = join(worktreePath, relPath);
      mkdirSync(dirname(destPath), { recursive: true });
      copyFileSync(srcPath, destPath);
      copied++;
    } catch {
      // Not fatal
    }
  }

  if (copied > 0) {
    process.stderr.write(`📋 claude-solo: copied ${copied} file(s) into worktree\n`);
  }

  // Output the worktree path — this is what Claude Code reads to find the worktree
  process.stdout.write(worktreePath + '\n');
  process.exit(0);
});
