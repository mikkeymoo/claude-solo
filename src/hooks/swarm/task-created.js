#!/usr/bin/env node
/**
 * claude-solo TaskCreated hook
 *
 * Fires when a task is being created in an agent team.
 * Validates task quality — blocks vague or oversized tasks.
 *
 * Exit 0: task creation proceeds
 * Exit 2: task creation blocked with feedback
 *
 * Input (stdin): JSON { session_id, cwd, hook_event_name, task_id, task_subject, task_description }
 */

import { createInterface } from 'readline';

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

  // Fields are top-level: task_subject, task_description (not nested under task)
  const title = input.task_subject || input.task_description || '';
  const desc = input.task_description || '';
  const issues = [];

  // Rule 1: Task must have a meaningful title (>10 chars)
  if (title.length < 10) {
    issues.push('Task title is too vague. Provide a specific, actionable description (>10 chars).');
  }

  // Rule 2: Block obviously vague tasks
  const vaguePatterns = [
    /^(do|fix|update|change|implement)\s+(it|this|that|stuff|things?)$/i,
    /^todo$/i,
    /^work on/i,
    /^misc/i,
  ];
  for (const pattern of vaguePatterns) {
    if (pattern.test(title.trim())) {
      issues.push(`Task "${title}" is too vague. Break it into a specific, atomic action.`);
      break;
    }
  }

  // Rule 3: Warn about mega-tasks (very long descriptions suggest scope creep)
  if (desc.length > 2000) {
    issues.push('Task description is very long (>2000 chars). Consider splitting into smaller tasks.');
  }

  // Rule 4: Check for "and" in title suggesting compound tasks
  const andCount = (title.match(/\band\b/gi) || []).length;
  if (andCount >= 2) {
    issues.push(`Task title contains ${andCount} "and" conjunctions. Split compound tasks into separate atomic tasks.`);
  }

  if (issues.length > 0) {
    const feedback = [
      'Task creation blocked. Please fix:',
      ...issues.map((issue, i) => `${i + 1}. ${issue}`),
    ].join('\n');

    process.stderr.write(`\n🚫 claude-solo swarm: task quality gate\n${feedback}\n`);
    process.exit(2);
  }

  process.stderr.write(`\n📋 claude-solo swarm: task created → "${title.slice(0, 80)}"\n`);
  process.exit(0);
});
