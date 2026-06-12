// Detect a prior claude-solo install by reading the marker files that
// install.sh writes on success. Pure reads — never mutates anything.
import { homedir } from 'node:os';
import { join } from 'node:path';
import { readFile, lstat, readlink } from 'node:fs/promises';

const CLAUDE_HOME = join(homedir(), '.claude');

async function readTrimmed(path) {
  try {
    const raw = await readFile(path, 'utf8');
    return raw.trim() || null;
  } catch {
    return null;
  }
}

// Is the plugin linked into ~/.claude/skills/claude-solo? install.sh creates
// this as a symlink (POSIX) or NTFS junction (Windows). lstat catches both.
async function pluginLinked() {
  const link = join(CLAUDE_HOME, 'skills', 'claude-solo');
  try {
    const st = await lstat(link);
    if (st.isSymbolicLink()) {
      const target = await readlink(link).catch(() => null);
      return { linked: true, target };
    }
    // Junctions on Windows report as directories via lstat; treat presence as linked.
    if (st.isDirectory()) return { linked: true, target: link };
    return { linked: true, target: null };
  } catch {
    return { linked: false, target: null };
  }
}

/**
 * @returns {Promise<{installed: boolean, sha: string|null, repo: string|null,
 *                    pluginLinked: boolean, pluginTarget: string|null,
 *                    claudeHome: string}>}
 */
export async function detect() {
  const [sha, repo, plugin] = await Promise.all([
    readTrimmed(join(CLAUDE_HOME, '.claude-solo-version')),
    readTrimmed(join(CLAUDE_HOME, '.claude-solo-repo')),
    pluginLinked(),
  ]);

  return {
    installed: Boolean(sha) || plugin.linked,
    sha,
    repo,
    pluginLinked: plugin.linked,
    pluginTarget: plugin.target,
    claudeHome: CLAUDE_HOME,
  };
}
