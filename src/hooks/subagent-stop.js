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
});
