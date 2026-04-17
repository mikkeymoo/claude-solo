#!/usr/bin/env node
/**
 * claude-solo prompt-submit hook
 *
 * Runs when you submit a prompt to Claude. Adds context from your
 * .planning/ directory automatically — so Claude always knows the
 * current sprint state without you having to paste it in.
 *
 * Input (stdin): JSON { prompt }
 * Output (stdout): JSON { prompt } (modified or pass-through)
 */

import { createInterface } from 'readline';
import { existsSync, readFileSync } from 'fs';
import { join } from 'path';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(raw);
    return;
  }

  const { prompt } = input;
  const planning = join(process.cwd(), '.planning');

  // If .planning/ exists, inject current sprint context silently
  if (existsSync(planning)) {
    const contextParts = [];

    const files = {
      'BRIEF.md': 'Current sprint brief',
      'PLAN.md': 'Current sprint plan',
    };

    for (const [file, label] of Object.entries(files)) {
      const filePath = join(planning, file);
      if (existsSync(filePath)) {
        const content = readFileSync(filePath, 'utf8').slice(0, 800); // cap at 800 chars
        contextParts.push(`[${label}]\n${content}`);
      }
    }

    if (contextParts.length > 0) {
      const injected = `${prompt}\n\n---\n<!-- Sprint context (auto-injected by claude-solo) -->\n${contextParts.join('\n\n')}`;
      process.stdout.write(JSON.stringify({ ...input, prompt: injected }));
      return;
    }
  }

  // No planning context — pass through unchanged
  process.stdout.write(JSON.stringify(input));
});
