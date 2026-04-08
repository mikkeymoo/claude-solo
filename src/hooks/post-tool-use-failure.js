#!/usr/bin/env node
/**
 * claude-solo PostToolUseFailure hook
 *
 * Fires when a tool call fails. Injects structured triage context to help
 * Claude diagnose and fix the failure rather than loop or give up.
 *
 * Input (stdin): JSON { tool_name, tool_input, error, exit_code, cwd, ... }
 * Output (stdout): JSON { additionalContext: "..." }
 */

import { createInterface } from 'readline';

const rl = createInterface({ input: process.stdin });
let raw = '';
rl.on('line', line => raw += line);

// Map failure signatures to triage hints
function triage(toolName, toolInput, error, exitCode) {
  const cmd = toolInput?.command || toolInput?.cmd || '';
  const errStr = (error || '').toLowerCase();
  const hints = [];

  // ── Exit code patterns ──────────────────────────────────────────────────
  if (exitCode === 127) {
    hints.push('Exit 127 = command not found.');
    hints.push('Checks: `which <cmd>`, `echo $PATH`, is the tool installed?');
    const match = cmd.match(/^(\S+)/);
    if (match) hints.push(`Missing binary: \`${match[1]}\``);
  }

  if (exitCode === 126) {
    hints.push('Exit 126 = permission denied (file exists but not executable).');
    hints.push('Fix: `chmod +x <file>` or run with interpreter (`node file.js`, `python file.py`).');
  }

  if (exitCode === 1 && cmd.match(/^git\s/)) {
    hints.push('Git exited with error. Common causes:');
    hints.push('- Nothing to commit (check `git status`)');
    hints.push('- Merge conflict (check `git status` for conflict markers)');
    hints.push('- Wrong branch or remote (check `git remote -v`)');
  }

  if (exitCode === 128) {
    hints.push('Exit 128 = git fatal error (bad repo state or invalid argument).');
    hints.push('Checks: are you in a git repo? (`git rev-parse --git-dir`)');
  }

  // ── Error string patterns ───────────────────────────────────────────────
  if (errStr.includes('enoent') || errStr.includes('no such file')) {
    hints.push('File not found (ENOENT). Checks:');
    hints.push('- Does the path exist? (`ls -la <path>`)');
    hints.push('- Is the working directory correct?');
    hints.push('- Did a previous step fail to create it?');
  }

  if (errStr.includes('eacces') || errStr.includes('permission denied')) {
    hints.push('Permission denied (EACCES). Checks:');
    hints.push('- File permissions: `ls -la <file>`');
    hints.push('- Is a process holding the file open?');
    hints.push('- On Windows: run as administrator if needed');
  }

  if (errStr.includes('eaddrinuse') || errStr.includes('address already in use')) {
    hints.push('Port already in use. Find what is holding it:');
    hints.push('- Unix: `lsof -i :<port>` or `ss -tlnp`');
    hints.push('- Windows: `netstat -ano | findstr <port>`');
  }

  if (errStr.includes('timeout') || errStr.includes('timed out')) {
    hints.push('Command timed out. Possible causes:');
    hints.push('- External service unreachable (network issue)');
    hints.push('- Command hung waiting for input (needs interactive TTY?)');
    hints.push('- Increase timeout if the operation is legitimately slow');
  }

  if (errStr.includes('module not found') || errStr.includes('cannot find module')) {
    hints.push('Node module not found. Fix:');
    hints.push('- Run `npm install` or `pnpm install`');
    hints.push('- Check the import path for typos');
    hints.push('- Verify the package is in package.json');
  }

  if (errStr.includes('modulenotfounderror') || errStr.includes('no module named')) {
    hints.push('Python module not found. Fix:');
    hints.push('- Run `pip install <module>` or `uv sync`');
    hints.push('- Check you are in the right virtual environment');
  }

  if (errStr.includes('syntaxerror') || errStr.includes('syntax error')) {
    hints.push('Syntax error in code. Check the file referenced in the error for:');
    hints.push('- Mismatched brackets, quotes, or parentheses');
    hints.push('- Invalid JSON/YAML/TOML syntax');
  }

  // ── Tool-specific patterns ──────────────────────────────────────────────
  if (toolName === 'Edit' || toolName === 'Write') {
    if (errStr.includes('old_string not found') || errStr.includes('no match')) {
      hints.push('Edit failed: old_string not found in file.');
      hints.push('- Re-read the file with Read tool — it may have changed');
      hints.push('- Check for invisible characters or line ending differences');
      hints.push('- Use a larger context window in old_string to ensure uniqueness');
    }
  }

  // Default hint if nothing matched
  if (hints.length === 0) {
    hints.push(`Tool \`${toolName}\` failed (exit ${exitCode ?? 'unknown'}).`);
    hints.push('Read the error output carefully — it usually names the root cause.');
    hints.push('Try running the command manually to get unfiltered output.');
  }

  return hints;
}

rl.on('close', () => {
  let input;
  try {
    input = JSON.parse(raw);
  } catch {
    process.stdout.write(JSON.stringify({}));
    return;
  }

  const { tool_name, tool_input, error, exit_code } = input;
  const hints = triage(tool_name, tool_input, error, exit_code);

  const additionalContext = [
    `## Tool Failure Triage: \`${tool_name}\``,
    '',
    ...hints.map(h => `- ${h}`),
    '',
    'Diagnose root cause before retrying — the same command will likely fail again.',
  ].join('\n');

  process.stdout.write(JSON.stringify({ additionalContext }));
});
