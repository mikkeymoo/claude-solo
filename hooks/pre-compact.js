#!/usr/bin/env node
/**
 * claude-solo PreCompact hook
 *
 * Fires before Claude compresses context. Saves a checkpoint so the
 * compacted session can still pick up where it left off.
 *
 * Writes .planning/CHECKPOINT.md with current state.
 *
 * Input (stdin): JSON { summary }
 * Output: none required
 */

import { createInterface } from 'readline';
import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'fs';
import { join } from 'path';
import { execSync } from 'child_process';

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

  const cwd = process.cwd();
  const planningDir = join(cwd, '.planning');
  const checkpointPath = join(planningDir, 'CHECKPOINT.md');

  const parts = [];
  parts.push('# Context Checkpoint');
  parts.push(`\nSaved: ${new Date().toISOString()}`);
  parts.push('Reason: pre-compact (context compression imminent)\n');

  // ── Git state ───────────────────────────────────────────────────────────
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const status = execSync('git status --porcelain', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const lastCommit = execSync('git log -1 --oneline', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const recentCommits = execSync('git log --oneline -5', { cwd, encoding: 'utf8', timeout: 5000 }).trim();

    parts.push('## Git State');
    parts.push(`- Branch: ${branch}`);
    parts.push(`- Last commit: ${lastCommit}`);
    if (status) {
      parts.push(`- Dirty files:\n${status.split('\n').map(l => `  - ${l}`).join('\n')}`);
    } else {
      parts.push('- Working tree: clean');
    }
    parts.push(`\nRecent commits:\n\`\`\`\n${recentCommits}\n\`\`\``);
  } catch {
    parts.push('## Git State\nUnavailable');
  }

  // ── Sprint docs ─────────────────────────────────────────────────────────
  if (existsSync(planningDir)) {
    const sprintFiles = ['BRIEF.md', 'PLAN.md', 'PAUSE.md', 'HANDOFF.md', 'VERIFY.md'];
    for (const file of sprintFiles) {
      const fp = join(planningDir, file);
      if (existsSync(fp)) {
        try {
          const content = readFileSync(fp, 'utf8').slice(0, 600);
          parts.push(`\n## ${file}\n\`\`\`\n${content}\n\`\`\``);
        } catch { /* skip */ }
      }
    }
  }

  // ── Compact summary from Claude ─────────────────────────────────────────
  if (input.summary) {
    parts.push(`\n## Claude's Compact Summary\n${input.summary}`);
  }

  // ── Write checkpoint ────────────────────────────────────────────────────
  try {
    mkdirSync(planningDir, { recursive: true });
    writeFileSync(checkpointPath, parts.join('\n') + '\n');
    process.stderr.write('📌 claude-solo: checkpoint saved to .planning/CHECKPOINT.md\n');
  } catch (err) {
    process.stderr.write(`⚠️  claude-solo: failed to save checkpoint: ${err.message}\n`);
  }
});
