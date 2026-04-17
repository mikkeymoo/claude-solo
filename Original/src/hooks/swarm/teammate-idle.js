#!/usr/bin/env node
/**
 * claude-solo TeammateIdle hook
 *
 * Fires when a teammate in an agent team is about to go idle.
 * Acts as a quality gate — checks if the teammate's work meets
 * minimum standards before allowing it to stop.
 *
 * Exit 0: teammate goes idle normally
 * Exit 2: teammate gets feedback and keeps working
 *
 * Input (stdin): JSON { session_id, cwd, hook_event_name, agent_id, agent_type }
 * Output (stdout): JSON with optional feedback
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

  // Quality checks based on agent type
  const checks = [];

  // Check 1: If this was an implementer, verify no lint/type errors were left
  if (agent_type && /implement|build|code|develop/i.test(agent_type)) {
    try {
      // Check for uncommitted changes (work not committed = not done)
      const status = execSync('git status --porcelain', {
        cwd: projectDir, encoding: 'utf8', timeout: 5000
      }).trim();

      if (status) {
        const changedFiles = status.split('\n').length;
        checks.push(`You have ${changedFiles} uncommitted file(s). Commit your work before going idle.`);
      }
    } catch { /* git not available */ }
  }

  // Check 2: If this was a tester, verify tests actually ran
  if (agent_type && /test|qa|quality/i.test(agent_type)) {
    const testIndicators = [
      'test-results', 'coverage', 'junit.xml', '.nyc_output',
      'test-report.html', 'test-report.json'
    ];
    const hasTestOutput = testIndicators.some(f =>
      existsSync(join(projectDir, f))
    );

    // Check .planning for test evidence
    const planningDir = join(projectDir, '.planning', 'agent-outputs');
    let hasTestEvidence = false;
    if (existsSync(planningDir)) {
      const files = readdirSync(planningDir);
      hasTestEvidence = files.some(f => /test/i.test(f));
    }

    if (!hasTestOutput && !hasTestEvidence) {
      checks.push('No test output detected. Run the test suite and report results before going idle.');
    }
  }

  // Check 3: If this was a reviewer, verify findings were documented
  if (agent_type && /review|audit|security/i.test(agent_type)) {
    const planningDir = join(projectDir, '.planning', 'agent-outputs');
    let hasReviewOutput = false;
    if (existsSync(planningDir)) {
      const files = readdirSync(planningDir);
      hasReviewOutput = files.some(f => /review|audit|security/i.test(f));
    }

    if (!hasReviewOutput) {
      checks.push('No review findings documented. Save your findings to .planning/ before going idle.');
    }
  }

  // If any checks failed, send feedback and keep teammate working
  if (checks.length > 0) {
    const feedback = [
      'Before going idle, please address:',
      ...checks.map((c, i) => `${i + 1}. ${c}`),
    ].join('\n');

    process.stderr.write(`\n🔄 claude-solo swarm: teammate quality gate triggered\n${feedback}\n`);
    process.exit(2);
  }

  // All good — let teammate go idle
  process.stderr.write(`\n✅ claude-solo swarm: teammate ${agent_type || 'unknown'} passed quality gate\n`);
  process.exit(0);
});
