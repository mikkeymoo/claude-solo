#!/usr/bin/env node
// claude-solo — interactive front door over install.sh.
// Thin and cross-platform: prompts in Node, all file work in install.sh.
import { Command } from 'commander';
import pc from 'picocolors';
import { detect } from '../src/installer/detect.js';
import { runInstall, bashAvailable } from '../src/installer/run-bash.js';
import {
  runPrompts,
  flagsFromAnswers,
  answersFromFlags,
  previewCommand,
} from '../src/installer/prompts.js';
import { outroSuccess, bashMissingHint } from '../src/installer/messages.js';

const isWindows = process.platform === 'win32';

// Hard preflight: bash is the one dependency the wrapper can't remove.
function requireBash() {
  if (bashAvailable()) return;
  // On Windows this is the common case worth a friendly hint; elsewhere a
  // missing bash is unusual but the same message applies.
  process.stderr.write('\n' + bashMissingHint() + '\n');
  process.exit(1);
}

async function doInstall(opts) {
  requireBash();

  const state = await detect();

  let answers;
  if (opts.yes) {
    // Non-interactive / CI: derive everything from flags, skip prompts.
    answers = answersFromFlags(opts);
    process.stdout.write(
      pc.dim(`Non-interactive mode — running: ${previewCommand(answers)}\n`)
    );
  } else {
    answers = await runPrompts(state, {
      dryRun: opts.dryRun,
      // `update` forces merge so the prompt can't contradict the command.
      forceMode: opts.forceMode,
    });
  }

  const flags = flagsFromAnswers(answers);
  const code = await runInstall(flags);

  if (code === 0) {
    process.stdout.write('\n' + outroSuccess(answers.scope) + '\n');
  } else {
    process.stderr.write(
      '\n' + pc.red(`✗ install.sh exited with code ${code}.`) + '\n'
    );
  }
  process.exit(code);
}

// uninstall / verify map straight through to install.sh with no prompting.
async function passthrough(flag, opts) {
  requireBash();
  const flags = [flag];
  if (opts && opts.dryRun) flags.push('--dry-run');
  const code = await runInstall(flags);
  process.exit(code);
}

const program = new Command();

program
  .name('claude-solo')
  .description('Interactive installer for the claude-solo Claude Code configuration')
  .version('1.0.0');

program
  .command('install', { isDefault: true })
  .description('Install claude-solo (interactive)')
  .option('-y, --yes', 'non-interactive: use flag values/defaults, skip prompts')
  .option('--project', 'project-level install into the current directory')
  .option('--fresh', 'fresh install (purge + backup) instead of merge')
  .option('--with-cache-fix', 'wire the local cache proxy (127.0.0.1:9801)')
  .option('-n, --dry-run', 'show what would happen without changing anything')
  .action(doInstall);

program
  .command('uninstall')
  .description('Remove a prior claude-solo install')
  .option('-n, --dry-run', 'show what would be removed')
  .action((opts) => passthrough('--uninstall', opts));

program
  .command('verify')
  .description('Check prerequisites only — no changes')
  .action((opts) => passthrough('--verify', opts));

program
  .command('update')
  .description('Re-run the installer to update an existing install (merge)')
  .option('-y, --yes', 'non-interactive')
  .option('--with-cache-fix', 'wire the local cache proxy (127.0.0.1:9801)')
  .option('-n, --dry-run', 'show what would happen without changing anything')
  .action((opts) => doInstall({ ...opts, fresh: false, forceMode: 'merge' }));

program.parseAsync(process.argv).catch((err) => {
  process.stderr.write('\n' + pc.red(`Unexpected error: ${err?.message || err}`) + '\n');
  process.exit(1);
});
