#!/usr/bin/env node
/**
 * claude-solo SubagentStop hook
 *
 * Captures subagent outputs as durable artifacts under .planning/agent-outputs/.
 * Reviewer findings, debugger diagnoses, and test results survive context compaction.
 *
 * Input (stdin): JSON from Claude Code's SubagentStop event
 * { agent_id, agent_type, last_assistant_message, cwd, duration_ms, ... }
 */

import { createInterface } from 'readline';
import { writeFileSync, mkdirSync, readdirSync } from 'fs';
import { join } from 'path';
import { spawnSync } from 'child_process';

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

  // Claude Code sends: agent_id, agent_type, last_assistant_message, cwd, duration_ms
  const agent_id = input.agent_id || input.agent_name || 'unknown-agent';
  const agent_type = input.agent_type || 'unknown';
  const result = input.last_assistant_message || input.result;
  const duration_ms = input.duration_ms;
  const cwd = input.cwd || process.cwd();

  // Only capture agents with meaningful output
  if (!result || (typeof result === 'string' && result.length < 50)) {
    return;
  }

  // Determine agent label
  const label = agent_id || agent_type;
  const safeLabel = label.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 50);
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  const outputDir = join(cwd, '.planning', 'agent-outputs');
  const outputFile = join(outputDir, `${safeLabel}-${timestamp}.md`);

  const content = [
    `# Agent Output: ${label}`,
    ``,
    `- Type: ${agent_type}`,
    `- Captured: ${new Date().toISOString()}`,
    duration_ms ? `- Duration: ${(duration_ms / 1000).toFixed(1)}s` : '',
    ``,
    `## Result`,
    ``,
    typeof result === 'string' ? result : JSON.stringify(result, null, 2),
    ``,
  ].filter(Boolean).join('\n');

  try {
    mkdirSync(outputDir, { recursive: true });
    writeFileSync(outputFile, content);
    process.stderr.write(`💾 claude-solo: agent output saved → .planning/agent-outputs/${safeLabel}-${timestamp}.md\n`);
  } catch (err) {
    process.stderr.write(`⚠️  claude-solo: failed to save agent output: ${err.message}\n`);
  }

  // ── Cleanup: remove this agent's worktree if one exists ─────────────────
  const worktreesDir = join(cwd, '.claude', 'worktrees');
  const shortId = agent_id.slice(0, 8);

  try {
    const dirs = readdirSync(worktreesDir);
    for (const dir of dirs) {
      if (dir.includes(shortId)) {
        const wtPath = join(worktreesDir, dir);
        spawnSync('git', ['worktree', 'remove', '--force', wtPath], { cwd });
        process.stderr.write(`🧹 claude-solo: removed worktree ${dir}\n`);
        break;
      }
    }
  } catch { /* worktrees dir doesn't exist or read failed — skip */ }

  // Prune stale git worktree refs regardless
  try {
    spawnSync('git', ['worktree', 'prune'], { cwd });
  } catch { /* skip */ }
});
