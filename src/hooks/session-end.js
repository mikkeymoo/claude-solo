#!/usr/bin/env node
/**
 * claude-solo SessionEnd hook
 *
 * Fires when a session ends. Writes a durable end-of-session summary
 * to .planning/SESSION-END.md so the next session can pick up cleanly.
 *
 * Input (stdin): JSON { session_id, cwd }
 * Output: none required
 */

import { createInterface } from 'readline';
import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { execSync } from 'child_process';
import os from 'os';

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

  const cwd = input.cwd || process.cwd();
  const planningDir = join(cwd, '.planning');
  const summaryPath = join(planningDir, 'SESSION-END.md');

  const parts = [];
  parts.push('# Session End Summary');
  parts.push(`\nEnded: ${new Date().toISOString()}`);

  // ── Git diff since session (approximate via recent commits) ─────────────
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const status = execSync('git status --porcelain', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const recentCommits = execSync('git log --oneline -10 --since="3 hours ago"', { cwd, encoding: 'utf8', timeout: 5000 }).trim();

    parts.push('\n## What Changed');
    parts.push(`Branch: ${branch}`);

    if (recentCommits) {
      parts.push(`\nCommits this session:\n\`\`\`\n${recentCommits}\n\`\`\``);
    } else {
      parts.push('No commits in the last 3 hours.');
    }

    if (status) {
      const lines = status.split('\n');
      parts.push(`\nUncommitted changes (${lines.length} files):\n${lines.slice(0, 15).map(l => `- ${l}`).join('\n')}`);
      if (lines.length > 15) parts.push(`  ... and ${lines.length - 15} more`);
    } else {
      parts.push('Working tree: clean');
    }

    // Diffstat of uncommitted changes
    try {
      const diffstat = execSync('git diff --stat', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
      if (diffstat) {
        parts.push(`\nDiff summary:\n\`\`\`\n${diffstat}\n\`\`\``);
      }
    } catch { /* skip */ }
  } catch {
    parts.push('\n## What Changed\nGit unavailable');
  }

  // ── Verification state ──────────────────────────────────────────────────
  const verifyPath = join(planningDir, 'VERIFY.md');
  if (existsSync(verifyPath)) {
    try {
      const content = readFileSync(verifyPath, 'utf8');
      const statusMatch = content.match(/Status:\s*(PASS|FAIL|PENDING)/i);
      if (statusMatch) {
        parts.push(`\n## Verification State\n${statusMatch[1]}`);
      }
    } catch { /* skip */ }
  }

  // ── Token usage today ───────────────────────────────────────────────────
  const dateStr = new Date().toISOString().slice(0, 10);
  const tokenFile = join(os.homedir(), '.claude', 'logs', `tokens-${dateStr}.json`);
  if (existsSync(tokenFile)) {
    try {
      const stats = JSON.parse(readFileSync(tokenFile, 'utf8'));
      const k = (n) => n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(n);
      parts.push(`\n## Token Usage Today\n- Calls: ${stats.calls}\n- Tokens: ~${k(stats.total_tokens)} (${k(stats.input_tokens)} in / ${k(stats.output_tokens)} out)`);
    } catch { /* skip */ }
  }

  // ── Open risks / next steps hint ────────────────────────────────────────
  parts.push('\n## Next Session');
  parts.push('Run `/mm:resume` or check `.planning/HANDOFF.md` if available.');

  // ── Write summary ───────────────────────────────────────────────────────
  try {
    mkdirSync(planningDir, { recursive: true });
    writeFileSync(summaryPath, parts.join('\n') + '\n');
    process.stderr.write('📝 claude-solo: session summary saved to .planning/SESSION-END.md\n');
  } catch (err) {
    process.stderr.write(`⚠️  claude-solo: failed to save session summary: ${err.message}\n`);
  }
});
