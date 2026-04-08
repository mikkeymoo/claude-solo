#!/usr/bin/env node
/**
 * claude-solo Stop gate hook (for swarm sessions)
 *
 * Fires when the lead agent tries to stop. Checks if all teammates
 * have finished and all tasks are resolved before allowing shutdown.
 *
 * This is optional — only used when CLAUDE_SOLO_SWARM_GATE=1 is set.
 *
 * Exit 0: stop proceeds
 * Exit 2: stop blocked, agent continues working
 *
 * Input (stdin): JSON { session_id, cwd, hook_event_name }
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync, readdirSync } from 'fs';
import { join } from 'path';
import os from 'os';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  // Only enforce if swarm gate is enabled
  if (process.env.CLAUDE_SOLO_SWARM_GATE !== '1') {
    process.exit(0);
  }

  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.exit(0);
  }

  const issues = [];

  // Check for active team config
  const teamsDir = join(os.homedir(), '.claude', 'teams');
  if (existsSync(teamsDir)) {
    try {
      const teams = readdirSync(teamsDir);
      for (const team of teams) {
        const configPath = join(teamsDir, team, 'config.json');
        if (existsSync(configPath)) {
          const config = JSON.parse(readFileSync(configPath, 'utf8'));
          const members = config.members || [];
          const active = members.filter(m => m.status === 'active' || !m.status);

          if (active.length > 0) {
            issues.push(
              `Team "${team}" still has ${active.length} active teammate(s). ` +
              `Ask them to finish and shut down before stopping.`
            );
          }
        }
      }
    } catch { /* ok */ }
  }

  // Check for pending tasks in .planning
  const cwd = input.cwd || process.cwd();
  const tasksDir = join(os.homedir(), '.claude', 'tasks');
  if (existsSync(tasksDir)) {
    try {
      const taskTeams = readdirSync(tasksDir);
      for (const team of taskTeams) {
        const teamTaskDir = join(tasksDir, team);
        const taskFiles = readdirSync(teamTaskDir).filter(f => f.endsWith('.json'));

        for (const taskFile of taskFiles) {
          try {
            const task = JSON.parse(readFileSync(join(teamTaskDir, taskFile), 'utf8'));
            if (task.status === 'pending' || task.status === 'in_progress') {
              issues.push(`Task "${task.title || taskFile}" is still ${task.status}.`);
            }
          } catch { /* skip malformed */ }
        }
      }
    } catch { /* ok */ }
  }

  if (issues.length > 0) {
    const feedback = [
      'Cannot stop — swarm work is incomplete:',
      ...issues.slice(0, 5).map((issue, i) => `${i + 1}. ${issue}`),
      issues.length > 5 ? `... and ${issues.length - 5} more issues` : '',
      '',
      'Resolve these or set CLAUDE_SOLO_SWARM_GATE=0 to disable this check.',
    ].filter(Boolean).join('\n');

    process.stderr.write(`\n🛑 claude-solo swarm: stop blocked\n${feedback}\n`);
    process.exit(2);
  }

  process.exit(0);
});
