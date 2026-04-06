#!/usr/bin/env node
/**
 * claude-solo SubagentStop hook
 *
 * Captures subagent outputs as durable artifacts under .planning/agent-outputs/.
 * Reviewer findings, debugger diagnoses, and test results survive context compaction.
 *
 * Input (stdin): JSON { agent_name, agent_type, result, duration_ms }
 * Output: none required
 */

import { createInterface } from 'readline';
import { writeFileSync, mkdirSync } from 'fs';
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

  const { agent_name, agent_type, result, duration_ms } = input;

  // Only capture agents with meaningful output
  if (!result || (typeof result === 'string' && result.length < 50)) {
    return;
  }

  // Determine agent label
  const label = agent_name || agent_type || 'unknown-agent';
  const safeLabel = label.replace(/[^a-zA-Z0-9_-]/g, '-').slice(0, 50);
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-');

  const cwd = process.cwd();
  const outputDir = join(cwd, '.planning', 'agent-outputs');
  const outputFile = join(outputDir, `${safeLabel}-${timestamp}.md`);

  const content = [
    `# Agent Output: ${label}`,
    ``,
    `- Type: ${agent_type || 'unknown'}`,
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
});
