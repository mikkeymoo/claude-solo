#!/usr/bin/env node
/**
 * claude-solo SubagentStart hook
 *
 * Fires when a subagent is spawned. Injects swarm context so every
 * agent (whether subagent or teammate) starts with project awareness.
 *
 * Input (stdin): JSON { session_id, cwd, hook_event_name, agent_id, agent_type }
 * Output (stdout): JSON with additionalContext
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
    process.exit(0);
  }

  const { agent_type, cwd } = input;
  const projectDir = cwd || process.cwd();
  const contextParts = [];

  // Inject git state
  try {
    const branch = execSync('git rev-parse --abbrev-ref HEAD', {
      cwd: projectDir, encoding: 'utf8', timeout: 5000
    }).trim();
    const lastCommit = execSync('git log -1 --oneline', {
      cwd: projectDir, encoding: 'utf8', timeout: 5000
    }).trim();
    contextParts.push(`Git: ${branch} @ ${lastCommit}`);
  } catch { /* not a git repo */ }

  // Inject sprint state if available
  const planning = join(projectDir, '.planning');
  if (existsSync(planning)) {
    for (const file of ['BRIEF.md', 'PLAN.md']) {
      const fp = join(planning, file);
      if (existsSync(fp)) {
        const content = readFileSync(fp, 'utf8').slice(0, 500);
        contextParts.push(`[${file}]\n${content}`);
      }
    }
  }

  // Inject team awareness — list other recent agent outputs
  const agentOutputs = join(projectDir, '.planning', 'agent-outputs');
  if (existsSync(agentOutputs)) {
    try {
      const recentOutputs = readdirSync(agentOutputs)
        .filter(f => f.endsWith('.md'))
        .slice(-5)  // last 5
        .map(f => f.replace('.md', ''));

      if (recentOutputs.length > 0) {
        contextParts.push(`Recent agent outputs: ${recentOutputs.join(', ')}`);
      }
    } catch { /* ok */ }
  }

  // Inject coordination rules based on agent type
  if (agent_type) {
    const rules = getCoordinationRules(agent_type);
    if (rules) {
      contextParts.push(rules);
    }
  }

  if (contextParts.length > 0) {
    const context = contextParts.join('\n\n');
    const output = {
      hookSpecificOutput: {
        hookEventName: 'SubagentStart',
        additionalContext: `[claude-solo swarm context]\n${context}`
      }
    };
    process.stdout.write(JSON.stringify(output));
    process.stderr.write(`\n🐝 claude-solo swarm: injected context for ${agent_type || 'agent'}\n`);
  }

  process.exit(0);
});

function getCoordinationRules(agentType) {
  const type = agentType.toLowerCase();

  if (/implement|build|code|develop/.test(type)) {
    return [
      'COORDINATION RULES:',
      '- Commit atomically: one logical change per commit',
      '- Use feat:/fix:/refactor: prefixes in commit messages',
      '- Do not modify files other teammates are working on',
      '- Save your progress to .planning/agent-outputs/ when done',
    ].join('\n');
  }

  if (/research|explore|investigate/.test(type)) {
    return [
      'COORDINATION RULES:',
      '- Document all findings in .planning/agent-outputs/',
      '- Be thorough but concise — other agents will read your output',
      '- Flag blockers or risks prominently at the top of your report',
      '- Include file paths and line numbers for anything you reference',
    ].join('\n');
  }

  if (/review|audit|security/.test(type)) {
    return [
      'COORDINATION RULES:',
      '- Use priority format: RED (must fix), YELLOW (should fix), BLUE (consider)',
      '- Include file:line for every finding',
      '- Auto-fix RED issues if you have write access',
      '- Save findings to .planning/agent-outputs/',
    ].join('\n');
  }

  if (/test|qa|quality/.test(type)) {
    return [
      'COORDINATION RULES:',
      '- Run existing tests first before writing new ones',
      '- Report pass/fail counts and any regressions',
      '- Write tests that catch real bugs, not coverage theater',
      '- Save test results to .planning/agent-outputs/',
    ].join('\n');
  }

  return null;
}
