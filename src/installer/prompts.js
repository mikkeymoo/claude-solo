// The @clack interactive flow. Returns a normalized answer object; mapping to
// install.sh flags lives in flagsFromAnswers() so it can be unit-reasoned and
// shown in the confirm summary.
import {
  intro,
  outro,
  select,
  confirm,
  isCancel,
  cancel,
  note,
  log,
} from '@clack/prompts';
import pc from 'picocolors';
import {
  introLine,
  statusLine,
  FRESH_MERGE_HELP,
  SCOPE_HELP,
  CACHE_FIX_HINT,
} from './messages.js';

function bail() {
  cancel('Cancelled — nothing was changed.');
  process.exit(130); // 128 + SIGINT, conventional for user cancel.
}

function guard(value) {
  if (isCancel(value)) bail();
  return value;
}

/**
 * Run the full interactive flow.
 * @param {object} state  result of detect()
 * @param {object} cliDefaults  values forced from CLI flags (e.g. --dry-run)
 * @returns {Promise<{scope:'user'|'project', mode:'fresh'|'merge',
 *                     cacheFix:boolean, dryRun:boolean}>}
 */
export async function runPrompts(state, cliDefaults = {}) {
  intro(pc.inverse(' claude-solo '));
  log.message(introLine());
  log.message(statusLine(state));

  // 1. Scope
  const scope = guard(
    await select({
      message: 'Where should claude-solo install?',
      options: [
        { value: 'user', label: SCOPE_HELP.userLabel, hint: SCOPE_HELP.userHint },
        { value: 'project', label: SCOPE_HELP.projectLabel, hint: SCOPE_HELP.projectHint },
      ],
      initialValue: 'user',
    })
  );

  // 2. Fresh vs merge — only meaningful for user-level when config exists.
  // The `update` command forces merge via cliDefaults.forceMode, so we skip
  // the question rather than letting the user contradict the command's intent.
  let mode = 'merge';
  if (scope === 'user' && state.installed && cliDefaults.forceMode) {
    mode = cliDefaults.forceMode;
    log.message(pc.dim(`Update mode — applying as ${mode} (keeps your settings).`));
  } else if (scope === 'user' && state.installed) {
    note(FRESH_MERGE_HELP.freshHint, 'A backup is always taken first');
    mode = guard(
      await select({
        message: 'An existing config was found. How should it be applied?',
        options: [
          { value: 'merge', label: FRESH_MERGE_HELP.mergeLabel, hint: FRESH_MERGE_HELP.mergeHint },
          { value: 'fresh', label: FRESH_MERGE_HELP.freshLabel, hint: FRESH_MERGE_HELP.freshHint },
        ],
        initialValue: 'merge',
      })
    );
  }

  // 3. Cache-fix proxy — opt-in, default No.
  const cacheFix = guard(
    await confirm({
      message: 'Wire the local cache proxy? ' + pc.dim('(' + CACHE_FIX_HINT + ')'),
      initialValue: false,
    })
  );

  const answers = {
    scope,
    mode,
    cacheFix,
    dryRun: Boolean(cliDefaults.dryRun),
  };

  // 4. Summary + confirm — show the exact command.
  const cmd = previewCommand(answers);
  note(pc.cyan(cmd), 'This command will run');
  const go = guard(
    await confirm({
      message: answers.dryRun
        ? 'Run the dry-run now?'
        : 'Proceed with the install?',
      initialValue: true,
    })
  );
  if (!go) bail();

  return answers;
}

/**
 * Map normalized answers → install.sh flag array.
 * @returns {string[]}
 */
export function flagsFromAnswers(a) {
  const flags = [];
  if (a.scope === 'project') flags.push('--project');
  if (a.scope === 'user' && a.mode === 'fresh') flags.push('--fresh');
  if (a.cacheFix) flags.push('--with-cache-fix');
  if (a.dryRun) flags.push('--dry-run');
  if (a.assumeYes) flags.push('-y');
  return flags;
}

// Human-readable preview of the command that flagsFromAnswers() will produce.
export function previewCommand(a) {
  const flags = flagsFromAnswers(a);
  return `bash install.sh${flags.length ? ' ' + flags.join(' ') : ''}`;
}

// Build answers from CLI flags only (no prompts) for --yes / CI mode.
export function answersFromFlags(opts) {
  return {
    scope: opts.project ? 'project' : 'user',
    mode: opts.fresh ? 'fresh' : 'merge',
    cacheFix: Boolean(opts.withCacheFix),
    dryRun: Boolean(opts.dryRun),
    assumeYes: true,
  };
}

export { outro };
