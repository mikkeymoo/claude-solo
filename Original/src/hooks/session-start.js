#!/usr/bin/env node
/**
 * claude-solo SessionStart hook
 *
 * Fires when a new or resumed session begins. Injects useful context
 * into stderr so Claude (and the user) know the current project state.
 *
 * Input (stdin): JSON { session_id, cwd, resumed }
 * Output: none required — informational only
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync, readdirSync } from 'fs';
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

  const cwd = input.cwd || process.cwd();
  const parts = [];

  // ── Git state ───────────────────────────────────────────────────────────
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const status = execSync('git status --porcelain', { cwd, encoding: 'utf8', timeout: 5000 }).trim();
    const dirtyCount = status ? status.split('\n').length : 0;
    const lastCommit = execSync('git log -1 --oneline', { cwd, encoding: 'utf8', timeout: 5000 }).trim();

    let branchLine = `Branch: ${branch}`;
    if (dirtyCount > 0) branchLine += ` (${dirtyCount} dirty)`;
    parts.push(branchLine);
    parts.push(`Last commit: ${lastCommit}`);
  } catch {
    // Not a git repo or git not available — skip
  }

  // ── Sprint state from .planning/ ────────────────────────────────────────
  const planning = join(cwd, '.planning');
  if (existsSync(planning)) {
    const planningFiles = ['BRIEF.md', 'PLAN.md', 'PAUSE.md', 'HANDOFF.md'];
    const found = planningFiles.filter(f => existsSync(join(planning, f)));
    if (found.length > 0) {
      parts.push(`Sprint docs: ${found.join(', ')}`);
    }

    // If HANDOFF.md or PAUSE.md exists, surface the next-step
    for (const resumeFile of ['HANDOFF.md', 'PAUSE.md']) {
      const fp = join(planning, resumeFile);
      if (existsSync(fp)) {
        const content = readFileSync(fp, 'utf8');
        const nextMatch = content.match(/##\s*Next\s*(task|step|action)[^\n]*\n([^\n#]+)/i);
        if (nextMatch) {
          parts.push(`Resume: ${nextMatch[2].trim().slice(0, 120)}`);
        }
        break;
      }
    }
  }

  // ── Pending verification ────────────────────────────────────────────────
  const verifyPath = join(cwd, '.planning', 'VERIFY.md');
  if (existsSync(verifyPath)) {
    const content = readFileSync(verifyPath, 'utf8');
    const statusMatch = content.match(/Status:\s*(PASS|FAIL|PENDING)/i);
    if (statusMatch) {
      const icon = statusMatch[1].toUpperCase() === 'PASS' ? '✅' : statusMatch[1].toUpperCase() === 'FAIL' ? '🔴' : '⏳';
      parts.push(`Verification: ${icon} ${statusMatch[1]}`);
    }
  }

  // ── Environment check ───────────────────────────────────────────────────
  const envExample = join(cwd, '.env.example');
  const envFile = join(cwd, '.env');
  if (existsSync(envExample) && !existsSync(envFile)) {
    parts.push('⚠️  .env.example exists but .env is missing');
  }

  // ── Output ──────────────────────────────────────────────────────────────
  if (parts.length > 0) {
    process.stderr.write(`\n📋 claude-solo session context:\n   ${parts.join('\n   ')}\n\n`);
  }
});
