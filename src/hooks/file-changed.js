#!/usr/bin/env node
/**
 * claude-solo FileChanged hook
 *
 * Fires when a watched dependency/config file changes during a session.
 * Injects a drift warning so Claude doesn't give stale advice based on
 * the old dependency state.
 *
 * Watched files (set via matcher in settings.json):
 *   package.json, pyproject.toml, requirements.txt, Cargo.toml, go.mod, .env.example
 *
 * Input (stdin): JSON { file_path, cwd, ... }
 * Output (stdout): JSON { additionalContext: "..." }
 */

import { createInterface } from 'readline';
import { basename } from 'path';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

// Per-file advice
const FILE_ADVICE = {
  'package.json': {
    label: 'Node.js dependencies',
    action: 'Run `npm install` or `pnpm install` to sync node_modules.',
    note: 'Check for new/removed packages before suggesting imports.',
  },
  'pnpm-lock.yaml': {
    label: 'pnpm lockfile',
    action: 'Run `pnpm install` to apply lockfile changes.',
    note: null,
  },
  'package-lock.json': {
    label: 'npm lockfile',
    action: 'Run `npm install` to apply lockfile changes.',
    note: null,
  },
  'pyproject.toml': {
    label: 'Python project config',
    action: 'Run `pip install -e .` or `uv sync` to update environment.',
    note: 'Check [tool.pytest], [tool.ruff] sections if config changed.',
  },
  'requirements.txt': {
    label: 'Python requirements',
    action: 'Run `pip install -r requirements.txt` to sync packages.',
    note: 'Check for new/removed packages before suggesting imports.',
  },
  'Cargo.toml': {
    label: 'Rust dependencies',
    action: 'Run `cargo build` or `cargo check` to resolve new deps.',
    note: 'Check for new/removed crates before suggesting `use` statements.',
  },
  'go.mod': {
    label: 'Go module dependencies',
    action: 'Run `go mod tidy` to sync dependencies.',
    note: 'Check for new/removed packages before suggesting imports.',
  },
  '.env.example': {
    label: 'Environment variables template',
    action: 'Review .env.example — new required env vars may need to be added to .env.',
    note: 'Check if any secrets/config are now required that were not before.',
  },
};

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  const filePath = input.file_path || '';
  const fileName = basename(filePath);
  const advice = FILE_ADVICE[fileName];

  const label = advice?.label || 'dependency/config file';
  const action = advice?.action || 'Review the file and re-run install if needed.';
  const note = advice?.note;

  const lines = [
    `## Dependency Drift Warning: \`${fileName}\` Changed`,
    '',
    `The \`${fileName}\` (${label}) changed while this session is active.`,
    '',
    `**Recommended action:** ${action}`,
  ];

  if (note) {
    lines.push(`**Note:** ${note}`);
  }

  lines.push('');
  lines.push('Your current assumptions about available packages/modules may be stale.');

  const additionalContext = lines.join('\n');

  process.stderr.write(`⚠️  claude-solo: ${fileName} changed — dependency drift possible\n`);
  process.stdout.write(JSON.stringify({ additionalContext }));
});
