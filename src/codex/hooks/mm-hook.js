#!/usr/bin/env node
/**
 * Codex hook wrapper for claude-solo.
 *
 * Usage:
 *   node .codex/hooks/mm-hook.js <event> [--cwd /path] [--prompt "text"]
 *
 * Events map directly to existing Claude hook script names:
 *   session-start, pre-tool-use, post-tool-use, prompt-submit,
 *   permission-request, pre-compact, subagent-stop, session-end
 *
 * Input payload can be piped via stdin JSON; CLI flags patch missing fields.
 */

import { spawnSync } from 'node:child_process';
import { existsSync, readFileSync } from 'node:fs';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { homedir } from 'node:os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const projectRoot = join(__dirname, '..', '..');

const hookMap = {
  'session-start': 'session-start.js',
  'pre-tool-use': 'pre-tool-use.js',
  'post-tool-use': 'post-tool-use.js',
  'prompt-submit': 'prompt-submit.js',
  'permission-request': 'permission-request.js',
  'pre-compact': 'pre-compact.js',
  'subagent-stop': 'subagent-stop.js',
  'session-end': 'session-end.js',
};

function resolveHooksDir() {
  const localProjectHooks = join(projectRoot, '.claude', 'hooks');
  const globalHooks = join(homedir(), '.claude', 'hooks');

  const sourcePointer = join(projectRoot, '.codex', '.claude-solo-source');
  let sourceHooks = '';
  if (existsSync(sourcePointer)) {
    try {
      const sourceRepo = readFileSync(sourcePointer, 'utf8').trim();
      if (sourceRepo) {
        sourceHooks = join(sourceRepo, 'src', 'hooks');
      }
    } catch {}
  }

  const legacyRelativeHooks = join(__dirname, '..', '..', '..', 'src', 'hooks');

  const candidates = [localProjectHooks, globalHooks, sourceHooks, legacyRelativeHooks].filter(Boolean);
  for (const dir of candidates) {
    const probe = join(dir, 'session-start.js');
    if (existsSync(probe)) return dir;
  }
  return '';
}

function parseArgs(argv) {
  const out = { event: argv[2], cwd: process.cwd() };
  for (let i = 3; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--cwd') out.cwd = argv[++i];
    else if (a === '--prompt') out.prompt = argv[++i];
    else if (a === '--tool-name') out.tool_name = argv[++i];
    else if (a === '--command') out.command = argv[++i];
  }
  return out;
}

function readStdin() {
  try {
    const text = readFileSync(0, 'utf8').trim();
    if (!text) return {};
    return JSON.parse(text);
  } catch {
    return {};
  }
}

function buildFallbackPayload(parsed) {
  const base = { cwd: parsed.cwd };

  switch (parsed.event) {
    case 'session-start':
      return { ...base, session_id: 'codex-session', resumed: false };
    case 'session-end':
      return { ...base, session_id: 'codex-session' };
    case 'prompt-submit':
      return { ...base, prompt: parsed.prompt || '' };
    case 'pre-tool-use':
    case 'post-tool-use':
      return {
        ...base,
        tool_name: parsed.tool_name || 'Bash',
        tool_input: { command: parsed.command || '' },
      };
    case 'permission-request':
      return {
        ...base,
        tool_name: parsed.tool_name || 'Bash',
        tool_input: { command: parsed.command || '' },
      };
    case 'pre-compact':
      return { ...base, summary: '' };
    case 'subagent-stop':
      return {
        ...base,
        agent_name: 'codex-agent',
        agent_type: 'default',
        result: '',
        duration_ms: 0,
      };
    default:
      return base;
  }
}

function main() {
  const parsed = parseArgs(process.argv);
  const hookFile = hookMap[parsed.event];

  if (!hookFile) {
    process.stderr.write(`Unknown event: ${parsed.event}\n`);
    process.stderr.write(`Valid events: ${Object.keys(hookMap).join(', ')}\n`);
    process.exit(2);
  }

  const hooksDir = resolveHooksDir();
  if (!hooksDir) {
    process.stderr.write('No claude-solo hooks directory found. Checked project, global, source, and legacy paths.\n');
    process.exit(2);
  }

  const scriptPath = join(hooksDir, hookFile);
  if (!existsSync(scriptPath)) {
    process.stderr.write(`Hook script not found: ${scriptPath}\n`);
    process.exit(2);
  }

  const stdinPayload = readStdin();
  const payload = { ...buildFallbackPayload(parsed), ...stdinPayload };

  const result = spawnSync(process.execPath, [scriptPath], {
    input: JSON.stringify(payload),
    encoding: 'utf8',
    cwd: payload.cwd || process.cwd(),
  });

  if (result.stderr) process.stderr.write(result.stderr);
  if (result.stdout) process.stdout.write(result.stdout);
  process.exit(result.status ?? 0);
}

main();
