// Locate a usable bash and run install.sh through it, streaming live output
// and propagating the exit code. All real install work stays in install.sh —
// this only resolves the interpreter and the script path.
import { spawn, spawnSync } from 'node:child_process';
import { existsSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join, resolve } from 'node:path';

const __dirname = dirname(fileURLToPath(import.meta.url));
// src/installer/run-bash.js → package root is two levels up.
export const PKG_ROOT = resolve(__dirname, '..', '..');
export const INSTALL_SH = join(PKG_ROOT, 'install.sh');

const isWindows = process.platform === 'win32';

// Common Git for Windows bash locations, checked after PATH.
const WINDOWS_BASH_CANDIDATES = [
  'C:\\Program Files\\Git\\bin\\bash.exe',
  'C:\\Program Files\\Git\\usr\\bin\\bash.exe',
  'C:\\Program Files (x86)\\Git\\bin\\bash.exe',
];

// Resolve a bash executable. On non-Windows, plain `bash` from PATH is fine.
// On Windows, prefer a real Git Bash path over a possible WSL `bash.exe` shim
// (WSL bash can't run a Windows-path script cleanly), but fall back to PATH.
export function findBash() {
  if (!isWindows) return 'bash';

  for (const candidate of WINDOWS_BASH_CANDIDATES) {
    if (existsSync(candidate)) return candidate;
  }

  // Last resort: rely on PATH resolution by spawn. May be WSL; the preflight
  // check in the CLI surfaces a hint if this ends up unusable.
  return 'bash';
}

// Quick preflight: can we actually launch bash? Returns true/false without
// throwing. Used to hard-exit with a hint before prompting on Windows.
export function bashAvailable() {
  const bash = findBash();
  if (bash !== 'bash' && existsSync(bash)) return true;
  // PATH-based: probe synchronously.
  try {
    const r = spawnSync(bash, ['-c', 'exit 0'], { stdio: 'ignore' });
    return r.status === 0;
  } catch {
    return false;
  }
}

/**
 * Run install.sh with the given flags.
 * @param {string[]} flags  e.g. ['--fresh', '--dry-run']
 * @param {object} [opts]
 * @param {string} [opts.cwd]  working dir for the bash process (project-level
 *                             installs write into this dir). Defaults to the
 *                             caller's CWD so `--project` lands in the user's
 *                             terminal directory.
 * @returns {Promise<number>} resolves with install.sh's exit code.
 */
export function runInstall(flags = [], opts = {}) {
  const bash = findBash();
  const cwd = opts.cwd || process.cwd();
  const args = [INSTALL_SH, ...flags];

  return new Promise((resolvePromise) => {
    const child = spawn(bash, args, {
      cwd,
      stdio: 'inherit', // install.sh has no stdin prompts of its own.
      env: process.env,
    });

    child.on('error', (err) => {
      process.stderr.write(`\nFailed to launch bash: ${err.message}\n`);
      resolvePromise(127);
    });

    child.on('close', (code, signal) => {
      if (signal) {
        // Killed by signal (e.g. Ctrl-C forwarded) — report as non-zero.
        resolvePromise(1);
        return;
      }
      resolvePromise(code == null ? 1 : code);
    });
  });
}
