#!/usr/bin/env node
/**
 * claude-solo pre-tool-use hook
 *
 * Warns about potentially dangerous commands via stderr — never blocks.
 * Claude Code will still execute the command; this is advisory only.
 *
 * Input (stdin): JSON { tool_name, tool_input }
 * Output (stdout): JSON { action: "continue" }
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
    process.stdout.write(JSON.stringify({ action: 'continue' }));
    return;
  }

  const { tool_name, tool_input } = input;

  if (tool_name === 'Bash' || tool_name === 'mcp__desktop-commander__start_process') {
    const cmd = (tool_input?.command || tool_input?.cmd || '').toLowerCase();

    const warnings = [
      // Filesystem destruction
      { pattern: /rm\s+-rf\s+\/(?!tmp)/, reason: 'Deleting from root' },
      { pattern: /rm\s+(-\w+\s+)*--no-preserve-root/, reason: 'Bypassing root preservation guard' },

      // Git danger
      { pattern: /git\s+push\s+(?!.*--dry-run)(--force|-f)/, reason: 'Force-pushing (overwrites remote history)' },
      { pattern: /git\s+reset\s+--hard/, reason: 'Hard reset discards uncommitted work' },
      { pattern: /git\s+clean\s+(?!.*-n)(?!.*--dry-run).*-\w*f/, reason: 'git clean -f removes untracked files permanently' },

      // Database
      { pattern: /drop\s+table/, reason: 'Dropping database table' },
      { pattern: /drop\s+database/, reason: 'Dropping entire database' },
      { pattern: /delete\s+from\s+\w+\s*;?\s*$/, reason: 'DELETE without WHERE clause' },
      { pattern: /truncate\s+table/, reason: 'TRUNCATE is irreversible' },

      // Process control
      { pattern: /pkill\s+-9|kill\s+-9/, reason: 'SIGKILL forcefully terminates processes (no cleanup)' },
      { pattern: /killall\s+-9/, reason: 'SIGKILL to all matching processes (no cleanup)' },

      // Permissions
      { pattern: /chmod\s+-r\s+777|chmod\s+777\s+-r|chmod\s+a\+rwx\s+-r/, reason: 'World-writable recursive permission change' },
      { pattern: /chmod\s+777\s+\/|chmod\s+777\s+~/, reason: 'World-writable on root or home directory' },

      // Remote code execution
      { pattern: /curl\s+.+\|\s*(ba)?sh|wget\s+.+\|\s*(ba)?sh/, reason: 'Piping remote content directly to shell (RCE risk)' },
      { pattern: /curl\s+.+\|\s*node|wget\s+.+\|\s*node/, reason: 'Piping remote content directly to Node (RCE risk)' },

      // Disk write
      { pattern: /\bdd\s+if=/, reason: 'Direct disk write (dd) — can destroy data' },

      // Publishing
      { pattern: /npm\s+publish(?!\s+--dry-run)/, reason: 'Publishing to npm registry (use --dry-run first)' },
      { pattern: /cargo\s+publish(?!\s+--dry-run)/, reason: 'Publishing to crates.io (use --dry-run first)' },
      { pattern: /pip\s+install\s+--upload|twine\s+upload(?!\s+--repository\s+testpypi)/, reason: 'Publishing to PyPI' },
    ];

    for (const { pattern, reason } of warnings) {
      if (pattern.test(cmd)) {
        process.stderr.write(`⚠️  claude-solo: ${reason}\n`);
        break;
      }
    }
  }

  // Always continue — never block
  process.stdout.write(JSON.stringify({ action: 'continue' }));
});
