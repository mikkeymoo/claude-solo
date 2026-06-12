// Banners and the honest copy. Kept apart from flow logic so the wording
// can be tuned without touching the prompt sequence.
import pc from 'picocolors';

export const TITLE = 'claude-solo installer';

export function introLine() {
  return `${pc.bold(pc.cyan('claude-solo'))} — Claude Code config for solo developers`;
}

// Shown once detect() has run, before any choices.
export function statusLine(state) {
  if (!state.installed) return pc.dim('No prior install detected — fresh install.');
  const sha = state.sha ? state.sha.slice(0, 8) : 'unknown';
  const where = state.repo ? pc.dim(` (repo: ${state.repo})`) : '';
  return `Existing install detected: ${pc.yellow(sha)}${where}`;
}

// The fresh-vs-merge copy. Honest about exactly what fresh purges and that a
// backup is always taken first — matches PLAN step 5 wording.
export const FRESH_MERGE_HELP = {
  freshLabel: 'Fresh (purge + backup)',
  freshHint:
    'Purges ~/.claude/{agents,skills,commands,rules,hooks} and rewrites settings.json. ' +
    'A timestamped backup is taken first at ~/.claude/.claude-solo-backup/ (last 5 kept).',
  mergeLabel: 'Merge (keep my settings)',
  mergeHint:
    'Preserves your settings.json and shows a diff. A backup is still taken before any change.',
};

export const SCOPE_HELP = {
  userLabel: 'User-level',
  userHint: 'Installs into ~/.claude — applies to all projects.',
  projectLabel: 'Project-level',
  projectHint: 'Adds a claude-solo override into the current directory only.',
};

export const CACHE_FIX_HINT =
  'Opt-in local cache proxy on 127.0.0.1:9801 (rewrites ANTHROPIC_BASE_URL). Default: No.';

// Printed after a successful install.sh run.
export function outroSuccess(scope) {
  const lines = [
    pc.green('✓ Install complete.'),
    '',
    'Next steps:',
    `  ${pc.dim('•')} Start a fresh Claude Code session so the new config loads.`,
  ];
  if (scope === 'user') {
    lines.push(
      `  ${pc.dim('•')} Try the sprint pipeline: ${pc.cyan('/mm-brief')} → ${pc.cyan('/mm-riper --plan')} → ${pc.cyan('/mm-riper --build')}.`,
      `  ${pc.dim('•')} Run ${pc.cyan('/mm-hud --doctor')} to verify hooks and agents are wired.`
    );
  } else {
    lines.push(`  ${pc.dim('•')} The project override lives in this directory — commit it if you want it tracked.`);
  }
  return lines.join('\n');
}

export function bashMissingHint() {
  return [
    pc.red('✗ Git Bash (bash) was not found on PATH.'),
    '',
    'claude-solo reuses install.sh for all file operations, which needs bash.',
    `Install Git for Windows, then re-run:`,
    `  ${pc.cyan('winget install Git.Git')}`,
    '',
    'After installing, open a new terminal so PATH picks up bash.',
  ].join('\n');
}
