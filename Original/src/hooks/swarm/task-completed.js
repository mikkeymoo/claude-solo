#!/usr/bin/env node
/**
 * claude-solo TaskCompleted hook
 *
 * Fires when a task is being marked as complete in an agent team.
 * Validates that the task was actually done — not just claimed as done.
 *
 * Exit 0: completion proceeds
 * Exit 2: completion blocked with feedback
 *
 * Input (stdin): JSON { session_id, cwd, hook_event_name, task, agent_id, agent_type }
 */

import { createInterface } from 'readline';
import { existsSync } from 'fs';
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

  const { task, agent_type, cwd } = input;
  const projectDir = cwd || process.cwd();
  const title = (task?.title || task?.name || task?.description || '').toLowerCase();
  const issues = [];

  // Check if task involves code changes — verify git shows actual modifications
  const codeTaskPatterns = /\b(implement|create|add|build|write|fix|refactor|update|modify)\b/i;
  if (codeTaskPatterns.test(title)) {
    try {
      const diff = execSync('git diff --stat HEAD', {
        cwd: projectDir, encoding: 'utf8', timeout: 5000
      }).trim();

      const stagedDiff = execSync('git diff --stat --cached', {
        cwd: projectDir, encoding: 'utf8', timeout: 5000
      }).trim();

      // Check recent commits (last 5 minutes) for evidence of work
      let recentCommits = '';
      try {
        recentCommits = execSync('git log --oneline --since="5 minutes ago"', {
          cwd: projectDir, encoding: 'utf8', timeout: 5000
        }).trim();
      } catch { /* ok */ }

      if (!diff && !stagedDiff && !recentCommits) {
        issues.push(
          'Task claims code changes but no git modifications detected. ' +
          'Commit your changes or verify the task was actually completed.'
        );
      }
    } catch { /* git not available — skip check */ }
  }

  // Check if task involves tests — verify test files exist or were modified
  if (/\b(test|spec|e2e|integration)\b/i.test(title)) {
    try {
      const recentTestChanges = execSync(
        'git diff --name-only HEAD | grep -iE "\\.(test|spec)\\.(ts|js|tsx|jsx|py)$"',
        { cwd: projectDir, encoding: 'utf8', timeout: 5000 }
      ).trim();

      if (!recentTestChanges) {
        // Check staged
        const stagedTestChanges = execSync(
          'git diff --name-only --cached | grep -iE "\\.(test|spec)\\.(ts|js|tsx|jsx|py)$"',
          { cwd: projectDir, encoding: 'utf8', timeout: 5000 }
        ).trim();

        if (!stagedTestChanges) {
          issues.push(
            'Task involves testing but no test files were modified. ' +
            'Write or update test files before marking complete.'
          );
        }
      }
    } catch { /* grep no matches or git not available */ }
  }

  // Check if task involves documentation — verify docs were touched
  if (/\b(document|docs|readme|changelog)\b/i.test(title)) {
    try {
      const docChanges = execSync(
        'git diff --name-only HEAD | grep -iE "\\.(md|rst|txt)$"',
        { cwd: projectDir, encoding: 'utf8', timeout: 5000 }
      ).trim();

      if (!docChanges) {
        issues.push(
          'Task involves documentation but no doc files were modified. ' +
          'Update the relevant documentation before marking complete.'
        );
      }
    } catch { /* ok */ }
  }

  if (issues.length > 0) {
    const feedback = [
      'Task completion blocked. Evidence missing:',
      ...issues.map((issue, i) => `${i + 1}. ${issue}`),
    ].join('\n');

    process.stderr.write(`\n🚫 claude-solo swarm: task completion gate\n${feedback}\n`);
    process.exit(2);
  }

  process.stderr.write(`\n✅ claude-solo swarm: task "${(title).slice(0, 60)}" verified complete\n`);
  process.exit(0);
});
